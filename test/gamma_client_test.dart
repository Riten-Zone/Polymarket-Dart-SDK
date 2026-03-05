/// Integration tests for GammaClient — market and event discovery.
///
/// Hits the live Polymarket Gamma API. No authentication required.
///
/// Run with:
///   dart test test/gamma_client_test.dart --tags gamma
@Tags(['integration', 'gamma'])
library;

import 'package:test/test.dart';
import 'package:polymarket_dart/polymarket_dart.dart';

void main() {
  late GammaClient client;

  setUpAll(() {
    client = GammaClient();
  });

  tearDownAll(() => client.close());

  // ---------------------------------------------------------------------------
  // Markets
  // ---------------------------------------------------------------------------

  group('GammaClient.getMarkets', () {
    test('returns a non-empty list', () async {
      final markets = await client.getMarkets(limit: 5);
      expect(markets, isA<List<GammaMarket>>());
      expect(markets, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('active filter returns only active markets', () async {
      final markets = await client.getMarkets(active: true, limit: 10);
      expect(markets, isNotEmpty);
      for (final m in markets) {
        expect(m.active, isTrue,
            reason: 'Market ${m.conditionId} should be active');
      }
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('market fields are well-formed', () async {
      final markets = await client.getMarkets(
        active: true,
        closed: false,
        order: 'volume24hr',
        ascending: false,
        limit: 5,
      );
      expect(markets, isNotEmpty);

      final m = markets.first;
      expect(m.conditionId, isNotEmpty);
      expect(m.question, isNotEmpty);
      expect(m.volume, isNonNegative);
      expect(m.volume24hr, isNonNegative);
      expect(m.liquidity, isNonNegative);
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('clobTokenIds are parsed from JSON-encoded string', () async {
      final markets = await client.getMarkets(active: true, limit: 10);
      final withTokens = markets.where((m) => m.clobTokenIds.isNotEmpty);
      if (withTokens.isEmpty) {
        // No markets with token IDs right now — skip.
        return;
      }
      final m = withTokens.first;
      expect(m.clobTokenIds.first, isNotEmpty,
          reason: 'clobTokenIds should be decoded from JSON string');
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  // ---------------------------------------------------------------------------
  // Single Market
  // ---------------------------------------------------------------------------

  group('GammaClient.getMarket', () {
    test('returns market by numeric id', () async {
      final markets = await client.getMarkets(active: true, limit: 1);
      if (markets.isEmpty) {
        markTestSkipped('No active markets available');
        return;
      }
      final id = markets.first.id;
      if (id == 0) {
        markTestSkipped('Market has no numeric id');
        return;
      }
      final market = await client.getMarket(id);
      expect(market.id, equals(id));
      expect(market.question, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  group('GammaClient.getEvents', () {
    test('returns a list of events', () async {
      final events = await client.getEvents(limit: 5);
      expect(events, isA<List<GammaEvent>>());
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('event fields are well-formed when events exist', () async {
      final events = await client.getEvents(active: true, limit: 5);
      if (events.isEmpty) return;

      final e = events.first;
      expect(e.id, greaterThan(0));
      expect(e.title, isNotEmpty);
      expect(e.slug, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  // ---------------------------------------------------------------------------
  // Tags
  // ---------------------------------------------------------------------------

  group('GammaClient.getTags', () {
    test('returns a non-empty list of tags', () async {
      final tags = await client.getTags();
      expect(tags, isA<List<Tag>>());
      expect(tags, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('tag fields are well-formed', () async {
      final tags = await client.getTags();
      expect(tags, isNotEmpty);

      final t = tags.first;
      expect(t.id, greaterThan(0));
      expect(t.label, isNotEmpty);
      expect(t.slug, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  group('GammaClient.searchMarkets', () {
    test('returns results for a broad query', () async {
      final results = await client.searchMarkets('election');
      expect(results, isA<List<GammaMarket>>());
      // May be empty if no matching markets — not an error.
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
