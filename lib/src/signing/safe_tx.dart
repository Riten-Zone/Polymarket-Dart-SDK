/// Gnosis Safe EIP-712 SafeTx hashing and multisend encoding.
///
/// Used by [RelayerClient] to build and sign Safe transactions for the
/// Polymarket gasless relayer API.
library;

import 'dart:typed_data';

import 'package:pointycastle/digests/keccak.dart';

import '../utils/contracts.dart';
import '../blockchain/polygon_rpc.dart' show AbiEncoder;

// ---------------------------------------------------------------------------
// SafeTx type and domain hashes (Gnosis Safe v1.3.0)
// ---------------------------------------------------------------------------

/// keccak256("EIP712Domain(uint256 chainId,address verifyingContract)")
final _domainTypeHash = _keccak256(
  _strToBytes('EIP712Domain(uint256 chainId,address verifyingContract)'),
);

/// keccak256 of the SafeTx type string (all fields, no spaces after commas).
final _safeTxTypeHash = _keccak256(
  _strToBytes(
    'SafeTx(address to,uint256 value,bytes data,uint8 operation,'
    'uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,'
    'address gasToken,address refundReceiver,uint256 nonce)',
  ),
);

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Compute the EIP-712 SafeTx digest that the EOA must sign.
///
/// Mirrors `create_struct_hash()` from `py_builder_relayer_client/builder/safe.py`.
///
/// All gas params are zero; gasToken and refundReceiver are the zero address.
///
/// Returns the 32-byte digest: `keccak256("\x19\x01" + domainSep + safeTxStructHash)`.
Uint8List hashSafeTx({
  required String safeAddress,
  required int nonce,
  required String to,
  required Uint8List data,
  int operation = 1, // DelegateCall for multisend
  int chainId = 137,
}) {
  // Domain separator
  final domainSep = _keccak256(_concat([
    _domainTypeHash,
    _encodeUint256(BigInt.from(chainId)),
    _encodeAddress(safeAddress),
  ]));

  // dataHash = keccak256(data)
  final dataHash = _keccak256(data);

  // SafeTx struct hash
  final structHash = _keccak256(_concat([
    _safeTxTypeHash,
    _encodeAddress(to),
    _encodeUint256(BigInt.zero),        // value = 0
    dataHash,                            // bytes data → keccak256(data)
    _encodeUint8(operation),             // operation
    _encodeUint256(BigInt.zero),        // safeTxGas = 0
    _encodeUint256(BigInt.zero),        // baseGas = 0
    _encodeUint256(BigInt.zero),        // gasPrice = 0
    _encodeAddress(PolymarketChain.zeroAddress), // gasToken
    _encodeAddress(PolymarketChain.zeroAddress), // refundReceiver
    _encodeUint256(BigInt.from(nonce)),
  ]));

  // EIP-712 final digest: \x19\x01 + domainSep + structHash
  final payload = Uint8List(66);
  payload[0] = 0x19;
  payload[1] = 0x01;
  payload.setRange(2, 34, domainSep);
  payload.setRange(34, 66, structHash);
  return _keccak256(payload);
}

/// Encode 6 Polymarket approval transactions into a Gnosis Safe multisend calldata.
///
/// Returns the full multisend calldata (`multiSend(bytes)`) as a hex string
/// with 0x prefix, and the target address (MULTISEND_ADDRESS).
({String to, String data}) encodeApprovalMultisend() {
  final txns = [
    (to: PolymarketContracts.usdc, data: AbiEncoder.encodeApprove(PolymarketContracts.ctfExchange)),
    (to: PolymarketContracts.usdc, data: AbiEncoder.encodeApprove(PolymarketContracts.negRiskExchange)),
    (to: PolymarketContracts.usdc, data: AbiEncoder.encodeApprove(PolymarketContracts.negRiskAdapter)),
    (to: PolymarketContracts.ctf, data: AbiEncoder.encodeSetApprovalForAll(PolymarketContracts.ctfExchange)),
    (to: PolymarketContracts.ctf, data: AbiEncoder.encodeSetApprovalForAll(PolymarketContracts.negRiskExchange)),
    (to: PolymarketContracts.ctf, data: AbiEncoder.encodeSetApprovalForAll(PolymarketContracts.negRiskAdapter)),
  ];

  return (
    to: PolymarketContracts.multisend,
    data: _encodeMultisend(txns),
  );
}

