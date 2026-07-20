/// Polygon JSON-RPC client for on-chain reads and transaction submission.
///
/// Provides the minimal subset of eth_* methods needed for approval checks
/// and raw transaction broadcast.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pointycastle/digests/keccak.dart';

import '../utils/contracts.dart';

/// Thin Polygon JSON-RPC client.
///
/// All methods throw [PolygonRpcException] on non-200 HTTP responses or
/// JSON-RPC errors returned by the node.
class PolygonRpc {
  final String rpcUrl;
  final http.Client _http;

  PolygonRpc({String? rpcUrl, http.Client? httpClient})
    : rpcUrl = rpcUrl ?? PolymarketContracts.polygonRpc,
      _http = httpClient ?? http.Client();

  /// Execute a read-only contract call (`eth_call`).
  ///
  /// [from] optionally sets the caller (`msg.sender`) — required to simulate
  /// balance/allowance-gated calls (e.g. dry-running a settlement) as a real
  /// account. Returns the raw hex result string (e.g. `"0x0000...0001"`).
  Future<String> ethCall({
    required String to,
    required String data,
    String? from,
  }) async {
    final result = await _rpc('eth_call', [
      {'to': to, 'data': data, 'from': ?from},
      'latest',
    ]);
    return result as String;
  }

  /// Get native POL balance for [address], in wei.
  Future<BigInt> getBalance(String address) async {
    final result = await _rpc('eth_getBalance', [address, 'latest']);
    return BigInt.parse((result as String).substring(2), radix: 16);
  }

