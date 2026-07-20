/// pUSD position settlement — split, merge, redeem, and neg-risk convert.
///
/// Two market kinds are supported:
/// - **Standard binary markets** route through the ConditionalTokens (CTF)
///   contract, operating on the caller's own positions.
/// - **Neg-risk markets** route through the NegRiskAdapter, which pulls the
///   caller's collateral / outcome tokens and therefore needs an ERC-20
///   allowance (split) or CTF operator approval (merge / redeem / convert).
///
/// Every operation has a `simulate…` method that runs a read-only `eth_call`
/// **as the wallet address** — use it to confirm a settlement would succeed
/// before broadcasting. `execute…` methods set any required approval, then sign
/// and send the transaction.
///
/// ```dart
/// final settle = SettlementClient(wallet: wallet);
///
/// // Always dry-run first — no funds, no gas:
/// await settle.simulateRedeemStandard(conditionId: '0x...');
///
/// // Then execute for real:
/// final hash = await settle.redeemStandard(conditionId: '0x...');
/// ```
library;

import '../signing/private_key_wallet_adapter.dart';
import '../utils/contracts.dart';
import 'polygon_rpc.dart';

/// Thrown when a settlement dry-run (`simulate…`) reverts on-chain. The
/// [reason] is the decoded revert string when the node provides one.
class SettlementSimulationException implements Exception {
  final String operation;
  final String reason;
  const SettlementSimulationException(this.operation, this.reason);

  @override
  String toString() => 'SettlementSimulationException($operation): $reason';
}

/// Signs and sends CTF / neg-risk settlement transactions on Polygon.
class SettlementClient {
  final PrivateKeyWalletAdapter wallet;
  final PolygonRpc _rpc;
  final bool _ownsRpc;

  /// Collateral token used for standard-market split/merge/redeem
  /// (defaults to pUSD).
  final String collateral;

  SettlementClient({
    required this.wallet,
    String? rpcUrl,
    PolygonRpc? rpc,
    String? collateral,
  })  : _rpc = rpc ?? PolygonRpc(rpcUrl: rpcUrl),
        _ownsRpc = rpc == null,
        collateral = collateral ?? PolymarketContracts.pusd;

  // ---------------------------------------------------------------------------
  // Standard (binary) markets — ConditionalTokens
  // ---------------------------------------------------------------------------

  /// Simulate `splitPosition` on the CTF as the wallet address (read-only).
  Future<void> simulateSplitStandard({
    required String conditionId,
    required BigInt amount,
  }) =>
      _simulate(
        'splitStandard',
        to: PolymarketContracts.ctf,
        data: AbiEncoder.encodeCtfSplit(
            collateralToken: collateral, conditionId: conditionId, amount: amount),
      );

  /// Split `amount` pUSD into a full outcome-token set. Approves pUSD to the
  /// CTF if needed, then sends. Returns the transaction hash.
  Future<String> splitStandard({
    required String conditionId,
    required BigInt amount,
    void Function(String)? onStatus,
  }) async {
    final log = onStatus ?? (_) {};
    await _approveErc20IfNeeded(
      token: collateral,
      spender: PolymarketContracts.ctf,
      amount: amount,
      label: 'pUSD -> CTF',
      log: log,
    );
    return _send(
      to: PolymarketContracts.ctf,
      data: AbiEncoder.encodeCtfSplit(
          collateralToken: collateral, conditionId: conditionId, amount: amount),
      label: 'splitStandard',
      gasLimit: 250000,
      log: log,
    );
  }

  /// Simulate `mergePositions` on the CTF (read-only).
  Future<void> simulateMergeStandard({
    required String conditionId,
    required BigInt amount,
  }) =>
      _simulate(
        'mergeStandard',
        to: PolymarketContracts.ctf,
        data: AbiEncoder.encodeCtfMerge(
            collateralToken: collateral, conditionId: conditionId, amount: amount),
      );

