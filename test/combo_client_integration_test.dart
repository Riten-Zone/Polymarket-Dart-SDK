/// Live integration tests for ComboClient — hits the real Polymarket
/// Combos/RFQ and Data APIs. Public endpoints run without credentials;
/// authenticated maker endpoints are lenient and skip without .env creds.
///
/// Run with:
///   dart test test/combo_client_integration_test.dart --tags combo
@Tags(['integration', 'combo'])
library;

import 'dart:io';

import 'package:polymarket_dart/polymarket_dart.dart';
import 'package:test/test.dart';

void main() {
  final privateKey =
      Platform.environment['PRIVATE_KEY'] ?? _loadEnv('PRIVATE_KEY');

  group('ComboClient public (live)', () {
    late ComboClient combo;

    setUpAll(() => combo = ComboClient());
    tearDownAll(() => combo.close());

    test('getComboMarkets returns real markets with aligned arrays', () async {
      final page = await combo.getComboMarkets(
        const GetComboMarketsParams(limit: 5),
      );

      expect(page.markets, isNotEmpty,
          reason: 'expected at least one live combo market');

      for (final m in page.markets) {
        expect(m.conditionId, startsWith('0x'));
        // YES/NO invariant: two position ids, aligned with outcomes/prices.
        expect(m.positionIds, hasLength(2));
        expect(m.outcomes, hasLength(2));
        expect(m.outcomePrices, hasLength(m.outcomes.length));
        expect(m.title, isNotEmpty);
        expect(m.volume, greaterThanOrEqualTo(0));
        // Prices parse as doubles in the 0..1 range.
        for (final p in m.outcomePrices) {
          final v = double.parse(p);
          expect(v, inInclusiveRange(0.0, 1.0));
        }
      }
      print('getComboMarkets → ${page.markets.length} markets, '
          'next_cursor=${page.nextCursor}');
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('cursor pagination advances', () async {
      final first = await combo.getComboMarkets(
        const GetComboMarketsParams(limit: 2),
      );
      if (first.nextCursor == null) {
        markTestSkipped('single page of combo markets — nothing to page');
        return;
      }
      final second = await combo.getComboMarkets(
        GetComboMarketsParams(limit: 2, cursor: first.nextCursor),
      );
      expect(second.markets, isNotEmpty);
      final firstIds = first.markets.map((m) => m.id).toSet();
      final secondIds = second.markets.map((m) => m.id).toSet();
      expect(firstIds.intersection(secondIds), isEmpty,
          reason: 'second page should hold different markets');
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('getComboPositions returns a well-formed page (may be empty)',
        () async {
      // A zero address reliably has no combo positions but exercises parsing.
      final page = await combo.getComboPositions(
        const GetComboPositionsParams(
          user: '0x0000000000000000000000000000000000000000',
          limit: 5,
        ),
      );
      expect(page.combos, isA<List<ComboPosition>>());
      expect(page.pagination, isNotNull);
      expect(page.pagination!.limit, equals(5));
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('getComboActivity returns a well-formed page (may be empty)',
        () async {
      final page = await combo.getComboActivity(
        const GetComboActivityParams(
          user: '0x0000000000000000000000000000000000000000',
          limit: 5,
        ),
      );
      expect(page.activity, isA<List<ComboActivity>>());
      expect(page.pagination, isNotNull);
    }, timeout: const Timeout(Duration(seconds: 20)));
  });

  group('ComboClient maker (live, needs creds)', () {
    late ComboClient maker;
    bool authAvailable = false;

    setUpAll(() async {
      if (privateKey == null || privateKey.isEmpty) return;
      try {
        final wallet = PrivateKeyWalletAdapter(privateKey);
        final clob = ClobClient(wallet: wallet);
        final creds = await clob.createOrDeriveApiKey();
        clob.close();
        maker = ComboClient(wallet: wallet, credentials: creds);
        authAvailable = true;
      } catch (_) {
        // auth setup failed — maker tests will skip
      }
    });

    tearDownAll(() {
      if (authAvailable) maker.close();
    });

    test('cancelQuote reaches the maker endpoint (lenient)', () async {
      if (!authAvailable) {
        markTestSkipped('No .env PRIVATE_KEY — skipping maker test');
        return;
      }
      // Cancelling a non-existent quote should reach the server and be
      // rejected (not a client-side crash). Either an API error or a snapshot
      // is an acceptable "endpoint reachable" outcome.
      try {
        final snap = await maker.cancelQuote(const CancelQuoteParams(
          rfqId: 'nonexistent-rfq',
          quoteId: 'nonexistent-quote',
          signerAddress: '0x0000000000000000000000000000000000000000',
          makerAddress: '0x0000000000000000000000000000000000000000',
          signatureType: 0,
        ));
        expect(snap, isA<RfqSnapshot>());
      } on PolymarketApiException catch (e) {
        print('cancelQuote → API rejected as expected: ${e.statusCode}');
        expect(e.statusCode, greaterThanOrEqualTo(400));
      }
    }, timeout: const Timeout(Duration(seconds: 20)));
  });
}

String? _loadEnv(String key) {
  final file = File('.env');
  if (!file.existsSync()) return null;
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final idx = trimmed.indexOf('=');
    if (idx == -1) continue;
    if (trimmed.substring(0, idx).trim() == key) {
      return trimmed.substring(idx + 1).trim();
    }
  }
  return null;
}
