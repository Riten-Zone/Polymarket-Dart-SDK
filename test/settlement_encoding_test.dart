/// Offline deterministic tests for CTF / neg-risk settlement calldata
/// (split / merge / redeem / convert). Verifies function selectors against the
/// canonical Gnosis ConditionalTokens values and the authoritative
/// NegRiskAdapter source, plus the ABI layout (offsets, dynamic array tails).
library;

import 'dart:typed_data';

import 'package:polymarket_dart/polymarket_dart.dart';
import 'package:test/test.dart';

String _hex(Uint8List b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

/// 32-byte word `i` (0-indexed) of the args, as hex (skips the 4-byte selector).
String _word(Uint8List data, int i) =>
    _hex(Uint8List.sublistView(data, 4 + i * 32, 4 + (i + 1) * 32));

String _selectorHex(Uint8List data) =>
    _hex(Uint8List.sublistView(data, 0, 4));

const _cond =
    '0xc41f543ccb7a1a35a200c28096cc2e5c2351c54546087f4f6cf5c4ef3e0c1aa5';
const _pusd = '0xC011a7E12a19f7B1f670d46F03B03f3342E82DFB';

void main() {
  group('standard CTF (ConditionalTokens) selectors', () {
    test('split / merge / redeem match canonical Gnosis selectors', () {
      expect(
        _selectorHex(AbiEncoder.encodeCtfSplit(
            collateralToken: _pusd, conditionId: _cond, amount: BigInt.one)),
        equals('72ce4275'),
      );
      expect(
        _selectorHex(AbiEncoder.encodeCtfMerge(
            collateralToken: _pusd, conditionId: _cond, amount: BigInt.one)),
        equals('9e7212ad'),
      );
      expect(
        _selectorHex(AbiEncoder.encodeCtfRedeem(
            collateralToken: _pusd, conditionId: _cond)),
        equals('01b7037c'),
      );
    });

    test('split ABI layout: head words, dynamic offset, and partition tail',
        () {
      final data = AbiEncoder.encodeCtfSplit(
        collateralToken: _pusd,
        conditionId: _cond,
        amount: BigInt.from(1000000), // 1 pUSD
      );
      // selector(4) + 5 head words + tail(length + 2 elems) = 4 + 160 + 96.
      expect(data.length, equals(4 + 5 * 32 + 3 * 32));
      // word0 collateral (address, right-aligned)
      expect(_word(data, 0).endsWith(_pusd.substring(2).toLowerCase()), isTrue);
      // word1 parentCollectionId = zero
      expect(_word(data, 1), equals('0' * 64));
      // word2 conditionId
      expect(_word(data, 2), equals(_cond.substring(2)));
      // word3 offset to partition = 0xa0 (160)
      expect(BigInt.parse(_word(data, 3), radix: 16), equals(BigInt.from(160)));
      // word4 amount
      expect(BigInt.parse(_word(data, 4), radix: 16),
          equals(BigInt.from(1000000)));
      // tail: length 2, then partition [1, 2]
      expect(BigInt.parse(_word(data, 5), radix: 16), equals(BigInt.two));
      expect(BigInt.parse(_word(data, 6), radix: 16), equals(BigInt.one));
      expect(BigInt.parse(_word(data, 7), radix: 16), equals(BigInt.two));
    });

    test('redeem offset points past the 4 head words', () {
      final data =
          AbiEncoder.encodeCtfRedeem(collateralToken: _pusd, conditionId: _cond);
      // word3 offset = 0x80 (128 = 4*32)
      expect(BigInt.parse(_word(data, 3), radix: 16), equals(BigInt.from(128)));
      // tail length = 2 (binary index sets)
      expect(BigInt.parse(_word(data, 4), radix: 16), equals(BigInt.two));
    });
  });

  group('NegRiskAdapter selectors (from contract source)', () {
    test('split / merge / redeem / convert selectors', () {
      expect(
        _selectorHex(AbiEncoder.encodeNegRiskSplit(
            conditionId: _cond, amount: BigInt.one)),
        equals('a3d7da1d'),
      );
      expect(
        _selectorHex(AbiEncoder.encodeNegRiskMerge(
            conditionId: _cond, amount: BigInt.one)),
        equals('b10c5c17'),
      );
      expect(
        _selectorHex(AbiEncoder.encodeNegRiskRedeem(
            conditionId: _cond, amounts: [BigInt.one, BigInt.zero])),
        equals('dbeccb23'),
      );
      expect(
        _selectorHex(AbiEncoder.encodeNegRiskConvert(
            marketId: _cond, indexSet: BigInt.one, amount: BigInt.one)),
        equals('c64748c4'),
      );
    });

    test('neg-risk split is two static words (no dynamic tail)', () {
      final data = AbiEncoder.encodeNegRiskSplit(
          conditionId: _cond, amount: BigInt.from(5000000));
      expect(data.length, equals(4 + 2 * 32));
      expect(_word(data, 0), equals(_cond.substring(2)));
      expect(BigInt.parse(_word(data, 1), radix: 16),
          equals(BigInt.from(5000000)));
    });

    test('neg-risk redeem encodes the amounts array tail', () {
      final data = AbiEncoder.encodeNegRiskRedeem(
        conditionId: _cond,
        amounts: [BigInt.from(7), BigInt.zero],
      );
      // word1 offset = 0x40 (64 = 2*32)
      expect(BigInt.parse(_word(data, 1), radix: 16), equals(BigInt.from(64)));
      // tail: length 2, then [7, 0]
      expect(BigInt.parse(_word(data, 2), radix: 16), equals(BigInt.two));
      expect(BigInt.parse(_word(data, 3), radix: 16), equals(BigInt.from(7)));
      expect(BigInt.parse(_word(data, 4), radix: 16), equals(BigInt.zero));
    });
  });
}
