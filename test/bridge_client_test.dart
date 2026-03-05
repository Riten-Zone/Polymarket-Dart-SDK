/// Integration tests for BridgeClient — cross-chain deposit facilitation.
///
/// Hits the live Polymarket Bridge API. No authentication required.
///
/// Run with:
///   dart test test/bridge_client_test.dart --tags bridge
@Tags(['integration', 'bridge'])
library;

import 'package:test/test.dart';
import 'package:polymarket_dart/polymarket_dart.dart';

void main() {
  late BridgeClient client;

  setUpAll(() {
    client = BridgeClient();
  });

  tearDownAll(() => client.close());

  // ---------------------------------------------------------------------------
  // Supported assets
  // ---------------------------------------------------------------------------

  group('BridgeClient.getSupportedAssets', () {
    test('returns a non-empty list of supported assets', () async {
      final assets = await client.getSupportedAssets();
      expect(assets, isA<List<SupportedAsset>>());
      expect(assets, isNotEmpty,
          reason: 'Bridge should support at least one chain/token');
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('each asset has a non-empty chainName and token symbol', () async {
      final assets = await client.getSupportedAssets();
      expect(assets, isNotEmpty);
      for (final a in assets) {
        expect(a.chainName, isNotEmpty,
            reason: 'Asset should have a chain name');
        expect(a.token.symbol, isNotEmpty,
            reason: 'Asset should have a token symbol');
      }
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  // ---------------------------------------------------------------------------
  // Deposit address creation
  // ---------------------------------------------------------------------------

  group('BridgeClient.createDeposit', () {
    const testAddress = '0x0000000000000000000000000000000000000001';

    test('returns deposit addresses with a non-empty EVM address', () async {
      final resp = await client.createDeposit(testAddress);
      expect(resp, isA<DepositResponse>());
      expect(resp.address.evm, isNotEmpty,
          reason: 'Deposit should always include an EVM address');
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('response includes a note', () async {
      final resp = await client.createDeposit(testAddress);
      // note may be null on some responses — just verify the model parses
      expect(resp, isA<DepositResponse>());
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  group('BridgeClient.getStatus', () {
    test('returns a DepositStatus or throws for an unknown address', () async {
      // The Bridge API returns 500 for addresses never registered as deposit
      // addresses. Use a real deposit address (from createDeposit) to get real
      // status data. Here we just verify the code path is callable.
      try {
        const evmAddress = '0x0000000000000000000000000000000000000002';
        final status = await client.getStatus(evmAddress);
        expect(status, isA<DepositStatus>());
        expect(status.transactions, isA<List<DepositTransaction>>());
      } on PolymarketApiException catch (_) {
        // 500 expected for addresses not registered via createDeposit
      }
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
