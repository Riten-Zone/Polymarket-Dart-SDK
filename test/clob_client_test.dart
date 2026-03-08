/// Integration tests for ClobClient public endpoints (no auth required).
///
/// These tests hit the live Polymarket CLOB API.
/// Run selectively: dart test test/clob_client_test.dart --tags integration
///
/// Skip these in CI unless you have network access.
@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:polymarket_dart/polymarket_dart.dart';

/// Fetch the top active markets by 24h volume from the Gamma API.
/// Returns a list of token IDs for the markets with the highest volume.
Future<List<String>> _fetchHighVolumeTokenIds({int limit = 5}) async {
  final uri = Uri.parse(
    'https://gamma-api.polymarket.com/markets'
    '?active=true&closed=false&order=volume24hr&ascending=false&limit=$limit',
  );
  final response = await http.get(uri);
  if (response.statusCode != 200) return [];

  final markets = jsonDecode(response.body) as List;
  final tokenIds = <String>[];
  for (final m in markets) {
    // clobTokenIds is a JSON-encoded string in the Gamma API response
    final raw = m['clobTokenIds'];
    final ids = raw is String
        ? (jsonDecode(raw) as List?)
        : raw as List?;
    if (ids != null && ids.isNotEmpty) {
      tokenIds.add(ids[0] as String);
    }
  }
  return tokenIds;
}

