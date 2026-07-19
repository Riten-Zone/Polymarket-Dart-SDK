/// Live integration tests for settlement calldata — read-only `eth_call`
/// against the real CTF and NegRiskAdapter contracts on Polygon. No funds are
/// moved: each call reverts inside the target function's own logic, which
/// proves our selector/ABI reaches the real function (a wrong selector would
/// fail differently).
///
/// Run with:
///   dart test test/settlement_integration_test.dart --tags integration
@Tags(['integration'])
library;

import 'dart:typed_data';

import 'package:polymarket_dart/polymarket_dart.dart';
import 'package:test/test.dart';

String _hex(Uint8List b) =>
    '0x${b.map((x) => x.toRadixString(16).padLeft(2, '0')).join()}';

// A real, resolved condition id (France World Cup combo market leg).
const _cond =
    '0xc41f543ccb7a1a35a200c28096cc2e5c2351c54546087f4f6cf5c4ef3e0c1aa5';

void main() {
  late PolygonRpc rpc;
  setUpAll(() => rpc = PolygonRpc());

  test('CTF.redeemPositions calldata reaches the real function', () async {
    final data = AbiEncoder.encodeCtfRedeem(
      collateralToken: PolymarketContracts.usdc,
      conditionId: _cond,
    );
    expect(_hex(Uint8List.sublistView(data, 0, 4)), equals('0x01b7037c'));

    try {
      final res =
          await rpc.ethCall(to: PolymarketContracts.ctf, data: _hex(data));
      // A bare success (0x) is also fine — the function ran.
      print('CTF.redeem eth_call returned: "$res"');
    } on PolygonRpcException catch (e) {
      // Contract-logic revert = selector reached redeemPositions.
      print('CTF.redeem reverted (as expected): ${e.error}');
      expect(e.toString().toLowerCase(), contains('erc1155'),
          reason: 'should revert inside CTF logic, not on an unknown selector');
    }
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('NegRiskAdapter.splitPosition calldata reaches the real function',
      () async {
    final data = AbiEncoder.encodeNegRiskSplit(
      conditionId: _cond,
      amount: BigInt.from(1000000), // 1 pUSD
    );
    expect(_hex(Uint8List.sublistView(data, 0, 4)), equals('0xa3d7da1d'));

    try {
      final res = await rpc.ethCall(
          to: PolymarketContracts.negRiskAdapter, data: _hex(data));
      print('NegRisk.split eth_call returned: "$res"');
    } on PolygonRpcException catch (e) {
      // TRANSFER_FROM_FAILED = split logic ran and tried to pull collateral.
      print('NegRisk.split reverted (as expected): ${e.error}');
      expect(e.toString().toUpperCase(), contains('TRANSFER_FROM_FAILED'),
          reason: 'should revert inside splitPosition, not on an unknown selector');
    }
  }, timeout: const Timeout(Duration(seconds: 20)));
}
