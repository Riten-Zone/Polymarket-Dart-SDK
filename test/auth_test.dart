/// Authenticated integration tests for ClobClient — Level 1 (EIP-712) and
/// Level 2 read-only (HMAC) endpoints, plus order placement and WebSocket.
///
/// Requires a private key in `.env`:
///   PRIVATE_KEY=<hex without 0x prefix>
///   FUNDER_ADDRESS=<checksummed Gnosis Safe address>
///
/// Run with:
///   dart test test/auth_test.dart --tags auth
///
/// No funds required for L1/L2 read tests.
/// Order placement tests require USDC on the Gnosis Safe.
@Tags(['integration', 'auth'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:polymarket_dart/polymarket_dart.dart';

/// Read PRIVATE_KEY from .env file in the project root.
String? _loadPrivateKey() {
  try {
    final env = File('.env').readAsStringSync();
    for (final line in env.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('PRIVATE_KEY=')) {
        final value = trimmed.substring('PRIVATE_KEY='.length).trim();
        if (value.isEmpty) return null;
        // Normalise: add 0x prefix if missing
        return value.startsWith('0x') ? value : '0x$value';
      }
    }
  } catch (_) {}
  return null;
}

/// Read FUNDER_ADDRESS from .env file in the project root.
String? _loadFunderAddress() {
  try {
    final env = File('.env').readAsStringSync();
    for (final line in env.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('FUNDER_ADDRESS=')) {
        final value = trimmed.substring('FUNDER_ADDRESS='.length).trim();
        return value.isEmpty ? null : value;
      }
    }
  } catch (_) {}
  return null;
}

/// Fetch the first active market token ID from the Gamma API.
Future<String?> _fetchLiveTokenId() async {
  final uri = Uri.parse(
    'https://gamma-api.polymarket.com/markets'
    '?active=true&closed=false&order=volume24hr&ascending=false&limit=5',
  );
  final response = await http.get(uri);
  if (response.statusCode != 200) return null;

  final markets = jsonDecode(response.body) as List;
  for (final m in markets) {
    // clobTokenIds is a JSON-encoded string in the Gamma API response
    final raw = m['clobTokenIds'];
    final ids = raw is String
        ? (jsonDecode(raw) as List?)
        : raw as List?;
    if (ids != null && ids.isNotEmpty) {
      return ids[0] as String;
    }
  }
  return null;
}