  /// Merge a full outcome-token set back into `amount` pUSD. Operates on the
  /// caller's own tokens, so no approval is required.
  Future<String> mergeStandard({
    required String conditionId,
    required BigInt amount,
    void Function(String)? onStatus,
  }) =>
      _send(
        to: PolymarketContracts.ctf,
        data: AbiEncoder.encodeCtfMerge(
            collateralToken: collateral, conditionId: conditionId, amount: amount),
        label: 'mergeStandard',
        gasLimit: 250000,
        log: onStatus ?? (_) {},
      );

  /// Simulate `redeemPositions` on the CTF (read-only).
  Future<void> simulateRedeemStandard({
    required String conditionId,
    List<BigInt>? indexSets,
  }) =>
      _simulate(
        'redeemStandard',
        to: PolymarketContracts.ctf,
        data: AbiEncoder.encodeCtfRedeem(
            collateralToken: collateral,
            conditionId: conditionId,
            indexSets: indexSets),
      );

  /// Redeem resolved winning positions for pUSD. Operates on the caller's own
  /// tokens, so no approval is required.
  Future<String> redeemStandard({
    required String conditionId,
    List<BigInt>? indexSets,
    void Function(String)? onStatus,
  }) =>
      _send(
        to: PolymarketContracts.ctf,
        data: AbiEncoder.encodeCtfRedeem(
            collateralToken: collateral,
            conditionId: conditionId,
            indexSets: indexSets),
        label: 'redeemStandard',
        gasLimit: 250000,
        log: onStatus ?? (_) {},
      );

  // ---------------------------------------------------------------------------
  // Neg-risk markets — NegRiskAdapter
  // ---------------------------------------------------------------------------

  /// Simulate `splitPosition` on the NegRiskAdapter (read-only).
  Future<void> simulateSplitNegRisk({
    required String conditionId,
    required BigInt amount,
  }) =>
      _simulate(
        'splitNegRisk',
        to: PolymarketContracts.negRiskAdapter,
        data: AbiEncoder.encodeNegRiskSplit(
            conditionId: conditionId, amount: amount),
      );

  /// Split via the NegRiskAdapter. Approves pUSD to the adapter if needed.
  Future<String> splitNegRisk({
    required String conditionId,
    required BigInt amount,
    void Function(String)? onStatus,
  }) async {
    final log = onStatus ?? (_) {};
    await _approveErc20IfNeeded(
      token: collateral,
      spender: PolymarketContracts.negRiskAdapter,
      amount: amount,
      label: 'pUSD -> NegRiskAdapter',
      log: log,
    );
    return _send(
      to: PolymarketContracts.negRiskAdapter,
      data: AbiEncoder.encodeNegRiskSplit(
          conditionId: conditionId, amount: amount),
      label: 'splitNegRisk',
      gasLimit: 300000,
      log: log,
    );
  }

  /// Simulate `mergePositions` on the NegRiskAdapter (read-only).
  Future<void> simulateMergeNegRisk({
    required String conditionId,
    required BigInt amount,
  }) =>
      _simulate(
        'mergeNegRisk',
        to: PolymarketContracts.negRiskAdapter,
        data: AbiEncoder.encodeNegRiskMerge(
            conditionId: conditionId, amount: amount),
      );

  /// Merge via the NegRiskAdapter. Grants the adapter CTF operator approval if
  /// needed (it moves your outcome tokens on your behalf).
  Future<String> mergeNegRisk({
    required String conditionId,
    required BigInt amount,
    void Function(String)? onStatus,
  }) async {
    final log = onStatus ?? (_) {};
    await _approveOperatorIfNeeded(PolymarketContracts.negRiskAdapter, log);
    return _send(
      to: PolymarketContracts.negRiskAdapter,
      data: AbiEncoder.encodeNegRiskMerge(
          conditionId: conditionId, amount: amount),
      label: 'mergeNegRisk',
      gasLimit: 300000,
      log: log,
    );
  }

