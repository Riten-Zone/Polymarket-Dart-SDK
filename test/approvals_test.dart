/// Integration tests for EOA on-chain approval checking and ABI encoding.
///
/// The ABI encoding tests are pure unit tests (no network).
/// The `ensureEoaApprovals` test reads from Polygon mainnet — no MATIC needed
/// to check, but MATIC is required to actually SET approvals if missing.
///
/// Run with:
///   dart test test/approvals_test.dart --tags approvals
@Tags(['integration', 'approvals'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:polymarket_dart/polymarket_dart.dart';

/// Read PRIVATE_KEY from .env file in the project root.
String? _loadPrivateKey() {
  try {
    final env = File('.env').readAsStringSync();
    for (final line in env.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('PRIVATE_KEY=')) {
        final value = trimmed.substring('PRIVATE_KEY='.length).trim();
        if (value.isEmpty) return null;
        return value.startsWith('0x') ? value : '0x$value';
      }
    }
  } catch (_) {}
  return null;
}

void main() {
  // ---------------------------------------------------------------------------
  // Unit tests: ABI encoding (no network)
  // ---------------------------------------------------------------------------

  group('AbiEncoder', () {
    test('encodeApprove produces 68-byte calldata', () {
      final data = AbiEncoder.encodeApprove(PolymarketContracts.ctfExchange);
      expect(data.length, equals(68)); // 4 selector + 32 address + 32 uint256
    });

    test('encodeApprove selector is 0x095ea7b3', () {
      final data = AbiEncoder.encodeApprove(PolymarketContracts.ctfExchange);
      expect(data[0], equals(0x09));
      expect(data[1], equals(0x5e));
      expect(data[2], equals(0xa7));
      expect(data[3], equals(0xb3));
    });

    test('encodeApprove amount is MAX_UINT256 (all 0xff)', () {
      final data = AbiEncoder.encodeApprove(PolymarketContracts.ctfExchange);
      // Last 32 bytes should be MAX_UINT256
      for (var i = 36; i < 68; i++) {
        expect(data[i], equals(0xff), reason: 'byte $i should be 0xff');
      }
    });

    test('encodeSetApprovalForAll produces 68-byte calldata', () {
      final data = AbiEncoder.encodeSetApprovalForAll(PolymarketContracts.ctfExchange);
      expect(data.length, equals(68)); // 4 selector + 32 address + 32 bool
    });

    test('encodeSetApprovalForAll selector is 0xa22cb465', () {
      final data = AbiEncoder.encodeSetApprovalForAll(PolymarketContracts.ctfExchange);
      expect(data[0], equals(0xa2));
      expect(data[1], equals(0x2c));
      expect(data[2], equals(0xb4));
      expect(data[3], equals(0x65));
    });

    test('encodeSetApprovalForAll bool=true is 0x01 in last byte', () {
      final data = AbiEncoder.encodeSetApprovalForAll(PolymarketContracts.ctfExchange);
      expect(data[67], equals(0x01));
      // Preceding 31 bytes should be zero
      for (var i = 36; i < 67; i++) {
        expect(data[i], equals(0x00), reason: 'byte $i should be 0x00');
      }
    });

    test('encodeIsApprovedForAll selector is 0xe985e9c5', () {
      final data = AbiEncoder.encodeIsApprovedForAll(
        '0x1234567890123456789012345678901234567890',
        PolymarketContracts.ctfExchange,
      );
      expect(data[0], equals(0xe9));
      expect(data[1], equals(0x85));
      expect(data[2], equals(0xe9));
      expect(data[3], equals(0xc5));
    });

    test('encodeAllowance selector is 0xdd62ed3e', () {
      final data = AbiEncoder.encodeAllowance(
        '0x1234567890123456789012345678901234567890',
        PolymarketContracts.ctfExchange,
      );
      expect(data[0], equals(0xdd));
      expect(data[1], equals(0x62));
      expect(data[2], equals(0xed));
      expect(data[3], equals(0x3e));
    });
  });

  // ---------------------------------------------------------------------------
  // Unit tests: RLP encoder
  // ---------------------------------------------------------------------------

  group('RLP encoder', () {
    test('encodes empty byte array as 0x80', () {
      final result = rlpEncode(Uint8List(0));
      expect(result, equals(Uint8List.fromList([0x80])));
    });

    test('encodes single byte < 0x80 as itself', () {
      final result = rlpEncode(Uint8List.fromList([0x7f]));
      expect(result, equals(Uint8List.fromList([0x7f])));
    });

    test('encodes integer 0 as 0x80 (empty byte string)', () {
      final result = rlpEncode(0);
      expect(result, equals(Uint8List.fromList([0x80])));
    });

    test('encodes integer 1 as 0x01', () {
      final result = rlpEncode(1);
      expect(result, equals(Uint8List.fromList([0x01])));
    });

    test('encodes integer 0x100 as 0x82 0x01 0x00', () {
      final result = rlpEncode(0x100);
      expect(result, equals(Uint8List.fromList([0x82, 0x01, 0x00])));
    });

    test('encodes empty list as 0xc0', () {
      final result = rlpEncode([]);
      expect(result, equals(Uint8List.fromList([0xc0])));
    });
  });

  // ---------------------------------------------------------------------------
  // Integration: check current on-chain approval state (read-only, no MATIC)
  // ---------------------------------------------------------------------------

  group('EOA approval state (Polygon mainnet read)', () {
    late PrivateKeyWalletAdapter wallet;
    late String address;

    setUpAll(() async {
      final privateKey = _loadPrivateKey();
      if (privateKey == null) {
        print('Skipping: PRIVATE_KEY not found in .env');
        return;
      }
      wallet = PrivateKeyWalletAdapter(privateKey);
      address = await wallet.getAddress();
      print('Checking approvals for EOA: $address');
    });

    test('can read isApprovedForAll state from Polygon', () async {
      final privateKey = _loadPrivateKey();
      if (privateKey == null) {
        print('Skipping: PRIVATE_KEY not in .env');
        return;
      }
      final rpc = PolygonRpc();
      try {
        final data = AbiEncoder.encodeIsApprovedForAll(
            address, PolymarketContracts.ctfExchange);
        final result = await rpc.ethCall(
          to: PolymarketContracts.ctf,
          data: '0x${_bytesToHex(data)}',
        );
        final isApproved =
            BigInt.parse(result.substring(2), radix: 16) == BigInt.one;
        print('CTF → CTF Exchange approved: $isApproved');
        expect(result, startsWith('0x'));
      } finally {
        rpc.close();
      }
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('can read USDC allowance from Polygon', () async {
      final privateKey = _loadPrivateKey();
      if (privateKey == null) {
        print('Skipping: PRIVATE_KEY not in .env');
        return;
      }
      final rpc = PolygonRpc();
      try {
        final data = AbiEncoder.encodeAllowance(
            address, PolymarketContracts.ctfExchange);
        final result = await rpc.ethCall(
          to: PolymarketContracts.usdc,
          data: '0x${_bytesToHex(data)}',
        );
        final allowance = BigInt.parse(result.substring(2), radix: 16);
        print('USDC allowance for CTF Exchange: $allowance');
        expect(result, startsWith('0x'));
      } finally {
        rpc.close();
      }
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}

String _bytesToHex(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
