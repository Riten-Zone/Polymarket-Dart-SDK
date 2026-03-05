/// Polymarket gasless relayer client for Gnosis Safe token approvals.
///
/// Mirrors `RelayClient.execute()` from `py_builder_relayer_client`.
/// Submits a batch of 6 ERC-20/ERC-1155 approvals via one Safe multisend,
/// signed by the EOA and relayed by Polymarket (no MATIC required).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

import '../signing/private_key_wallet_adapter.dart';
import '../signing/safe_tx.dart';
import '../utils/contracts.dart';

/// Builder Program API credentials.
///
/// Obtain from https://polymarket.com/settings?tab=builder
class BuilderCredentials {
  final String apiKey;
  final String secret;
  final String passphrase;

  const BuilderCredentials({
    required this.apiKey,
    required this.secret,
    required this.passphrase,
  });
}

/// Polymarket relayer client for gasless Gnosis Safe transactions.
///
/// ```dart
/// final relayer = RelayerClient(
///   wallet: wallet,
///   creds: BuilderCredentials(
///     apiKey: '...',
///     secret: '...',
///     passphrase: '...',
///   ),
/// );
/// await relayer.runApprovals(funderAddress);
/// ```
class RelayerClient {
  final PrivateKeyWalletAdapter _wallet;
  final BuilderCredentials _creds;
  final String _relayerUrl;
  final http.Client _http;

  RelayerClient({
    required PrivateKeyWalletAdapter wallet,
    required BuilderCredentials creds,
    String? relayerUrl,
    http.Client? httpClient,
  })  : _wallet = wallet,
        _creds = creds,
        _relayerUrl = (relayerUrl ?? PolymarketContracts.relayerUrl)
            .replaceAll(RegExp(r'/$'), ''),
        _http = httpClient ?? http.Client();

  /// Submit all 6 required Polymarket token approvals for [safeAddress].
  ///
  /// Gasless — Polymarket's relayer covers the Polygon gas fees.
  ///
  /// Mirrors `wallet.py run_approvals()` and `RelayClient.execute()`.
  Future<void> runApprovals(
    String safeAddress, {
    String metadata = 'Polymarket token approvals',
    void Function(String)? onStatus,
  }) async {
    final log = onStatus ?? print;
    final fromAddress = await _wallet.getAddress();

    // 1. Build multisend calldata for all 6 approvals
    final multisend = encodeApprovalMultisend();

    // 2. Get Safe nonce from relayer
    final nonce = await _getNonce(fromAddress);
    log('Safe nonce: $nonce');

    // 3. Hash the SafeTx (EIP-712 digest)
    final multisendData = Uint8List.fromList(_hexToBytes(multisend.data));
    final digest = hashSafeTx(
      safeAddress: safeAddress,
      nonce: nonce,
      to: multisend.to,
      data: multisendData,
      operation: 1, // DelegateCall for multisend
    );

    // 4. Sign with eth_sign (EIP-191 prefix) — Gnosis Safe expects v=31/32
    final signature = await _wallet.signEthMessage(digest);

    // 5. Repack signature: split r, s, v and re-encode as (uint256, uint256, uint8)
    final packedSig = _packSig(signature);

    // 6. Build and submit the relayer request
    final body = {
      'type': 'safe',
      'from': fromAddress,
      'to': multisend.to,
      'proxyWallet': safeAddress,
      'data': multisend.data,
      'value': '0',
      'nonce': nonce.toString(),
      'signature': packedSig,
      'signatureParams': {
        'gasPrice': '0',
        'operation': '1', // DelegateCall
        'safeTxnGas': '0',
        'baseGas': '0',
        'gasToken': '0x0000000000000000000000000000000000000000',
        'refundReceiver': '0x0000000000000000000000000000000000000000',
      },
      'metadata': metadata,
    };

    log('Submitting relayer transaction...');
    final transactionId = await _submit(body);
    log('Transaction ID: $transactionId — polling...');

    // 7. Poll until confirmed
    await _pollUntilDone(transactionId, log: log);
    log('✅ All Safe approvals complete!');
  }

  // ---------------------------------------------------------------------------

