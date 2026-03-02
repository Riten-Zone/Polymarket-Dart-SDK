/// Integration tests for ClobClient public endpoints (no auth required).
///
/// These tests hit the live Polymarket CLOB API.
/// Run selectively: dart test test/clob_client_test.dart
///
/// Skip these in CI unless you have network access.
@Tags(['integration'])
library;

import 'package:test/test.dart';
import 'package:polymarket_dart/polymarket_dart.dart';

// A real market condition ID (Trump 2024 win market — settled, always available)
const kTestConditionId =
    '0x5c0a010e984e5e1a0ec56f564e07e63c36c6b9bd09c8d4c2dcf91e9ca37c9df';

// A real YES token ID for the above market
const kTestTokenId =
    '21742633143463906290569050155826241533067272736897614950488156847949938836455';

void main() {
  late ClobClient client;

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
      // Most pages have a nextCursor
      expect(page.nextCursor, isNotNull);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getMarket by condition ID returns valid market', () async {
      // Get a real condition ID from the first page
      final page = await client.getMarkets();
      final first = page.data.first;
      final market = await client.getMarket(first.conditionId);
      expect(market.conditionId, equals(first.conditionId));
      expect(market.tokens, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  group('Orderbook', () {
    test('getOrderBook returns bids and asks', () async {
      final book = await client.getOrderBook(kTestTokenId);
      expect(book.asset, isNotEmpty);
      // Book may be empty for settled markets but structure should be valid
      expect(book.bids, isA<List<OrderLevel>>());
      expect(book.asks, isA<List<OrderLevel>>());
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getOrderBooks for multiple tokens returns list', () async {
      final books = await client.getOrderBooks([
        BookParams(tokenId: kTestTokenId),
      ]);
      expect(books, isA<List<OrderBookSummary>>());
      expect(books.length, equals(1));
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  group('Pricing', () {
    test('getMidpoint returns a price string', () async {
      final mid = await client.getMidpoint(kTestTokenId);
      expect(mid, isNotEmpty);
      final price = double.tryParse(mid);
      expect(price, isNotNull);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getPrice BUY returns a price string', () async {
      final price = await client.getPrice(kTestTokenId, 'BUY');
      expect(price, isNotEmpty);
      expect(double.tryParse(price), isNotNull);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getSpread returns a spread string', () async {
      final spread = await client.getSpread(kTestTokenId);
      expect(spread, isNotEmpty);
      expect(double.tryParse(spread), isNotNull);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getLastTradePrice returns a price string', () async {
      final price = await client.getLastTradePrice(kTestTokenId);
      expect(price, isNotEmpty);
      expect(double.tryParse(price), isNotNull);
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  group('Market config', () {
    test('getTickSize returns a valid tick size string', () async {
      final tickSize = await client.getTickSize(kTestTokenId);
      expect(['0.1', '0.01', '0.001', '0.0001'], contains(tickSize));
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getNegRisk returns a boolean', () async {
      final negRisk = await client.getNegRisk(kTestTokenId);
      expect(negRisk, isA<bool>());
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getFeeRateBps returns a non-negative integer', () async {
      final bps = await client.getFeeRateBps(kTestTokenId);
      expect(bps, greaterThanOrEqualTo(0));
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  group('Price history', () {
    test('getPricesHistory returns a list of price points', () async {
      final points = await client.getPricesHistory(
        PriceHistoryParams(
          market: kTestConditionId,
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
}
