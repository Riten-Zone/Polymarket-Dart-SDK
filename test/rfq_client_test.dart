/// Integration tests for RfqClient — Request for Quote API.
///
/// Hits the live Polymarket CLOB RFQ API.
/// Most endpoints require Level 2 HMAC auth. Tests that need auth
/// load credentials from .env and are lenient — they catch
/// PolymarketApiException in case the test wallet is not RFQ-eligible.
///
/// Run with:
///   dart test test/rfq_client_test.dart --tags rfq
@Tags(['integration', 'rfq'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:polymarket_dart/polymarket_dart.dart';

void main() {
  // Load credentials from environment or .env file
  final privateKey = Platform.environment['PRIVATE_KEY'] ?? _loadEnv('PRIVATE_KEY');

  // ---------------------------------------------------------------------------
  // Public / unauthenticated
  // ---------------------------------------------------------------------------

  group('RfqClient.getBuilderLeaderboard (ClobClient)', () {
    late ClobClient clob;

    setUpAll(() {
      clob = ClobClient();
    });

    tearDownAll(() => clob.close());

    test('builder leaderboard returns a list (lenient — may be empty or 404)',
        () async {
      try {
        final entries = await clob.getBuilderLeaderboard(limit: 5);
        expect(entries, isA<List<BuilderLeaderboardEntry>>());
      } on PolymarketApiException catch (_) {
        // Path may not be available without builder auth — acceptable
      }
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  // ---------------------------------------------------------------------------
  // Authenticated (Level 2 required)
  // ---------------------------------------------------------------------------

  group('RfqClient — authenticated', () {
    late RfqClient rfq;
    late PrivateKeyWalletAdapter wallet;
    late ApiCredentials creds;
    bool authAvailable = false;

    setUpAll(() async {
      if (privateKey == null || privateKey.isEmpty) {
        return; // skip — no credentials
      }
      try {
        wallet = PrivateKeyWalletAdapter(privateKey);
        final clob = ClobClient(wallet: wallet);
        creds = await clob.createOrDeriveApiKey();
        clob.close();
        rfq = RfqClient(wallet: wallet, credentials: creds);
        authAvailable = true;
      } catch (_) {
        // auth setup failed — all auth tests will be skipped
      }
    });

    tearDownAll(() {
      if (authAvailable) rfq.close();
    });

    test('getRequests returns a paginated response (lenient)', () async {
      if (!authAvailable) {
        markTestSkipped('No .env credentials — skipping auth test');
        return;
      }
      try {
        final resp = await rfq.getRequests(GetRfqRequestsParams(limit: 5));
        expect(resp, isA<RfqPaginatedResponse<RfqRequest>>());
        expect(resp.data, isA<List<RfqRequest>>());
      } on PolymarketApiException catch (_) {
        // 404 / 403 expected if wallet is not RFQ-eligible
      }
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('getConfig returns a map (lenient)', () async {
      if (!authAvailable) {
        markTestSkipped('No .env credentials — skipping auth test');
        return;
      }
      try {
        final cfg = await rfq.getConfig();
        expect(cfg, isA<Map<String, dynamic>>());
      } on PolymarketApiException catch (_) {
        // Acceptable if not available
      }
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String? _loadEnv(String key) {
  try {
    final lines = File('.env').readAsLinesSync();
    for (final line in lines) {
      if (line.startsWith('$key=')) return line.substring(key.length + 1);
    }
  } catch (_) {}
  return null;
}
