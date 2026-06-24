/// pUSD collateral wrapping helpers.
///
/// Wrap sends USDC.e to the CollateralOnramp and receives pUSD.
/// Unwrap sends pUSD to the CollateralOfframp and receives USDC.e.
library;

import '../signing/private_key_wallet_adapter.dart';
import '../utils/contracts.dart';
import 'polygon_rpc.dart';

/// Result for a submitted and confirmed collateral transaction.
class CollateralTransactionResult {
  final String approvalTxHash;
  final String actionTxHash;
  final BigInt amount;

  const CollateralTransactionResult({
    required this.approvalTxHash,
    required this.actionTxHash,
    required this.amount,
  });
}

/// Sends pUSD collateral wrap and unwrap transactions on Polygon.
class CollateralClient {
  final PrivateKeyWalletAdapter wallet;
  final PolygonRpc _rpc;
  final bool _ownsRpc;

  CollateralClient({required this.wallet, String? rpcUrl, PolygonRpc? rpc})
    : _rpc = rpc ?? PolygonRpc(rpcUrl: rpcUrl),
      _ownsRpc = rpc == null;

  /// Wrap USDC.e into pUSD for the wallet address.
  Future<CollateralTransactionResult> wrapUsdcToPusd(
    BigInt amount, {
    String? recipient,
    void Function(String message)? onStatus,
  }) async {
    final owner = await wallet.getAddress();
    final to = recipient ?? owner;
    final log = onStatus ?? (_) {};

    final approvalHash = await _approveIfNeeded(
      token: PolymarketContracts.usdc,
      spender: PolymarketContracts.collateralOnramp,
      amount: amount,
      label: 'USDC.e -> CollateralOnramp',
      log: log,
    );

    final calldata = AbiEncoder.encodeWrap(to: to, amount: amount);
    final actionHash = await _sendAndWait(
      to: PolymarketContracts.collateralOnramp,
      data: '0x${_bytesToHex(calldata)}',
      label: 'wrap USDC.e -> pUSD',
      gasLimit: 180000,
      log: log,
    );

    return CollateralTransactionResult(
      approvalTxHash: approvalHash,
      actionTxHash: actionHash,
      amount: amount,
    );
  }

  /// Unwrap pUSD back into USDC.e for the wallet address.
  Future<CollateralTransactionResult> unwrapPusdToUsdc(
    BigInt amount, {
    String? recipient,
    void Function(String message)? onStatus,
  }) async {
    final owner = await wallet.getAddress();
    final to = recipient ?? owner;
    final log = onStatus ?? (_) {};

    final approvalHash = await _approveIfNeeded(
      token: PolymarketContracts.pusd,
      spender: PolymarketContracts.collateralOfframp,
      amount: amount,
      label: 'pUSD -> CollateralOfframp',
      log: log,
    );

    final calldata = AbiEncoder.encodeUnwrap(to: to, amount: amount);
    final actionHash = await _sendAndWait(
      to: PolymarketContracts.collateralOfframp,
      data: '0x${_bytesToHex(calldata)}',
      label: 'unwrap pUSD -> USDC.e',
      gasLimit: 180000,
      log: log,
    );

    return CollateralTransactionResult(
      approvalTxHash: approvalHash,
      actionTxHash: actionHash,
      amount: amount,
    );
  }

  /// Read ERC-20 balance for [owner].
  Future<BigInt> balanceOf({
    required String token,
    required String owner,
  }) async {
    final result = await _rpc.ethCall(
      to: token,
      data: '0x${_bytesToHex(AbiEncoder.encodeBalanceOf(owner))}',
    );
    return BigInt.parse(result.substring(2), radix: 16);
  }

  /// Read native POL balance for [owner], in wei.
  Future<BigInt> nativeBalance(String owner) => _rpc.getBalance(owner);

  /// Read ERC-20 allowance from [owner] to [spender].
  Future<BigInt> allowance({
    required String token,
    required String owner,
    required String spender,
  }) async {
    final result = await _rpc.ethCall(
      to: token,
      data: '0x${_bytesToHex(AbiEncoder.encodeAllowance(owner, spender))}',
    );
    return BigInt.parse(result.substring(2), radix: 16);
  }

  Future<String> _approveIfNeeded({
    required String token,
    required String spender,
    required BigInt amount,
    required String label,
    required void Function(String) log,
  }) async {
    final owner = await wallet.getAddress();
    final current = await allowance(
      token: token,
      owner: owner,
      spender: spender,
    );
    if (current >= amount) {
      log('$label allowance already sufficient: $current');
      return 'skipped';
    }

    final calldata = AbiEncoder.encodeApprove(spender, amount: amount);
    return _sendAndWait(
      to: token,
      data: '0x${_bytesToHex(calldata)}',
      label: 'approve $label',
      gasLimit: 90000,
      log: log,
    );
  }

  Future<String> _sendAndWait({
    required String to,
    required String data,
    required String label,
    required int gasLimit,
    required void Function(String) log,
  }) async {
    final owner = await wallet.getAddress();
    final nonce = await _rpc.getTransactionCount(owner);
    final gasPrice = await _rpc.getGasPrice();
    final rawTx = await wallet.signRawTransaction(
      to: to,
      data: data,
      nonce: nonce,
      gasPrice: gasPrice,
      gasLimit: gasLimit,
    );

    final hash = await _rpc.sendRawTransaction(rawTx);
    log('$label submitted: $hash');

    final success = await _rpc.waitForReceipt(
      hash,
      maxAttempts: 60,
      interval: const Duration(seconds: 2),
    );
    if (success == true) {
      log('$label confirmed: $hash');
      return hash;
    }
    if (success == false) {
      throw StateError('$label reverted: $hash');
    }
    throw StateError('$label did not confirm before timeout: $hash');
  }

  void close() {
    if (_ownsRpc) {
      _rpc.close();
    }
  }
}

String _bytesToHex(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
