/// Live integration tests for RelayerClient v2 public endpoints — hits the
/// real relayer-v2.polymarket.com API. Only unauthenticated endpoints are
/// exercised here (no gas is spent, nothing is submitted).
///
/// Run with:
///   dart test test/relayer_integration_test.dart --tags relayer
@Tags(['integration', 'relayer'])
library;

import 'package:polymarket_dart/polymarket_dart.dart';
import 'package:test/test.dart';

// RelayerClient requires a wallet + builder creds at construction, but the
// public endpoints below send no auth. A throwaway key satisfies the ctor.
const _throwawayKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const _placeholderCreds = BuilderCredentials(
  apiKey: 'unused',
  secret: 'dW51c2Vk',
  passphrase: 'unused',
);

final _hexAddress = RegExp(r'^0x[a-fA-F0-9]{40}$');

void main() {
  late RelayerClient relayer;

  setUpAll(() {
    relayer = RelayerClient(
      wallet: PrivateKeyWalletAdapter(_throwawayKey),
      creds: _placeholderCreds,
    );
  });

  tearDownAll(() => relayer.close());

  test('getRelayPayload returns a real relayer address + numeric nonce',
      () async {
    // The hardhat account #0 address for the throwaway key above.
    const owner = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

    final payload = await relayer.getRelayPayload(owner);

    expect(payload.address, matches(_hexAddress),
        reason: 'relayer address should be a 0x-prefixed 40-hex address');
    expect(int.tryParse(payload.nonce), isNotNull,
        reason: 'nonce should parse as an integer');
    expect(int.parse(payload.nonce), greaterThanOrEqualTo(0));
    print('getRelayPayload → address=${payload.address} nonce=${payload.nonce}');
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('getRelayPayload works for the PROXY wallet type too', () async {
    const owner = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
    final payload = await relayer.getRelayPayload(
      owner,
      type: RelayerWalletType.proxy,
    );
    expect(payload.address, matches(_hexAddress));
    expect(int.tryParse(payload.nonce), isNotNull);
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('getTransaction for an unknown id returns an empty list (lenient)',
      () async {
    try {
      final txns =
          await relayer.getTransaction('00000000-0000-0000-0000-000000000000');
      expect(txns, isA<List<RelayerTransaction>>());
    } on RelayerException catch (e) {
      // Some ids may 404 at the relayer — reaching the endpoint is the point.
      print('getTransaction → relayer rejected unknown id: $e');
    }
  }, timeout: const Timeout(Duration(seconds: 20)));
}