// ---------------------------------------------------------------------------
// Multisend encoding
// ---------------------------------------------------------------------------

/// Encode a list of transactions as Gnosis Safe multisend calldata.
///
/// Each tx is packed as: `uint8(operation=0) + address(20) + uint256(value=0)
/// + uint256(dataLen) + bytes(data)`.
/// All are concatenated and wrapped in `multiSend(bytes)`.
String _encodeMultisend(List<({String to, Uint8List data})> txns) {
  final parts = <Uint8List>[];

  for (final tx in txns) {
    final toBytes = _hexToBytes(tx.to);
    final dataLen = tx.data.length;

    // uint8(0) = Call operation
    // address(20 bytes)
    // uint256 value = 0 (32 bytes)
    // uint256 dataLen (32 bytes)
    // bytes data
    final packed = Uint8List(1 + 20 + 32 + 32 + dataLen);
    var offset = 0;

    packed[offset] = 0; // operation = Call
    offset += 1;

    packed.setRange(offset, offset + 20, toBytes);
    offset += 20;

    // value = 0 (32 bytes, already zeroed)
    offset += 32;

    // dataLen as uint256 big-endian
    final lenBytes = _bigIntToBytes32(BigInt.from(dataLen));
    packed.setRange(offset, offset + 32, lenBytes);
    offset += 32;

    packed.setRange(offset, offset + dataLen, tx.data);

    parts.add(packed);
  }

  // Concatenate all packed txns
  final concatenated = _concatAll(parts);

  // ABI-encode as bytes: offset(32) + length(32) + data (padded to 32)
  final dataLen = concatenated.length;
  final paddedLen = (dataLen + 31) & ~31;
  final abiEncoded = Uint8List(32 + 32 + paddedLen);
  // offset = 0x20 (32) — pointer to the bytes value
  abiEncoded[31] = 32;
  // length
  final lenBytes = _bigIntToBytes32(BigInt.from(dataLen));
  abiEncoded.setRange(32, 64, lenBytes);
  // data
  abiEncoded.setRange(64, 64 + dataLen, concatenated);

  // multiSend(bytes) selector = 0x8d80ff0a
  final selector = Uint8List.fromList([0x8d, 0x80, 0xff, 0x0a]);
  final calldata = _concat([selector, abiEncoded]);

  return '0x${_bytesToHex(calldata)}';
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

class PolymarketChain {
  static const String zeroAddress = '0x0000000000000000000000000000000000000000';
}

Uint8List _keccak256(Uint8List data) {
  final digest = KeccakDigest(256);
  final hash = Uint8List(digest.digestSize);
  digest.update(data, 0, data.length);
  digest.doFinal(hash, 0);
  return hash;
}

Uint8List _encodeAddress(String address) {
  final hex = address.startsWith('0x') ? address.substring(2) : address;
  final bytes = _hexToBytes(hex);
  final padded = Uint8List(32);
  padded.setRange(32 - bytes.length, 32, bytes);
  return padded;
}

Uint8List _encodeUint256(BigInt value) {
  return _bigIntToBytes32(value);
}

Uint8List _encodeUint8(int value) {
  final result = Uint8List(32);
  result[31] = value & 0xff;
  return result;
}

Uint8List _bigIntToBytes32(BigInt value) {
  final result = Uint8List(32);
  var v = value;
  for (var i = 31; i >= 0; i--) {
    result[i] = (v & BigInt.from(0xff)).toInt();
    v = v >> 8;
  }
  return result;
}

Uint8List _concat(List<Uint8List> parts) {
  final total = parts.fold<int>(0, (s, p) => s + p.length);
  final result = Uint8List(total);
  var offset = 0;
  for (final part in parts) {
    result.setRange(offset, offset + part.length, part);
    offset += part.length;
  }
  return result;
}

Uint8List _concatAll(List<Uint8List> parts) => _concat(parts);

Uint8List _hexToBytes(String hex) {
  final h = hex.startsWith('0x') ? hex.substring(2) : hex;
  final result = Uint8List(h.length ~/ 2);
  for (var i = 0; i < result.length; i++) {
    result[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}

Uint8List _strToBytes(String s) => Uint8List.fromList(s.codeUnits);

String _bytesToHex(Uint8List bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