  /// Get the transaction count (nonce) for [address].
  Future<int> getTransactionCount(String address) async {
    final result = await _rpc('eth_getTransactionCount', [address, 'latest']);
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
        final statusHex =
            (receipt as Map<String, dynamic>)['status'] as String?;
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
  static Uint8List encodeApprove(String spender, {BigInt? amount}) {
    // selector: keccak256("approve(address,uint256)")[0:4] = 0x095ea7b3
    const selector = '095ea7b3';
    return _encodeSelectorAndArgs(selector, [
      _encodeAddress(spender),
      _encodeUint256(amount ?? _maxUint256),
    ]);
  }

  /// `wrap(address _asset, address _to, uint256 _amount)` call data.
  static Uint8List encodeWrap({
    String asset = PolymarketContracts.usdc,
    required String to,
    required BigInt amount,
  }) {
    return _encodeSelectorAndArgs(_selector('wrap(address,address,uint256)'), [
      _encodeAddress(asset),
      _encodeAddress(to),
      _encodeUint256(amount),
    ]);
  }

  /// `unwrap(address _asset, address _to, uint256 _amount)` call data.
  static Uint8List encodeUnwrap({
    String asset = PolymarketContracts.usdc,
    required String to,
    required BigInt amount,
  }) {
    return _encodeSelectorAndArgs(
      _selector('unwrap(address,address,uint256)'),
      [_encodeAddress(asset), _encodeAddress(to), _encodeUint256(amount)],
    );
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

  /// `balanceOf(address account)` call data.
  static Uint8List encodeBalanceOf(String account) {
    // selector: keccak256("balanceOf(address)")[0:4] = 0x70a08231
    const selector = '70a08231';
    return _encodeSelectorAndArgs(selector, [_encodeAddress(account)]);
  }

  // ---------------------------------------------------------------------------
  // Conditional Token Framework (CTF) — split / merge / redeem calldata.
  //
  // Two routing options per market kind:
  // - Standard (binary) markets: the ConditionalTokens contract, which takes an
  //   explicit collateral token, parentCollectionId (zero), conditionId, and a
  //   partition / indexSets array.
  // - Neg-risk markets: the NegRiskAdapter, which handles the collateral token
  //   and parentCollectionId internally — callers pass only conditionId/amount.
  //
  // Binary markets use partition/indexSets `[1, 2]` (index 0 = YES, 1 = NO) and
  // parentCollectionId = 32 zero bytes. Amounts are pUSD base units (6 dp).
  // ---------------------------------------------------------------------------

  /// Standard binary partition / index sets for a two-outcome market.
  static final List<BigInt> binaryPartition = [BigInt.one, BigInt.two];

  static final Uint8List _zeroBytes32 = Uint8List(32);

  /// `splitPosition(address,bytes32,bytes32,uint256[],uint256)` on the CTF.
  static Uint8List encodeCtfSplit({
    required String collateralToken,
    required String conditionId,
    required BigInt amount,
    List<BigInt>? partition,
  }) {
    final part = partition ?? binaryPartition;
    // Head: collateral, parentCollectionId(0), conditionId, offset(partition), amount.
    final head = <Uint8List>[
      _encodeAddress(collateralToken),
      _zeroBytes32,
      _encodeBytes32(conditionId),
      _encodeUint256(BigInt.from(5 * 32)), // offset to the dynamic array tail
      _encodeUint256(amount),
    ];
    return _assemble(
      _selector('splitPosition(address,bytes32,bytes32,uint256[],uint256)'),
      head,
      _encodeUint256ArrayTail(part),
    );
  }

  /// `mergePositions(address,bytes32,bytes32,uint256[],uint256)` on the CTF.
  static Uint8List encodeCtfMerge({
    required String collateralToken,
    required String conditionId,
    required BigInt amount,
    List<BigInt>? partition,
  }) {
    final part = partition ?? binaryPartition;
    final head = <Uint8List>[
      _encodeAddress(collateralToken),
      _zeroBytes32,
      _encodeBytes32(conditionId),
      _encodeUint256(BigInt.from(5 * 32)),
      _encodeUint256(amount),
    ];
    return _assemble(
      _selector('mergePositions(address,bytes32,bytes32,uint256[],uint256)'),
      head,
      _encodeUint256ArrayTail(part),
    );
  }

  /// `redeemPositions(address,bytes32,bytes32,uint256[])` on the CTF.
  static Uint8List encodeCtfRedeem({
    required String collateralToken,
    required String conditionId,
    List<BigInt>? indexSets,
  }) {
    final sets = indexSets ?? binaryPartition;
    final head = <Uint8List>[
      _encodeAddress(collateralToken),
      _zeroBytes32,
      _encodeBytes32(conditionId),
      _encodeUint256(BigInt.from(4 * 32)),
    ];
    return _assemble(
      _selector('redeemPositions(address,bytes32,bytes32,uint256[])'),
      head,
      _encodeUint256ArrayTail(sets),
    );
  }

  /// `splitPosition(bytes32,uint256)` on the NegRiskAdapter.
  static Uint8List encodeNegRiskSplit({
    required String conditionId,
    required BigInt amount,
  }) =>
      _assemble(
        _selector('splitPosition(bytes32,uint256)'),
        [_encodeBytes32(conditionId), _encodeUint256(amount)],
      );

  /// `mergePositions(bytes32,uint256)` on the NegRiskAdapter.
  static Uint8List encodeNegRiskMerge({
    required String conditionId,
    required BigInt amount,
  }) =>
      _assemble(
        _selector('mergePositions(bytes32,uint256)'),
        [_encodeBytes32(conditionId), _encodeUint256(amount)],
      );

  /// `redeemPositions(bytes32,uint256[])` on the NegRiskAdapter.
  ///
  /// [amounts] holds the amount to redeem per outcome index.
  static Uint8List encodeNegRiskRedeem({
    required String conditionId,
    required List<BigInt> amounts,
  }) =>
      _assemble(
        _selector('redeemPositions(bytes32,uint256[])'),
        [_encodeBytes32(conditionId), _encodeUint256(BigInt.from(2 * 32))],
        _encodeUint256ArrayTail(amounts),
      );

  /// `convertPositions(bytes32,uint256,uint256)` on the NegRiskAdapter.
  static Uint8List encodeNegRiskConvert({
    required String marketId,
    required BigInt indexSet,
    required BigInt amount,
  }) =>
      _assemble(
        _selector('convertPositions(bytes32,uint256,uint256)'),
        [
          _encodeBytes32(marketId),
          _encodeUint256(indexSet),
          _encodeUint256(amount),
        ],
      );

  /// Assemble calldata from a 4-byte selector, fixed 32-byte head words, and an
  /// optional dynamic tail (already ABI-encoded).
  static Uint8List _assemble(
    String selectorHex,
    List<Uint8List> head, [
    Uint8List? tail,
  ]) {
    final tailBytes = tail ?? Uint8List(0);
    final out = Uint8List(4 + head.length * 32 + tailBytes.length);
    out.setRange(0, 4, _hexToBytes(selectorHex));
    var off = 4;
    for (final word in head) {
      out.setRange(off, off + 32, word);
      off += 32;
    }
    out.setRange(off, off + tailBytes.length, tailBytes);
    return out;
  }

  /// ABI tail for a `uint256[]`: length word followed by one word per element.
  static Uint8List _encodeUint256ArrayTail(List<BigInt> values) {
    final out = Uint8List(32 * (1 + values.length));
    out.setRange(0, 32, _encodeUint256(BigInt.from(values.length)));
    for (var i = 0; i < values.length; i++) {
      out.setRange(32 * (i + 1), 32 * (i + 2), _encodeUint256(values[i]));
    }
    return out;
  }

  /// Encode a 32-byte value (e.g. conditionId), left-aligned per `bytes32`.
  static Uint8List _encodeBytes32(String hex) {
    final h = hex.startsWith('0x') ? hex.substring(2) : hex;
    final bytes = _hexToBytes(h);
    final padded = Uint8List(32);
    padded.setRange(0, bytes.length > 32 ? 32 : bytes.length, bytes);
    return padded;
  }

  static Uint8List _encodeSelectorAndArgs(
    String selectorHex,
    List<Uint8List> args,
  ) {
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

  static String _selector(String signature) {
    final input = utf8.encode(signature);
    final digest = KeccakDigest(256)..update(input, 0, input.length);
    final output = Uint8List(32);
    digest.doFinal(output, 0);
    return output
        .take(4)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
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