  Future<int> _getNonce(String fromAddress) async {
    final uri = Uri.parse(
        '$_relayerUrl/nonce?address=$fromAddress&type=safe');
    final response = await _http.get(uri, headers: _builderHeaders('GET', '/nonce?address=$fromAddress&type=safe'));
    _checkStatus(response, '/nonce');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return (json['nonce'] as num).toInt();
  }

  Future<String> _submit(Map<String, dynamic> body) async {
    const path = '/submit';
    final bodyStr = jsonEncode(body);
    final headers = {
      'Content-Type': 'application/json',
      ..._builderHeaders('POST', path, body: bodyStr),
    };
    final response = await _http.post(
      Uri.parse('$_relayerUrl$path'),
      headers: headers,
      body: bodyStr,
    );
    _checkStatus(response, path);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final id = json['transactionID'] as String?;
    if (id == null) {
      throw RelayerException('No transactionID in response: ${response.body}');
    }
    return id;
  }

  Future<void> _pollUntilDone(String transactionId,
      {int maxPolls = 20,
      Duration interval = const Duration(seconds: 3),
      void Function(String)? log}) async {
    final uri = Uri.parse('$_relayerUrl/transaction?id=$transactionId');
    for (var i = 0; i < maxPolls; i++) {
      await Future<void>.delayed(interval);
      final response = await _http.get(uri);
      if (response.statusCode != 200) continue;
      final json = jsonDecode(response.body);
      final List<dynamic> txns = json is List ? json : [json];
      if (txns.isEmpty) continue;
      final txn = txns[0] as Map<String, dynamic>;
      final state = txn['state'] as String?;
      if (state == 'confirmed' || state == 'success') return;
      if (state == 'failed' || state == 'reverted') {
        throw RelayerException(
            'Transaction $transactionId failed with state: $state');
      }
    }
    throw RelayerException(
        'Transaction $transactionId did not confirm within polling window');
  }

  /// Generate Builder HMAC headers.
  ///
  /// Same algorithm as CLOB HMAC but different header names:
  /// `POLY_BUILDER_API_KEY`, `POLY_BUILDER_TIMESTAMP`, etc.
  Map<String, String> _builderHeaders(String method, String path,
      {String? body}) {
    final ts =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

    final normalizedBody = body?.replaceAll("'", '"') ?? '';
    final message = ts + method.toUpperCase() + path + normalizedBody;

    final keyBytes = base64Url.decode(base64Url.normalize(_creds.secret));
    final msgBytes = utf8.encode(message);
    final sig = Hmac(sha256, keyBytes).convert(msgBytes).bytes;
    final sigBase64 = base64Url.encode(sig);

    return {
      'POLY_BUILDER_API_KEY': _creds.apiKey,
      'POLY_BUILDER_SIGNATURE': sigBase64,
      'POLY_BUILDER_TIMESTAMP': ts,
      'POLY_BUILDER_PASSPHRASE': _creds.passphrase,
    };
  }

  void _checkStatus(http.Response response, String path) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RelayerException(
          'Relayer $path returned ${response.statusCode}: ${response.body}');
    }
  }

  void close() => _http.close();
}

/// Repack a 65-byte ECDSA signature into Gnosis Safe's packed format.
///
/// Splits (r, s, v) and re-encodes as (uint256(r), uint256(s), uint8(v)).
/// Input signature must already have v = 31 or 32 (from [signEthMessage]).
String _packSig(String hexSig) {
  final bytes = _hexToBytes(hexSig);
  final r = bytes.sublist(0, 32);
  final s = bytes.sublist(32, 64);
  final v = bytes[64]; // 31 or 32

  // Pack as uint256(r) + uint256(s) + uint8(v)
  final packed = [...r, ...s, v];
  return '0x${packed.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
}

List<int> _hexToBytes(String hex) {
  final h = hex.startsWith('0x') ? hex.substring(2) : hex;
  return List.generate(
      h.length ~/ 2, (i) => int.parse(h.substring(i * 2, i * 2 + 2), radix: 16));
}

/// Thrown when the Polymarket relayer returns an error or times out.
class RelayerException implements Exception {
  final String message;
  const RelayerException(this.message);

  @override
  String toString() => 'RelayerException: $message';
}
