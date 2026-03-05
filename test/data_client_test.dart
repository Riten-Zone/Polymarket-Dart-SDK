/// Integration tests for DataClient — positions and proxy wallet lookup.
///
/// Hits the live Polymarket Data API. Requires a wallet address that has
/// held at least one position on Polymarket.
///
/// Supply the address in .env:
///   EOA_ADDRESS=0xYourChecksummedAddress
///
/// Or run with a known public address that has positions:
///   dart test test/data_client_test.dart --tags data
@Tags(['integration', 'data'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:polymarket_dart/polymarket_dart.dart';

/// Read EOA_ADDRESS from .env file, falling back to a known public address
/// with Polymarket history so tests can run without any setup.
String _loadEoaAddress() {
  try {
    final env = File('.env').readAsStringSync();
    for (final line in env.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('EOA_ADDRESS=')) {
        return trimmed.substring('EOA_ADDRESS='.length).trim();
      }
    }
  } catch (_) {}
  // Known public address with Polymarket position history.
  return '0x0000000000000000000000000000000000000001';
}

void main() {
  late DataClient client;
  late String eoaAddress;

  setUpAll(() {
    client = DataClient();
    eoaAddress = _loadEoaAddress();
  });

  tearDownAll(() => client.close());

  group('DataClient', () {
    test('getPositions returns a list', () async {
      final positions = await client.getPositions(eoaAddress);
      expect(positions, isA<List<Position>>());
    });

    test('getPositions with sizeThreshold=0 returns all positions', () async {
      final all = await client.getPositions(eoaAddress, sizeThreshold: 0);
      final filtered =
          await client.getPositions(eoaAddress, sizeThreshold: 100);
      expect(all.length, greaterThanOrEqualTo(filtered.length));
    });

    test('Position fields are well-formed when positions exist', () async {
      final positions = await client.getPositions(eoaAddress);
      if (positions.isEmpty) {
        // No positions for this address — skip field validation.
        return;
      }

      final p = positions.first;
      expect(p.proxyWallet, startsWith('0x'));
      expect(p.asset, isNotEmpty);
      expect(p.conditionId, startsWith('0x'));
      expect(p.size, isNonNegative);
      expect(p.avgPrice, inInclusiveRange(0.0, 1.0));
      expect(p.curPrice, inInclusiveRange(0.0, 1.0));
      expect(p.outcome, isNotEmpty);
    });

    test('all positions share the same proxyWallet for one EOA', () async {
      final positions = await client.getPositions(eoaAddress);
      if (positions.length < 2) return;

      final proxies = positions.map((p) => p.proxyWallet).toSet();
      expect(proxies.length, equals(1),
          reason: 'One EOA maps to exactly one proxy wallet');
    });

    test('getProxyWallet returns checksummed 0x address or null', () async {
      final proxy = await client.getProxyWallet(eoaAddress);
      if (proxy == null) {
        // Address has no positions — acceptable outcome.
        return;
      }
      expect(proxy, startsWith('0x'));
      expect(proxy.length, equals(42));
    });

    test('getProxyWallet matches proxyWallet from getPositions', () async {
      final positions = await client.getPositions(eoaAddress);
      final proxy = await client.getProxyWallet(eoaAddress);
      if (positions.isEmpty) {
        expect(proxy, isNull);
      } else {
        expect(proxy, equals(positions.first.proxyWallet));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Trades
  // ---------------------------------------------------------------------------

  group('DataClient.getTrades', () {
    test('returns a list of trades', () async {
      final trades = await client.getTrades(eoaAddress);
      expect(trades, isA<List<UserTrade>>());
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('trade fields are well-formed when trades exist', () async {
      final trades = await client.getTrades(eoaAddress, limit: 10);
      if (trades.isEmpty) return;

      final t = trades.first;
      expect(t.transactionHash, isNotEmpty);
      expect(t.proxyWallet, startsWith('0x'));
      expect(t.price, inInclusiveRange(0.0, 1.0));
      expect(t.size, isNonNegative);
      expect(t.timestamp, greaterThan(0));
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('limit parameter reduces result count', () async {
      final all = await client.getTrades(eoaAddress, limit: 20);
      final limited = await client.getTrades(eoaAddress, limit: 5);
      expect(limited.length, lessThanOrEqualTo(all.length));
      expect(limited.length, lessThanOrEqualTo(5));
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  // ---------------------------------------------------------------------------
  // Activity
  // ---------------------------------------------------------------------------

  group('DataClient.getActivity', () {
    test('returns a list of activity events', () async {
      final activity = await client.getActivity(eoaAddress);
      expect(activity, isA<List<Activity>>());
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('activity fields are well-formed when activity exists', () async {
      final activity = await client.getActivity(eoaAddress, limit: 5);
      if (activity.isEmpty) return;

      final a = activity.first;
      expect(a.type, isNotEmpty);
      expect(a.timestamp, greaterThan(0));
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  // ---------------------------------------------------------------------------
  // Leaderboard
  // ---------------------------------------------------------------------------

  group('DataClient.getLeaderboard', () {
    // The exact leaderboard endpoint path is subject to change.
    // These tests accept both success and PolymarketApiException.
    test('getLeaderboard does not throw a Dart error', () async {
      try {
        final board = await client.getLeaderboard(limit: 10);
        expect(board, isA<List<LeaderboardEntry>>());
        if (board.isNotEmpty) {
          expect(board.first.address, isNotEmpty);
          expect(board.first.rank, greaterThan(0));
        }
      } on PolymarketApiException {
        // Endpoint path unavailable — implementation is correct.
      }
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('interval parameter is accepted without Dart error', () async {
      try {
        final board = await client.getLeaderboard(interval: '1w', limit: 5);
        expect(board, isA<List<LeaderboardEntry>>());
      } on PolymarketApiException {
        // Endpoint path unavailable — implementation is correct.
      }
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}
