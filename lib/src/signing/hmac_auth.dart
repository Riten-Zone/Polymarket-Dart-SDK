/// Level 2 HMAC-SHA256 authentication for Polymarket CLOB API.
///
/// Used for all authenticated requests (order placement, account data, etc.)
/// after obtaining API credentials via Level 1 (EIP-712).
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Generates Level 2 HMAC-SHA256 authentication headers for CLOB requests.
///
/// Implementation notes (verified from py-clob-client source):
/// - The [secret] from API credentials is base64url-encoded; it must be
///   decoded before use as the HMAC key.
/// - Single quotes in the body are replaced with double quotes before signing.
/// - The resulting signature is base64url-encoded.
class HmacAuth {
  final String apiKey;
  final String secret;
  final String passphrase;

  const HmacAuth({
    required this.apiKey,
    required this.secret,
    required this.passphrase,
  });

  /// Generate Level 2 auth headers for a CLOB request.
  ///
  /// [walletAddress] — the wallet's Ethereum address.
  /// [method] — HTTP method: 'GET', 'POST', or 'DELETE'.
  /// [path] — request path including query string, e.g. '/order' or '/orders?id=123'.
  /// [body] — compact JSON string of the request body (empty string for GET).
  /// [timestamp] — unix timestamp as string; auto-generated if null.
  Map<String, String> generateHeaders({
    required String walletAddress,
    required String method,
    required String path,
    String body = '',
    String? timestamp,
  }) {
    final ts = timestamp ??
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

    // CRITICAL: normalize single quotes → double quotes (matches Python impl).
    final normalizedBody = body.replaceAll("'", '"');
    final message = ts + method.toUpperCase() + path + normalizedBody;

    // CRITICAL: base64url-DECODE the secret before using as HMAC key.
    final keyBytes = base64Url.decode(base64Url.normalize(secret));
    final msgBytes = utf8.encode(message);
    final sig = Hmac(sha256, keyBytes).convert(msgBytes).bytes;

    // CRITICAL: base64url-ENCODE the signature output.
    final sigBase64 = base64Url.encode(sig);

    return {
      'POLY_ADDRESS': walletAddress,
      'POLY_SIGNATURE': sigBase64,
      'POLY_TIMESTAMP': ts,
      'POLY_API_KEY': apiKey,
      'POLY_PASSPHRASE': passphrase,
    };
  }

  /// Convenience: serialize [body] map to compact JSON then generate headers.
  Map<String, String> generateHeadersFromMap({
    required String walletAddress,
    required String method,
    required String path,
    Map<String, dynamic>? body,
    String? timestamp,
  }) {
    final bodyStr =
        body != null ? jsonEncode(body) : '';
    return generateHeaders(
      walletAddress: walletAddress,
      method: method,
      path: path,
      body: bodyStr,
      timestamp: timestamp,
    );
  }
}
