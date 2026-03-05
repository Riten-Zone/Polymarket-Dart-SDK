/// Integration tests for GnosisSafe relayer token approvals.
///
/// Requires in .env:
///   PRIVATE_KEY=...
///   FUNDER_ADDRESS=...         (the Gnosis Safe address)
///   BUILDER_API_KEY=...
///   BUILDER_API_SECRET=...
///   BUILDER_API_PASSPHRASE=...
///
/// Run with:
///   dart test test/relayer_test.dart --tags relayer
@Tags(['integration', 'relayer'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:polymarket_dart/polymarket_dart.dart';

String? _loadEnv(String key) {
  try {
    final env = File('.env').readAsStringSync();
    for (final line in env.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('$key=')) {
        final value = trimmed.substring('$key='.length).trim();
        return value.isEmpty ? null : value;
      }
    }
  } catch (_) {}
  return null;
}

void main() {
  late PrivateKeyWalletAdapter wallet;
  late String funderAddress;
  late BuilderCredentials builderCreds;
  bool _skip = false;

  setUpAll(() async {
    final privateKey = _loadEnv('PRIVATE_KEY');
    final funder = _loadEnv('FUNDER_ADDRESS');
    final apiKey = _loadEnv('BUILDER_API_KEY');
    final secret = _loadEnv('BUILDER_API_SECRET');
    final passphrase = _loadEnv('BUILDER_API_PASSPHRASE');

    if (privateKey == null || funder == null ||
        apiKey == null || secret == null || passphrase == null) {
      print(
        'Skipping relayer tests: missing PRIVATE_KEY, FUNDER_ADDRESS, '
        'or BUILDER_API_* in .env',
      );
      _skip = true;
      return;
    }

    final pk = privateKey.startsWith('0x') ? privateKey : '0x$privateKey';
    wallet = PrivateKeyWalletAdapter(pk);
    funderAddress = funder;
    builderCreds = BuilderCredentials(
      apiKey: apiKey,
      secret: secret,
      passphrase: passphrase,
    );

    print('EOA:  ${await wallet.getAddress()}');
    print('Safe: $funderAddress');
  });

  group('RelayerClient — runApprovals', () {
    test('runApprovals completes without error (idempotent)', () async {
      if (_skip) {
        print('Skipping: required .env vars not set');
        return;
      }

      final relayer = RelayerClient(
        wallet: wallet,
        creds: builderCreds,
      );

      try {
        await relayer.runApprovals(
          funderAddress,
          onStatus: print,
        );
        // After approvals, CLOB balance allowance should be non-null
        print('Safe approvals submitted successfully');
      } finally {
        relayer.close();
      }
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
