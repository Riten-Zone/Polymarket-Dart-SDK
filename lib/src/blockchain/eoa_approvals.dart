/// On-chain token approvals for EOA wallets via direct Polygon JSON-RPC.
///
/// Mirrors `ensure_token_approvals()` from Polymarket_MM's `set_approval.py`.
/// Checks current on-chain state before submitting transactions — idempotent.
///
/// **Requirements:** The EOA must hold MATIC to pay Polygon gas fees.
/// For gasless Gnosis Safe approvals use [RelayerClient.runApprovals] instead.
library;

import '../signing/private_key_wallet_adapter.dart';
import '../utils/contracts.dart';
import 'polygon_rpc.dart';

/// Check and set all required Polymarket token approvals for an EOA wallet.
///
/// Submits up to 7 Polygon transactions (skipping any already approved):
/// - `CTF.setApprovalForAll` → CTF Exchange, NegRisk Adapter, NegRisk Exchange
/// - `USDC.approve(MAX)` → CTF Contract, CTF Exchange, NegRisk Adapter, NegRisk Exchange
///
/// Each transaction is waited on for confirmation before proceeding.
/// Throws [PolygonRpcException] if the node rejects a transaction.
///
/// [wallet] — the EOA wallet used for signing.
/// [rpcUrl] — Polygon JSON-RPC endpoint (defaults to public drpc.org node).
/// [onStatus] — optional callback for status messages (defaults to print).
Future<void> ensureEoaApprovals(
  PrivateKeyWalletAdapter wallet, {
  String? rpcUrl,
  void Function(String message)? onStatus,
}) async {
  final rpc = PolygonRpc(rpcUrl: rpcUrl);
  final address = await wallet.getAddress();
  final log = onStatus ?? print;

  log('Checking EOA approvals for ${address.substring(0, 10)}...');

  try {
    // --- 1. ERC-1155 setApprovalForAll (conditional tokens → exchanges) -----
    log('ERC-1155 Conditional Token Approvals:');
    final erc1155Targets = [
      ('CTF Exchange', PolymarketContracts.ctfExchange),
      ('NegRisk Adapter', PolymarketContracts.negRiskAdapter),
      ('NegRisk Exchange', PolymarketContracts.negRiskExchange),
    ];

    for (final (name, exchange) in erc1155Targets) {
      final callData = AbiEncoder.encodeIsApprovedForAll(address, exchange);
      final result = await rpc.ethCall(
        to: PolymarketContracts.ctf,
        data: '0x${_bytesToHex(callData)}',
      );
      final isApproved = BigInt.parse(result.substring(2), radix: 16) == BigInt.one;

      if (isApproved) {
        log('  ✓ CTF → $name: already approved');
        continue;
      }

      log('  ⏳ CTF → $name: setting approval...');
      final txData = AbiEncoder.encodeSetApprovalForAll(exchange);
      await _sendAndWait(
        wallet: wallet,
        rpc: rpc,
        address: address,
        to: PolymarketContracts.ctf,
        data: '0x${_bytesToHex(txData)}',
        label: 'CTF → $name',
        log: log,
      );
    }

    // --- 2. ERC-20 USDC approve (USDC → all targets) ------------------------
    log('USDC Approvals:');
    final usdcTargets = [
      ('CTF Contract', PolymarketContracts.ctf),
      ('CTF Exchange', PolymarketContracts.ctfExchange),
      ('NegRisk Adapter', PolymarketContracts.negRiskAdapter),
      ('NegRisk Exchange', PolymarketContracts.negRiskExchange),
    ];

    for (final (name, spender) in usdcTargets) {
      final callData = AbiEncoder.encodeAllowance(address, spender);
      final result = await rpc.ethCall(
        to: PolymarketContracts.usdc,
        data: '0x${_bytesToHex(callData)}',
      );
      final allowance = BigInt.parse(result.substring(2), radix: 16);

      // Consider approved if allowance > 1000 USDC (1e9 in 6-decimal micro-units)
      if (allowance > BigInt.from(1_000_000_000)) {
        log('  ✓ USDC → $name: already approved');
        continue;
      }

      log('  ⏳ USDC → $name: setting approval...');
      final txData = AbiEncoder.encodeApprove(spender);
      await _sendAndWait(
        wallet: wallet,
        rpc: rpc,
        address: address,
        to: PolymarketContracts.usdc,
        data: '0x${_bytesToHex(txData)}',
        label: 'USDC → $name',
        log: log,
      );
    }

    log('✅ All EOA token approvals complete!');
  } finally {
    rpc.close();
  }
}

Future<void> _sendAndWait({
  required PrivateKeyWalletAdapter wallet,
  required PolygonRpc rpc,
  required String address,
  required String to,
  required String data,
  required String label,
  required void Function(String) log,
}) async {
  final nonce = await rpc.getTransactionCount(address);
  final gasPrice = await rpc.getGasPrice();

  final rawTx = await wallet.signRawTransaction(
    to: to,
    data: data,
    nonce: nonce,
    gasPrice: gasPrice,
  );

  final txHash = await rpc.sendRawTransaction(rawTx);
  log('  ⏳ $label: tx ${txHash.substring(0, 18)}... waiting...');

  final success = await rpc.waitForReceipt(txHash);
  if (success == true) {
    log('  ✅ $label: approved');
  } else if (success == false) {
    throw Exception('$label: transaction reverted (hash: $txHash)');
  } else {
    log('  ⚠️  $label: tx pending — may need more time (hash: $txHash)');
  }
}

String _bytesToHex(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
