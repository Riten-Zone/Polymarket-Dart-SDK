import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/keccak.dart';
import 'package:polymarket_dart/polymarket_dart.dart';
import 'package:test/test.dart';

void main() {
  group('PolymarketContracts pUSD and CLOB V2 addresses', () {
    test('uses current collateral contract addresses', () {
      expect(
        PolymarketContracts.pusd,
        equals('0xC011a7E12a19f7B1f670d46F03B03f3342E82DFB'),
      );
      expect(
        PolymarketContracts.collateralOnramp,
        equals('0x93070a847efEf7F70739046A929D47a521F5B8ee'),
      );
      expect(
        PolymarketContracts.collateralOfframp,
        equals('0x2957922Eb93258b93368531d39fAcCA3B4dC5854'),
      );
    });

    test('uses current CLOB V2 exchange addresses', () {
      expect(
        PolymarketContracts.ctfExchange,
        equals('0xE111180000d2663C0091e4f400237545B87B996B'),
      );
      expect(
        PolymarketContracts.negRiskExchange,
        equals('0xe2222d279d744050d28e00520010520000310F59'),
      );
    });

    test('keeps legacy exchange addresses for migration tooling', () {
      expect(
        PolymarketContracts.legacyCtfExchange,
        equals('0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E'),
      );
      expect(
        PolymarketContracts.legacyNegRiskExchange,
        equals('0xC5d563A36AE78145C45a50134d48A1215220f80a'),
      );
    });
  });

  group('AbiEncoder pUSD wrap/unwrap', () {
    const recipient = '0x1234567890123456789012345678901234567890';
    final amount = BigInt.from(100000000); // 100 tokens with 6 decimals.

    test('encodeApprove supports exact approval amount', () {
      final data = AbiEncoder.encodeApprove(
        PolymarketContracts.collateralOnramp,
        amount: amount,
      );

      expect(data.length, equals(68));
      expect(_hex(data.take(4)), equals('095ea7b3'));
      expect(
        _hex(data.sublist(4, 36)),
        equals(_addressWord(PolymarketContracts.collateralOnramp)),
      );
      expect(
        BigInt.parse(_hex(data.sublist(36, 68)), radix: 16),
        equals(amount),
      );
    });

    test('encodeWrap builds wrap(USDC.e, recipient, amount) calldata', () {
      final data = AbiEncoder.encodeWrap(to: recipient, amount: amount);

      expect(data.length, equals(100));
      expect(
        _hex(data.take(4)),
        equals(_selector('wrap(address,address,uint256)')),
      );
      expect(
        _hex(data.sublist(4, 36)),
        equals(_addressWord(PolymarketContracts.usdc)),
      );
      expect(_hex(data.sublist(36, 68)), equals(_addressWord(recipient)));
      expect(
        BigInt.parse(_hex(data.sublist(68, 100)), radix: 16),
        equals(amount),
      );
    });

    test('encodeUnwrap builds unwrap(USDC.e, recipient, amount) calldata', () {
      final data = AbiEncoder.encodeUnwrap(to: recipient, amount: amount);

      expect(data.length, equals(100));
      expect(
        _hex(data.take(4)),
        equals(_selector('unwrap(address,address,uint256)')),
      );
      expect(
        _hex(data.sublist(4, 36)),
        equals(_addressWord(PolymarketContracts.usdc)),
      );
      expect(_hex(data.sublist(36, 68)), equals(_addressWord(recipient)));
      expect(
        BigInt.parse(_hex(data.sublist(68, 100)), radix: 16),
        equals(amount),
      );
    });
  });

  group('Safe multisend approvals', () {
    test('encodeApprovalMultisend targets pUSD and CLOB V2 contracts', () {
      final multisend = encodeApprovalMultisend();
      final data = multisend.data.toLowerCase();

      expect(multisend.to, equals(PolymarketContracts.multisend));
      expect(data, contains(_addressHex(PolymarketContracts.pusd)));
      expect(data, contains(_addressHex(PolymarketContracts.ctfExchange)));
      expect(data, contains(_addressHex(PolymarketContracts.negRiskExchange)));
      expect(data, isNot(contains(_addressHex(PolymarketContracts.usdc))));
      expect(
        data,
        isNot(contains(_addressHex(PolymarketContracts.legacyCtfExchange))),
      );
      expect(
        data,
        isNot(contains(_addressHex(PolymarketContracts.legacyNegRiskExchange))),
      );
    });
  });
}

String _selector(String signature) {
  final input = utf8.encode(signature);
  final digest = KeccakDigest(256)..update(input, 0, input.length);
  final output = Uint8List(32);
  digest.doFinal(output, 0);
  return _hex(output.take(4));
}

String _addressWord(String address) {
  final hex = address.startsWith('0x') ? address.substring(2) : address;
  return hex.toLowerCase().padLeft(64, '0');
}

String _addressHex(String address) =>
    address.startsWith('0x') ? address.substring(2).toLowerCase() : address;

String _hex(Iterable<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
