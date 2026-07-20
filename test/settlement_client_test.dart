/// Offline tests for SettlementClient — mocks the JSON-RPC transport to verify
/// the dry-run (`simulate…`) payloads (from / to / selector), revert handling,
/// and the operator-approval read. No network, no funds.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polymarket_dart/polymarket_dart.dart';
import 'package:test/test.dart';

const _testKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const _owner = '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266'; // hardhat #0
const _cond =
    '0xc41f543ccb7a1a35a200c28096cc2e5c2351c54546087f4f6cf5c4ef3e0c1aa5';

/// Builds a SettlementClient whose eth_call is answered by [onEthCall].
/// [onEthCall] receives the params map ({to, data, from}) and returns either a
/// success hex result or throws to signal a revert.
SettlementClient _clientForEthCall(
  String Function(Map<String, dynamic> params) onEthCall,
) {
  final mock = MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final method = body['method'] as String;
    final params = (body['params'] as List).first as Map<String, dynamic>;
    if (method == 'eth_call') {
      try {
        final result = onEthCall(params);
        return http.Response(jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': result}), 200);
      } catch (e) {
        return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': 1,
              'error': {'code': 3, 'message': e.toString()}
            }),
            200);
      }
    }
    return http.Response(jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': '0x'}), 200);
  });
  return SettlementClient(
    wallet: PrivateKeyWalletAdapter(_testKey),
    rpc: PolygonRpc(httpClient: mock),
  );
}

void main() {
  test('simulateSplitStandard targets CTF with from=owner and split selector',
      () async {
    Map<String, dynamic>? captured;
    final client = _clientForEthCall((params) {
      captured = params;
      return '0x'; // success
    });

    await client.simulateSplitStandard(
        conditionId: _cond, amount: BigInt.from(1000000));

    expect((captured!['to'] as String).toLowerCase(),
        equals(PolymarketContracts.ctf.toLowerCase()));
    expect((captured!['from'] as String).toLowerCase(), equals(_owner));
    expect(captured!['data'] as String, startsWith('0x72ce4275'));
    client.close();
  });

  test('simulateRedeemNegRisk targets the neg-risk adapter with its selector',
      () async {
    Map<String, dynamic>? captured;
    final client = _clientForEthCall((params) {
      captured = params;
      return '0x';
    });

    await client.simulateRedeemNegRisk(
        conditionId: _cond, amounts: [BigInt.one, BigInt.zero]);

    expect((captured!['to'] as String).toLowerCase(),
        equals(PolymarketContracts.negRiskAdapter.toLowerCase()));
    expect(captured!['data'] as String, startsWith('0xdbeccb23'));
    client.close();
  });

  test('simulate wraps an on-chain revert in SettlementSimulationException',
      () async {
    final client = _clientForEthCall((params) {
      throw 'execution reverted: TRANSFER_FROM_FAILED';
    });

    expect(
      () => client.simulateSplitNegRisk(
          conditionId: _cond, amount: BigInt.from(1000000)),
      throwsA(isA<SettlementSimulationException>()),
    );
    client.close();
  });

  test('isCtfOperatorApproved decodes the boolean result', () async {
    final approved = _clientForEthCall((_) => '0x${'0' * 63}1'); // true
    expect(
      await approved.isCtfOperatorApproved(
          owner: _owner, operator: PolymarketContracts.negRiskAdapter),
      isTrue,
    );
    approved.close();

    final notApproved = _clientForEthCall((_) => '0x${'0' * 64}'); // false
    expect(
      await notApproved.isCtfOperatorApproved(
          owner: _owner, operator: PolymarketContracts.negRiskAdapter),
      isFalse,
    );
    notApproved.close();
  });
}
