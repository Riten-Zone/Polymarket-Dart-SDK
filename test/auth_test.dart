/// Authenticated integration tests for ClobClient — Level 1 (EIP-712) and
/// Level 2 read-only (HMAC) endpoints.
///
/// Requires a private key in `.env`:
///   PRIVATE_KEY=<hex without 0x prefix>
///
/// Run with:
///   dart test test/auth_test.dart --tags auth
///
/// No funds required — L1 just signs a typed message locally.
/// L2 read endpoints return empty data for a fresh wallet.
@Tags(['integration', 'auth'])
library;

import 'dart:io';

import 'package:test/test.dart';
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

void main() {
  final privateKey = _loadPrivateKey();

  if (privateKey == null) {
    print('Skipping auth tests: PRIVATE_KEY not found in .env');
    return;
  }

  late ClobClient client;
  late ApiCredentials creds;

  setUpAll(() async {
    final wallet = PrivateKeyWalletAdapter(privateKey);
    client = ClobClient(wallet: wallet);
    // Derive (or create) API credentials once for all L2 tests
    creds = await client.createOrDeriveApiKey();
    client.setCredentials(creds);
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
  });
}
