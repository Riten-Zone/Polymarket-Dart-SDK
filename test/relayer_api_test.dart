/// Offline tests for the RelayerClient v2 endpoints — relay payload/nonce,
/// submit, transaction lookup, recent transactions, API keys, and deposit
/// wallet deploy. Uses a mocked HTTP client (no network).
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polymarket_dart/polymarket_dart.dart';
import 'package:test/test.dart';

const _testKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

const _creds = BuilderCredentials(
  apiKey: 'builder-key',
  secret: 'c2VjcmV0LXNlY3JldC1zZWNyZXQtc2VjcmV0',
  passphrase: 'builder-pass',
);

RelayerClient clientFor(
  Future<http.Response> Function(http.Request request) handler,
) =>
    RelayerClient(
      wallet: PrivateKeyWalletAdapter(_testKey),
      creds: _creds,
      httpClient: MockClient(handler),
    );

void main() {
  test('getRelayPayload GETs /relay-payload with address + type', () async {
    final client = clientFor((request) async {
      expect(request.method, equals('GET'));
      expect(request.url.path, equals('/relay-payload'));
      expect(request.url.queryParameters['address'], equals('0xOwner'));
      expect(request.url.queryParameters['type'], equals('SAFE'));
      return http.Response(
        jsonEncode({'address': '0xRelayer', 'nonce': '31'}),
        200,
      );
    });

    final payload = await client.getRelayPayload('0xOwner');
    expect(payload.address, equals('0xRelayer'));
    expect(payload.nonce, equals('31'));
    client.close();
  });

  test('submitTransaction POSTs /submit and returns id + state', () async {
    final client = clientFor((request) async {
      expect(request.method, equals('POST'));
      expect(request.url.path, equals('/submit'));
      // Builder auth header present.
      expect(
        request.headers['poly_builder_api_key'] ??
            request.headers['POLY_BUILDER_API_KEY'],
        isNotNull,
      );
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['type'], equals('SAFE'));
      expect(body['from'], equals('0xFrom'));
      expect(body['signatureParams'], isA<Map<String, dynamic>>());
      return http.Response(
        jsonEncode({'transactionID': 'tx-123', 'state': 'STATE_NEW'}),
        200,
      );
    });

    final result = await client.submitTransaction(const RelayerSubmitRequest(
      from: '0xFrom',
      to: '0xTo',
      proxyWallet: '0xProxy',
      data: '0xdeadbeef',
      nonce: '5',
      signature: '0xsig',
      type: RelayerWalletType.safe,
    ));

    expect(result.transactionId, equals('tx-123'));
    expect(result.state, equals('STATE_NEW'));
    client.close();
  });

  test('getTransaction parses an array of records and status helpers',
      () async {
    final client = clientFor((request) async {
      expect(request.url.path, equals('/transaction'));
      expect(request.url.queryParameters['id'], equals('tx-123'));
      return http.Response(
        jsonEncode([
          {
            'transactionID': 'tx-123',
            'transactionHash': '0xhash',
            'state': 'STATE_CONFIRMED',
            'type': 'SAFE',
            'nonce': 5,
          },
        ]),
        200,
      );
    });

    final txns = await client.getTransaction('tx-123');
    expect(txns, hasLength(1));
    expect(txns.first.transactionHash, equals('0xhash'));
    expect(txns.first.nonce, equals('5'));
    expect(txns.first.isConfirmed, isTrue);
    expect(txns.first.isFailed, isFalse);
    client.close();
  });

  test('getRecentTransactions GETs /transactions with builder auth', () async {
    final client = clientFor((request) async {
      expect(request.url.path, equals('/transactions'));
      expect(
        request.headers['poly_builder_signature'] ??
            request.headers['POLY_BUILDER_SIGNATURE'],
        isNotNull,
      );
      return http.Response(
        jsonEncode([
          {'transactionID': 'a', 'state': 'STATE_MINED'},
          {'transactionID': 'b', 'state': 'STATE_FAILED'},
        ]),
        200,
      );
    });

    final txns = await client.getRecentTransactions();
    expect(txns, hasLength(2));
    expect(txns[1].isFailed, isTrue);
    client.close();
  });

  test('getApiKeys parses relayer api key list', () async {
    final client = clientFor((request) async {
      expect(request.url.path, equals('/relayer/api/keys'));
      return http.Response(
        jsonEncode([
          {
            'apiKey': 'uuid-1',
            'address': '0xabc',
            'createdAt': '2026-01-01T00:00:00Z',
          },
        ]),
        200,
      );
    });

    final keys = await client.getApiKeys();
    expect(keys.single.apiKey, equals('uuid-1'));
    expect(keys.single.address, equals('0xabc'));
    client.close();
  });

  test('waitForTransaction polls until STATE_CONFIRMED', () async {
    var polls = 0;
    final client = clientFor((request) async {
      expect(request.url.path, equals('/transaction'));
      polls++;
      final state = polls < 3 ? 'STATE_MINED' : 'STATE_CONFIRMED';
      return http.Response(
        jsonEncode([
          {'transactionID': 'tx-1', 'state': state},
        ]),
        200,
      );
    });

    final txn = await client.waitForTransaction(
      'tx-1',
      interval: const Duration(milliseconds: 1),
    );
    expect(txn.isConfirmed, isTrue);
    expect(polls, greaterThanOrEqualTo(3));
    client.close();
  });

  test('waitForTransaction throws when the relayer reports failure', () async {
    final client = clientFor((request) async {
      return http.Response(
        jsonEncode([
          {'transactionID': 'tx-2', 'state': 'STATE_FAILED'},
        ]),
        200,
      );
    });

    expect(
      () => client.waitForTransaction(
        'tx-2',
        interval: const Duration(milliseconds: 1),
      ),
      throwsA(isA<RelayerException>()),
    );
    client.close();
  });

  test('deployDepositWallet POSTs WALLET-CREATE to the factory', () async {
    final client = clientFor((request) async {
      expect(request.url.path, equals('/submit'));
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['type'], equals('WALLET-CREATE'));
      expect(body['from'], equals('0xOwner'));
      expect(
        body['to'],
        equals(PolymarketContracts.depositWalletFactory),
      );
      // No user signature in this payload.
      expect(body.containsKey('signature'), isFalse);
      return http.Response(
        jsonEncode({'transactionID': 'wc-1', 'state': 'STATE_NEW'}),
        200,
      );
    });

    final result = await client.deployDepositWallet('0xOwner');
    expect(result.transactionId, equals('wc-1'));
    client.close();
  });
}
