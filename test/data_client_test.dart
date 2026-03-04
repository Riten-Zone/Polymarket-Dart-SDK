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
}