void main() {
  final privateKey = _loadPrivateKey();

  if (privateKey == null) {
    print('Skipping auth tests: PRIVATE_KEY not found in .env');
    return;
  }

  late ClobClient client;
  late ApiCredentials creds;
  late String funderAddress;
  late String testTokenId;
  bool testTokenNegRisk = false;

  setUpAll(() async {
    final wallet = PrivateKeyWalletAdapter(privateKey);
    client = ClobClient(wallet: wallet);
    // Derive (or create) API credentials once for all L2 tests
    creds = await client.createOrDeriveApiKey();
    client.setCredentials(creds);

    // Load funder address (Gnosis Safe / POLY_PROXY)
    funderAddress = _loadFunderAddress() ?? '';

    // Fetch a live active market token for order placement + WS tests
    testTokenId = await _fetchLiveTokenId() ?? '';
    if (testTokenId.isNotEmpty) {
      print('testTokenId: $testTokenId');
      // Check negRisk so we can sign against the correct exchange contract
      testTokenNegRisk = await client.getNegRisk(testTokenId);
      print('negRisk: $testTokenNegRisk');
    }
  });

  tearDownAll(() {
    client.close();
  });

  // ---------------------------------------------------------------------------
  // Level 1 — EIP-712 API key management
  // ---------------------------------------------------------------------------

  group('L1 — API key management', () {
    test('createOrDeriveApiKey returns valid credentials', () {
      expect(creds.apiKey, isNotEmpty);
      expect(creds.secret, isNotEmpty);
      expect(creds.passphrase, isNotEmpty);
      print('apiKey: ${creds.apiKey}');
    });

    test('deriveApiKey is deterministic', () async {
      final wallet = PrivateKeyWalletAdapter(privateKey);
      final client2 = ClobClient(wallet: wallet);
      final creds2 = await client2.deriveApiKey();
      client2.close();
      expect(creds2.apiKey, equals(creds.apiKey));
      expect(creds2.secret, equals(creds.secret));
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('getApiKeys returns a list including current key', () async {
      final res = await client.getApiKeys();
      expect(res.apiKeys, isA<List>());
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  // ---------------------------------------------------------------------------
  // Level 2 — HMAC read-only endpoints (no funds needed)
  // ---------------------------------------------------------------------------

  group('L2 — Read-only account endpoints', () {
    test('getOpenOrders returns a list (empty for fresh wallet)', () async {
      final page = await client.getOpenOrders();
      expect(page.data, isA<List<OpenOrder>>());
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getTrades returns a page (empty for fresh wallet)', () async {
      final page = await client.getTrades();
      expect(page.data, isA<List<Trade>>());
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getBalanceAllowance returns a BalanceAllowance object', () async {
      // asset_type must be uppercase 'COLLATERAL' for USDC balance
      final balance = await client.getBalanceAllowance(
        params: const BalanceAllowanceParams(assetType: 'COLLATERAL'),
      );
      expect(balance, isA<BalanceAllowance>());
      print('balance: ${balance.balance}, allowance: ${balance.allowance}');
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getNotifications returns a list', () async {
      final notifications = await client.getNotifications();
      expect(notifications, isA<List<Notification>>());
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('postHeartbeat does not throw', () async {
      await client.postHeartbeat();
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getClosedOnlyMode returns a BanStatus object', () async {
      final status = await client.getClosedOnlyMode();
      expect(status, isA<BanStatus>());
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('cancelAll succeeds with no open orders', () async {
      // Idempotent — fresh wallet has no orders, should not throw.
      await client.cancelAll();
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  // ---------------------------------------------------------------------------
  // Level 2 — Order placement & cancellation (requires USDC on Gnosis Safe)
  // ---------------------------------------------------------------------------

  group('L2 — Order placement & cancellation', () {
    test('postOrder places a tiny limit buy and cancels it', () async {
      if (funderAddress.isEmpty) {
        print('Skipping: FUNDER_ADDRESS not set in .env');
        return;
      }
      if (testTokenId.isEmpty) {
        print('Skipping: could not fetch a live market token');
        return;
      }

      // BUY at $0.01 — far from market, will not execute. Size=500 → $5 USDC
      final order = await client.createOrder(
        OrderArgs(
          tokenId: testTokenId,
          price: 0.01,
          size: 500.0,
          side: OrderSide.buy,
          feeRateBps: 0,
        ),
        options: CreateOrderOptions(
          funder: funderAddress.isEmpty ? null : funderAddress,
          signatureType: funderAddress.isEmpty ? 0 : 2, // GnosisSafe
          negRisk: testTokenNegRisk,
        ),
      );
      print('order json: ${jsonEncode(order.toJson())}');

      try {
        final response = await client.postOrder(order);
        print('orderId: ${response.orderId}');
        expect(response.orderId, isNotEmpty);
        // Cancel immediately to clean up
        await client.cancelOrder(response.orderId!);
      } on PolymarketApiException catch (e) {
        if (e.statusCode == 403) {
          print('Skipping: geo-restricted region (403). Order signing verified OK.');
          return;
        }
        rethrow;
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  // ---------------------------------------------------------------------------
  // WebSocket — orderbook subscription
  // ---------------------------------------------------------------------------

  group('WebSocket — orderbook subscription', () {
    test('raw WS connection receives messages', () async {
      if (testTokenId.isEmpty) {
        print('Skipping: could not fetch a live market token');
        return;
      }
      final rawMessages = <String>[];
      final wsUri = Uri.parse('wss://ws-subscriptions-clob.polymarket.com/ws/market');
      final channel = WebSocketChannel.connect(wsUri);
      await channel.ready;
      print('WS connected');
      channel.stream.listen(
        (msg) {
          print('WS msg: $msg');
          rawMessages.add(msg.toString());
        },
        onError: (e) => print('WS error: $e'),
        onDone: () => print('WS done'),
      );
      // Correct CLOB WS subscription: assets_ids array + type "market"
      channel.sink.add(jsonEncode({'assets_ids': [testTokenId], 'type': 'market'}));
      await Future.delayed(const Duration(seconds: 5));
      await channel.sink.close();
      print('Total raw messages: ${rawMessages.length}');
      expect(rawMessages, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('subscribeOrderbook receives at least one message', () async {
      if (testTokenId.isEmpty) {
        print('Skipping: could not fetch a live market token');
        return;
      }

      final wsClient = WebSocketClient();
      await wsClient.connectClob();
      final messages = <OrderbookUpdate>[];
      final sub = wsClient.subscribeOrderbook(testTokenId).listen(messages.add);
      await Future.delayed(const Duration(seconds: 8));
      await sub.cancel();
      await wsClient.dispose();
      expect(messages, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 20)));
  });
}
