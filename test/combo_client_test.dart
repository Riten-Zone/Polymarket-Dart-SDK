/// Offline tests for ComboClient — combo markets, positions, activity, and
/// the authenticated maker quote/last-look flow. Uses a mocked HTTP client, so
/// these run with no network access as part of the default `dart test` suite.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polymarket_dart/polymarket_dart.dart';
import 'package:test/test.dart';

// Standard hardhat test key (address 0xf39F...2266). Never holds funds.
const _testKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

// Valid base64url secret so HMAC header generation works.
const _creds = ApiCredentials(
  apiKey: 'test-api-key',
  secret: 'c2VjcmV0LXNlY3JldC1zZWNyZXQtc2VjcmV0',
  passphrase: 'test-pass',
);

ComboClient publicClientFor(
  Future<http.Response> Function(http.Request request) handler,
) =>
    ComboClient(transport: HttpTransport(client: MockClient(handler)));

ComboClient makerClientFor(
  Future<http.Response> Function(http.Request request) handler,
) =>
    ComboClient(
      wallet: PrivateKeyWalletAdapter(_testKey),
      credentials: _creds,
      transport: HttpTransport(client: MockClient(handler)),
    );

void main() {
  group('ComboClient public discovery', () {
    test('getComboMarkets hits combo-markets and parses aligned arrays',
        () async {
      final client = publicClientFor((request) async {
        expect(request.method, equals('GET'));
        expect(request.url.host, equals('combos-rfq-api.polymarket.com'));
        expect(request.url.path, equals('/v1/rfq/combo-markets'));
        expect(request.url.queryParameters['limit'], equals('20'));
        expect(request.url.queryParameters['exclude'], equals('0xaa,0xbb'));

        return http.Response(
          jsonEncode({
            'markets': [
              {
                'id': 'm1',
                'condition_id': '0xcond',
                'position_ids': ['0xyes', '0xno'],
                'slug': 'will-x-happen',
                'title': 'Will X happen?',
                'outcomes': ['Yes', 'No'],
                'outcome_prices': ['0.72', '0.28'],
                'image': 'https://img',
                'volume': 12345.6,
                'tags': ['crypto'],
              },
            ],
            'next_cursor': 'CURSOR2',
          }),
          200,
        );
      });

      final page = await client.getComboMarkets(
        const GetComboMarketsParams(limit: 20, exclude: ['0xaa', '0xbb']),
      );

      expect(page.nextCursor, equals('CURSOR2'));
      expect(page.markets, hasLength(1));
      final m = page.markets.first;
      expect(m.conditionId, equals('0xcond'));
      expect(m.positionIds, equals(['0xyes', '0xno']));
      expect(m.outcomes[0], equals('Yes'));
      expect(m.outcomePrices[0], equals('0.72'));
      expect(m.volume, closeTo(12345.6, 1e-9));
      expect(m.tags, contains('crypto'));
      client.close();
    });

    test('getComboPositions hits data-api with user + status filters',
        () async {
      final client = publicClientFor((request) async {
        expect(request.url.host, equals('data-api.polymarket.com'));
        expect(request.url.path, equals('/v1/positions/combos'));
        expect(request.url.queryParameters['user'], equals('0xUser'));
        expect(request.url.queryParameters['status'],
            equals('OPEN,RESOLVED_WIN'));
        expect(request.url.queryParameters['updatedAfter'], equals('1700'));

        return http.Response(
          jsonEncode({
            'combos': [
              {
                'combo_position_id': '0xpos',
                'combo_condition_id': '0xcond',
                'status': 'OPEN',
                'size': '10',
              },
            ],
            'pagination': {
              'limit': 50,
              'offset': 0,
              'has_more': true,
              'next_cursor': 'N',
            },
          }),
          200,
        );
      });

      final page = await client.getComboPositions(
        const GetComboPositionsParams(
          user: '0xUser',
          status: ['OPEN', 'RESOLVED_WIN'],
          updatedAfter: 1700,
        ),
      );

      expect(page.combos, hasLength(1));
      expect(page.combos.first.comboPositionId, equals('0xpos'));
      expect(page.combos.first.raw['size'], equals('10'));
      expect(page.pagination!.hasMore, isTrue);
      expect(page.pagination!.nextCursor, equals('N'));
      client.close();
    });

    test('getComboActivity hits data-api activity endpoint', () async {
      final client = publicClientFor((request) async {
        expect(request.url.path, equals('/v1/activity/combos'));
        expect(request.url.queryParameters['user'], equals('0xUser'));
        expect(request.url.queryParameters['market_id'], equals('0x1,0x2'));

        return http.Response(
          jsonEncode({
            'activity': [
              {'type': 'SPLIT', 'combo_condition_id': '0x1', 'timestamp': 42},
            ],
            'pagination': {'limit': 50, 'offset': 0, 'has_more': false},
          }),
          200,
        );
      });

      final page = await client.getComboActivity(
        const GetComboActivityParams(user: '0xUser', marketId: ['0x1', '0x2']),
      );

      expect(page.activity.single.type, equals('SPLIT'));
      expect(page.activity.single.timestamp, equals(42));
      expect(page.pagination!.hasMore, isFalse);
      client.close();
    });
  });

  group('ComboClient maker flow (Level 2)', () {
    SignedRfqOrder order() => const SignedRfqOrder(
          salt: '123',
          maker: '0xmaker',
          signer: '0xsigner',
          tokenId: '0xtoken',
          makerAmount: '1000000',
          takerAmount: '2000000',
          side: 0,
          signatureType: 0,
          timestamp: '1700',
          signature: '0xsig',
        );

    test('submitQuote posts to /v1/maker/quotes with L2 headers and body',
        () async {
      final client = makerClientFor((request) async {
        expect(request.method, equals('POST'));
        expect(request.url.host, equals('combos-rfq-api.polymarket.com'));
        expect(request.url.path, equals('/v1/maker/quotes'));
        // L2 auth headers present.
        expect(request.headers['poly_api_key'] ?? request.headers['POLY_API_KEY'],
            isNotNull);
        expect(
            request.headers['poly_signature'] ??
                request.headers['POLY_SIGNATURE'],
            isNotNull);

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['rfq_id'], equals('rfq1'));
        expect(body['quote_id'], equals('q1'));
        expect(body['price_e6'], equals('550000'));
        expect(body['signed_order'], isA<Map<String, dynamic>>());
        expect(body['signed_order']['tokenId'], equals('0xtoken'));
        expect(body['signed_order']['builder'], equals(''));

        return http.Response(
          jsonEncode({'rfq_id': 'rfq1', 'status': 'PENDING'}),
          200,
        );
      });

      final snap = await client.submitQuote(SubmitQuoteParams(
        quoteId: 'q1',
        rfqId: 'rfq1',
        signerAddress: '0xsigner',
        makerAddress: '0xmaker',
        signatureType: 0,
        priceE6: '550000',
        sizeE6: '50000000',
        signedOrder: order(),
      ));

      expect(snap.rfqId, equals('rfq1'));
      expect(snap.status, equals('PENDING'));
      client.close();
    });

    test('submitConfirmation posts CONFIRM decision', () async {
      final client = makerClientFor((request) async {
        expect(request.url.path, equals('/v1/maker/confirmations'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['decision'], equals('CONFIRM'));
        expect(body['quote_id'], equals('q1'));
        return http.Response(jsonEncode({'execution': {'filled': true}}), 200);
      });

      final snap = await client.submitConfirmation(const ConfirmationParams(
        rfqId: 'rfq1',
        quoteId: 'q1',
        signerAddress: '0xsigner',
        makerAddress: '0xmaker',
        signatureType: 0,
        decision: LastLookDecision.confirm,
      ));

      expect(snap.raw['execution'], isA<Map<String, dynamic>>());
      client.close();
    });

    test('maker endpoints without credentials throw StateError', () async {
      final client = ComboClient(); // no wallet/creds
      expect(
        () => client.cancelQuote(const CancelQuoteParams(
          rfqId: 'r',
          quoteId: 'q',
          signerAddress: '0xs',
          makerAddress: '0xm',
          signatureType: 0,
        )),
        throwsA(isA<StateError>()),
      );
      client.close();
    });
  });

  group('Combo gateway message models', () {
    test('RfqRequestEvent parses nested requested_size', () {
      final event = RfqRequestEvent.fromJson({
        'type': 'RFQ_REQUEST',
        'rfq_id': 'rfq1',
        'leg_position_ids': ['0xa', '0xb'],
        'condition_id': '0xcond',
        'yes_position_id': '0xyes',
        'no_position_id': '0xno',
        'direction': 'BUY',
        'side': 'YES',
        'requested_size': {'unit': 'shares', 'value_e6': '50000000'},
        'submission_deadline': 1700000000,
      });

      expect(event.rfqId, equals('rfq1'));
      expect(event.legPositionIds, equals(['0xa', '0xb']));
      expect(event.direction, equals('BUY'));
      expect(event.sizeUnit, equals('shares'));
      expect(event.sizeValueE6, equals('50000000'));
      expect(event.submissionDeadline, equals(1700000000));
    });

    test('LastLookDecision serializes to upper-case', () {
      expect(LastLookDecision.confirm.toJson(), equals('CONFIRM'));
      expect(LastLookDecision.decline.toJson(), equals('DECLINE'));
    });
  });
}