  /// Simulate `redeemPositions` on the NegRiskAdapter (read-only).
  Future<void> simulateRedeemNegRisk({
    required String conditionId,
    required List<BigInt> amounts,
  }) =>
      _simulate(
        'redeemNegRisk',
        to: PolymarketContracts.negRiskAdapter,
        data: AbiEncoder.encodeNegRiskRedeem(
            conditionId: conditionId, amounts: amounts),
      );

  /// Redeem resolved neg-risk positions. Grants the adapter CTF operator
  /// approval if needed.
  Future<String> redeemNegRisk({
    required String conditionId,
    required List<BigInt> amounts,
    void Function(String)? onStatus,
  }) async {
    final log = onStatus ?? (_) {};
    await _approveOperatorIfNeeded(PolymarketContracts.negRiskAdapter, log);
    return _send(
      to: PolymarketContracts.negRiskAdapter,
      data: AbiEncoder.encodeNegRiskRedeem(
          conditionId: conditionId, amounts: amounts),
      label: 'redeemNegRisk',
      gasLimit: 300000,
      log: log,
    );
  }

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Whether [operator] is an approved ERC-1155 operator for [owner] on the CTF.
  Future<bool> isCtfOperatorApproved({
    required String owner,
    required String operator,
  }) async {
    final res = await _rpc.ethCall(
      to: PolymarketContracts.ctf,
      data: '0x${_hex(AbiEncoder.encodeIsApprovedForAll(owner, operator))}',
    );
    return BigInt.parse(res.substring(2), radix: 16) == BigInt.one;
  }

  void close() {
    if (_ownsRpc) _rpc.close();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _simulate(
    String op, {
    required String to,
    required List<int> data,
  }) async {
    final owner = await wallet.getAddress();
    try {
      await _rpc.ethCall(to: to, data: '0x${_hex(data)}', from: owner);
    } on PolygonRpcException catch (e) {
      throw SettlementSimulationException(op, e.error.toString());
    }
  }

  Future<void> _approveErc20IfNeeded({
    required String token,
    required String spender,
    required BigInt amount,
    required String label,
    required void Function(String) log,
  }) async {
    final owner = await wallet.getAddress();
    final res = await _rpc.ethCall(
      to: token,
      data: '0x${_hex(AbiEncoder.encodeAllowance(owner, spender))}',
    );
    final current = BigInt.parse(res.substring(2), radix: 16);
    if (current >= amount) {
      log('$label allowance already sufficient');
      return;
    }
    await _send(
      to: token,
      data: AbiEncoder.encodeApprove(spender, amount: amount),
      label: 'approve $label',
      gasLimit: 90000,
      log: log,
    );
  }

  Future<void> _approveOperatorIfNeeded(
    String operator,
    void Function(String) log,
  ) async {
    final owner = await wallet.getAddress();
    if (await isCtfOperatorApproved(owner: owner, operator: operator)) {
      log('CTF operator already approved for $operator');
      return;
    }
    await _send(
      to: PolymarketContracts.ctf,
      data: AbiEncoder.encodeSetApprovalForAll(operator),
      label: 'setApprovalForAll $operator',
      gasLimit: 90000,
      log: log,
    );
  }

  Future<String> _send({
    required String to,
    required List<int> data,
    required String label,
    required int gasLimit,
    required void Function(String) log,
  }) async {
    final owner = await wallet.getAddress();
    final nonce = await _rpc.getTransactionCount(owner);
    final gasPrice = await _rpc.getGasPrice();
    final rawTx = await wallet.signRawTransaction(
      to: to,
      data: '0x${_hex(data)}',
      nonce: nonce,
      gasPrice: gasPrice,
      gasLimit: gasLimit,
    );
    final hash = await _rpc.sendRawTransaction(rawTx);
    log('$label submitted: $hash');
    final ok = await _rpc.waitForReceipt(hash,
        maxAttempts: 60, interval: const Duration(seconds: 2));
    if (ok == true) {
      log('$label confirmed: $hash');
      return hash;
    }
    if (ok == false) throw StateError('$label reverted: $hash');
    throw StateError('$label did not confirm before timeout: $hash');
  }

  static String _hex(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
