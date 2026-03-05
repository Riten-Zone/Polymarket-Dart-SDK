/// Builder Program HMAC authentication for Polymarket.
///
/// Builder credentials give access to order attribution, gasless relayer,
/// and builder-specific CLOB endpoints. Obtain credentials at
/// https://polymarket.com/settings?tab=builder
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';

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

/// Generate Builder HMAC authentication headers.
///
/// Builder auth uses different header names from standard L2:
/// `POLY_BUILDER_API_KEY`, `POLY_BUILDER_TIMESTAMP`,
/// `POLY_BUILDER_PASSPHRASE`, `POLY_BUILDER_SIGNATURE`.
///
/// The signing algorithm is identical to L2 HMAC (base64url-decode secret,
/// HMAC-SHA256, base64url-encode signature).
Map<String, String> generateBuilderHeaders({
  required BuilderCredentials creds,
  required String method,
  required String path,
  String? body,
}) {
  final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

  final normalizedBody = body?.replaceAll("'", '"') ?? '';
  final message = ts + method.toUpperCase() + path + normalizedBody;

  final keyBytes = base64Url.decode(base64Url.normalize(creds.secret));
  final msgBytes = utf8.encode(message);
  final sig = Hmac(sha256, keyBytes).convert(msgBytes).bytes;
  final sigBase64 = base64Url.encode(sig);

  return {
    'POLY_BUILDER_API_KEY': creds.apiKey,
    'POLY_BUILDER_SIGNATURE': sigBase64,
    'POLY_BUILDER_TIMESTAMP': ts,
    'POLY_BUILDER_PASSPHRASE': creds.passphrase,
  };
}