void main() {
  late ClobClient client;

  // Resolved once for the whole test run — high-volume active market token IDs.
  late List<String> liveTokenIds;
  String? liveTokenId;

  setUpAll(() async {
    liveTokenIds = await _fetchHighVolumeTokenIds();
    liveTokenId = liveTokenIds.isNotEmpty ? liveTokenIds.first : null;
  });

  setUp(() {
    client = ClobClient();
  });

  tearDown(() {
    client.close();
  });

  group('Health', () {
    test('getOk returns true', () async {
      final ok = await client.getOk();
      expect(ok, isTrue);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getServerTime returns a recent unix timestamp', () async {
      final ts = await client.getServerTime();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(ts, greaterThan(now - 60));
      expect(ts, lessThan(now + 60));
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  group('Markets', () {
    test('getMarkets returns a page with data', () async {
      final page = await client.getMarkets();
      expect(page.data, isNotEmpty);
      expect(page.data.first.conditionId, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getMarkets pagination cursor is returned', () async {
      final page = await client.getMarkets();
      expect(page.nextCursor, isNotNull);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getMarket by condition ID returns valid market', () async {
      final page = await client.getMarkets();
      final first = page.data.first;
      final market = await client.getMarket(first.conditionId);
      expect(market.conditionId, equals(first.conditionId));
      expect(market.tokens, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  group('Orderbook', () {
    test('getOrderBook returns bids and asks', () async {
      if (liveTokenId == null) {
        markTestSkipped('No active market token available');
        return;
      }
      final book = await client.getOrderBook(liveTokenId!);
      expect(book.asset, isNotEmpty);
      expect(book.bids, isA<List<OrderLevel>>());
      expect(book.asks, isA<List<OrderLevel>>());
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getOrderBooks for multiple high-volume tokens returns list', () async {
      if (liveTokenIds.isEmpty) {
        markTestSkipped('No active market tokens available');
        return;
      }
      final params = liveTokenIds
          .take(3)
          .map((id) => BookParams(tokenId: id))
          .toList();
      final books = await client.getOrderBooks(params);
      expect(books, isA<List<OrderBookSummary>>());
      expect(books.length, greaterThan(0));
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  group('Pricing', () {
    test('getMidpoint returns a price string', () async {
      if (liveTokenId == null) {
        markTestSkipped('No active market token available');
        return;
      }
      final mid = await client.getMidpoint(liveTokenId!);
      expect(mid, isNotEmpty);
      expect(double.tryParse(mid), isNotNull);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getPrice BUY returns a price string', () async {
      if (liveTokenId == null) {
        markTestSkipped('No active market token available');
        return;
      }
      final price = await client.getPrice(liveTokenId!, 'BUY');
      expect(price, isNotEmpty);
      expect(double.tryParse(price), isNotNull);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getSpread returns a spread string', () async {
      if (liveTokenId == null) {
        markTestSkipped('No active market token available');
        return;
      }
      final spread = await client.getSpread(liveTokenId!);
      expect(spread, isNotEmpty);
      expect(double.tryParse(spread), isNotNull);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getLastTradePrice returns a price string', () async {
      if (liveTokenId == null) {
        markTestSkipped('No active market token available');
        return;
      }
      final price = await client.getLastTradePrice(liveTokenId!);
      expect(price, isNotEmpty);
      expect(double.tryParse(price), isNotNull);
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  group('Market config', () {
    test('getTickSize returns a valid tick size string', () async {
      if (liveTokenId == null) {
        markTestSkipped('No active market token available');
        return;
      }
      final tickSize = await client.getTickSize(liveTokenId!);
      expect(['0.1', '0.01', '0.001', '0.0001'], contains(tickSize));
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getNegRisk returns a boolean', () async {
      if (liveTokenId == null) {
        markTestSkipped('No active market token available');
        return;
      }
      final negRisk = await client.getNegRisk(liveTokenId!);
      expect(negRisk, isA<bool>());
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getFeeRateBps returns a non-negative integer', () async {
      if (liveTokenId == null) {
        markTestSkipped('No active market token available');
        return;
      }
      final bps = await client.getFeeRateBps(liveTokenId!);
      expect(bps, greaterThanOrEqualTo(0));
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  group('Price history', () {
    test('getPricesHistory returns a list of price points', () async {
      if (liveTokenId == null) {
        markTestSkipped('No active market token available');
        return;
      }
      // Fetch the condition ID for this token from the market list
      final page = await client.getMarkets();
      final conditionId = page.data.first.conditionId;
      final points = await client.getPricesHistory(
        PriceHistoryParams(
          market: conditionId,
          interval: '1w',
          fidelity: '10',
        ),
      );
      expect(points, isA<List<PricePoint>>());
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  group('Error handling', () {
    test('throws PolymarketApiException for invalid condition ID', () async {
      expect(
        () => client.getMarket('invalid-id-that-does-not-exist'),
        throwsA(isA<PolymarketApiException>()),
      );
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('requiresWallet error is thrown when wallet not set', () {
      expect(
        () => client.createApiKey(),
        throwsA(isA<StateError>()),
      );
    });

    test('requiresCredentials error when credentials not set', () {
      final clientWithWallet = ClobClient(
        wallet: PrivateKeyWalletAdapter(
          '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
        ),
      );
      expect(
        () => clientWithWallet.postOrder(
          const SignedOrder(
            salt: '1',
            maker: '0x1',
            signer: '0x1',
            taker: '0x0',
            tokenId: '1',
            makerAmount: '1',
            takerAmount: '1',
            expiration: '0',
            nonce: '0',
            feeRateBps: '0',
            side: 0,
            signatureType: 0,
            signature: '0x',
          ),
        ),
        throwsA(isA<StateError>()),
      );
      clientWithWallet.close();
    });
  });

  // ---------------------------------------------------------------------------
  // Rewards (Level 2 — HMAC required)
  // ---------------------------------------------------------------------------

  group('Rewards', () {
    late ClobClient authClient;
    bool authAvailable = false;

    setUpAll(() async {
      final pk = _loadEnv('PRIVATE_KEY');
      if (pk == null || pk.isEmpty) return;
      try {
        final wallet = PrivateKeyWalletAdapter(pk);
        final bootstrap = ClobClient(wallet: wallet);
        final creds = await bootstrap.createOrDeriveApiKey();
        bootstrap.close();
        authClient = ClobClient(wallet: wallet, credentials: creds);
        authAvailable = true;
      } catch (_) {}
    });

    tearDownAll(() {
      if (authAvailable) authClient.close();
    });

    test('getRewardPercentages does not throw a Dart error', () async {
      if (!authAvailable) { markTestSkipped('No .env credentials'); return; }
      try {
        final result = await authClient.getRewardPercentages();
        expect(result, isA<Map<String, dynamic>>());
        print('getRewardPercentages → $result');
      } on PolymarketApiException catch (e) {
        print('getRewardPercentages → $e');
      }
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('getCurrentRewards does not throw a Dart error', () async {
      if (!authAvailable) { markTestSkipped('No .env credentials'); return; }
      try {
        final result = await authClient.getCurrentRewards();
        expect(result, isA<Map<String, dynamic>>());
        print('getCurrentRewards → $result');
      } on PolymarketApiException catch (e) {
        print('getCurrentRewards → $e');
      }
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('getEarningsForDay does not throw a Dart error', () async {
      if (!authAvailable) { markTestSkipped('No .env credentials'); return; }
      try {
        final result = await authClient.getEarningsForDay('2026-03-01');
        expect(result, isA<Map<String, dynamic>>());
        print('getEarningsForDay → $result');
      } on PolymarketApiException catch (e) {
        print('getEarningsForDay → $e');
      }
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('getTotalEarningsForDay does not throw a Dart error', () async {
      if (!authAvailable) { markTestSkipped('No .env credentials'); return; }
      try {
        final result = await authClient.getTotalEarningsForDay('2026-03-01');
        expect(result, isA<Map<String, dynamic>>());
        print('getTotalEarningsForDay → $result');
      } on PolymarketApiException catch (e) {
        print('getTotalEarningsForDay → $e');
      }
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}

String? _loadEnv(String key) {
  try {
    final lines = File('.env').readAsLinesSync();
    for (final line in lines) {
      if (line.startsWith('$key=')) return line.substring(key.length + 1);
    }
  } catch (_) {}
  return null;
}
