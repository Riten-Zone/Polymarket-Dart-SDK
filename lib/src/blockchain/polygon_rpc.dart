/// Polygon JSON-RPC client for on-chain reads and transaction submission.
///
/// Provides the minimal subset of eth_* methods needed for approval checks
/// and raw transaction broadcast.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../utils/contracts.dart';

/// Thin Polygon JSON-RPC client.
///
/// All methods throw [PolygonRpcException] on non-200 HTTP responses or
/// JSON-RPC errors returned by the node.
class PolygonRpc {
  final String rpcUrl;
  final http.Client _http;

  PolygonRpc({
    String? rpcUrl,
    http.Client? httpClient,
  })  : rpcUrl = rpcUrl ?? PolymarketContracts.polygonRpc,
        _http = httpClient ?? http.Client();

  /// Execute a read-only contract call (`eth_call`).
  ///
  /// Returns the raw hex result string (e.g. `"0x0000...0001"`).
  Future<String> ethCall({required String to, required String data}) async {
    final result = await _rpc('eth_call', [
      {'to': to, 'data': data},
      'latest',
    ]);
    return result as String;
  }

  /// Get the transaction count (nonce) for [address].
  Future<int> getTransactionCount(String address) async {
    final result =
        await _rpc('eth_getTransactionCount', [address, 'latest']);
    return int.parse((result as String).substring(2), radix: 16);
  }

  /// Get the current gas price in wei.
  Future<BigInt> getGasPrice() async {
    final result = await _rpc('eth_gasPrice', []);
    return BigInt.parse((result as String).substring(2), radix: 16);
  }

  /// Broadcast a signed raw transaction.
  ///
  /// Returns the transaction hash on success.
  /// Throws [PolygonRpcException] if the node rejects the transaction.
  Future<String> sendRawTransaction(String rawHex) async {
    final result = await _rpc('eth_sendRawTransaction', [rawHex]);
    return result as String;
  }

  /// Poll for a transaction receipt until it confirms or [maxAttempts] is reached.
  ///
  /// Returns `true` if the transaction succeeded (status = 1), `false` if it
  /// reverted, or `null` if it was not mined within the polling window.
  Future<bool?> waitForReceipt(
    String txHash, {
    int maxAttempts = 30,
    Duration interval = const Duration(seconds: 2),
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      await Future<void>.delayed(interval);
      final receipt = await _rpcNullable('eth_getTransactionReceipt', [txHash]);
      if (receipt != null) {
        final statusHex = (receipt as Map<String, dynamic>)['status'] as String?;
        if (statusHex != null) {
          return int.parse(statusHex.substring(2), radix: 16) == 1;
        }
      }
    }
    return null; // timed out
  }

  // ---------------------------------------------------------------------------

  Future<dynamic> _rpc(String method, List<dynamic> params) async {
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
      'id': 1,
    });
    final response = await _http.post(
      Uri.parse(rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json.containsKey('error')) {
      throw PolygonRpcException(method, json['error']);
    }
    return json['result'];
  }

  Future<dynamic> _rpcNullable(String method, List<dynamic> params) async {
    try {
      return await _rpc(method, params);
    } catch (_) {
      return null;
    }
  }

  void close() => _http.close();
}

/// ABI encoding helpers (no external ABI library required).
///
/// All encode functions return the full calldata including the 4-byte selector.
class AbiEncoder {
  static final _maxUint256 = (BigInt.one << 256) - BigInt.one;

  /// `approve(address spender, uint256 amount)` with MAX_UINT256.
  static Uint8List encodeApprove(String spender) {
    // selector: keccak256("approve(address,uint256)")[0:4] = 0x095ea7b3
    const selector = '095ea7b3';
    return _encodeSelectorAndArgs(selector, [
      _encodeAddress(spender),
      _encodeUint256(_maxUint256),
    ]);
  }

  /// `setApprovalForAll(address operator, bool approved)` with approved=true.
  static Uint8List encodeSetApprovalForAll(String operator) {
    // selector: keccak256("setApprovalForAll(address,bool)")[0:4] = 0xa22cb465
    const selector = 'a22cb465';
    return _encodeSelectorAndArgs(selector, [
      _encodeAddress(operator),
      _encodeBool(true),
    ]);
  }

  /// `isApprovedForAll(address owner, address operator)` call data.
  static Uint8List encodeIsApprovedForAll(String owner, String operator) {
    // selector: keccak256("isApprovedForAll(address,address)")[0:4] = 0xe985e9c5
    const selector = 'e985e9c5';
    return _encodeSelectorAndArgs(selector, [
      _encodeAddress(owner),
      _encodeAddress(operator),
    ]);
  }

  /// `allowance(address owner, address spender)` call data.
  static Uint8List encodeAllowance(String owner, String spender) {
    // selector: keccak256("allowance(address,address)")[0:4] = 0xdd62ed3e
    const selector = 'dd62ed3e';
    return _encodeSelectorAndArgs(selector, [
      _encodeAddress(owner),
      _encodeAddress(spender),
    ]);
  }

  static Uint8List _encodeSelectorAndArgs(
      String selectorHex, List<Uint8List> args) {
    final selector = _hexToBytes(selectorHex);
    final total = 4 + args.fold<int>(0, (s, a) => s + a.length);
    final result = Uint8List(total);
    result.setRange(0, 4, selector);
    var offset = 4;
    for (final arg in args) {
      result.setRange(offset, offset + arg.length, arg);
      offset += arg.length;
    }
    return result;
  }

  static Uint8List _encodeAddress(String address) {
    final hex = address.startsWith('0x') ? address.substring(2) : address;
    final bytes = _hexToBytes(hex);
    final padded = Uint8List(32);
    padded.setRange(32 - bytes.length, 32, bytes);
    return padded;
  }

  static Uint8List _encodeUint256(BigInt value) {
    final result = Uint8List(32);
    var v = value;
    for (var i = 31; i >= 0; i--) {
      result[i] = (v & BigInt.from(0xff)).toInt();
      v = v >> 8;
    }
    return result;
  }

  static Uint8List _encodeBool(bool value) {
    final result = Uint8List(32);
    result[31] = value ? 1 : 0;
    return result;
  }

  static Uint8List _hexToBytes(String hex) {
    final h = hex.startsWith('0x') ? hex.substring(2) : hex;
    final result = Uint8List(h.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}

/// Thrown when a Polygon JSON-RPC call fails.
class PolygonRpcException implements Exception {
  final String method;
  final dynamic error;

  const PolygonRpcException(this.method, this.error);

  @override
  String toString() => 'PolygonRpcException($method): $error';
}
