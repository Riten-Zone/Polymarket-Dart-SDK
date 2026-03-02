import 'package:test/test.dart';
import 'package:polymarket_dart/polymarket_dart.dart';

void main() {
  group('buildClobAuthTypedData', () {
    test('returns correct domain', () {
      final td = buildClobAuthTypedData(
        address: '0xabcdef1234567890abcdef1234567890abcdef12',
        timestamp: '1700000000',
        nonce: 0,
      );

      final domain = td['domain'] as Map<String, dynamic>;
      expect(domain['name'], equals('ClobAuthDomain'));
      expect(domain['version'], equals('1'));
      expect(domain['chainId'], equals(137));
      // No verifyingContract for ClobAuth domain
      expect(domain.containsKey('verifyingContract'), isFalse);
    });

    test('returns correct primaryType', () {
      final td = buildClobAuthTypedData(
        address: '0xabc',
        timestamp: '1700000000',
      );
      expect(td['primaryType'], equals('ClobAuth'));
    });

    test('lowercases the address in the message', () {
      final td = buildClobAuthTypedData(
        address: '0xABCDEF1234567890ABCDEF1234567890ABCDEF12',
        timestamp: '1700000000',
      );
      final msg = td['message'] as Map<String, dynamic>;
      expect(msg['address'], equals('0xabcdef1234567890abcdef1234567890abcdef12'));
    });

    test('uses exact attestation string', () {
      final td = buildClobAuthTypedData(
        address: '0xabc',
        timestamp: '1700000000',
      );
      final msg = td['message'] as Map<String, dynamic>;
      expect(
        msg['message'],
        equals('This message attests that I control the given wallet'),
      );
    });

    test('nonce is included in message', () {
      final td = buildClobAuthTypedData(
        address: '0xabc',
        timestamp: '1700000000',
        nonce: 42,
      );
      final msg = td['message'] as Map<String, dynamic>;
      expect(msg['nonce'], equals(42));
    });

    test('ClobAuth type has correct fields', () {
      final td = buildClobAuthTypedData(
        address: '0xabc',
        timestamp: '1700000000',
      );
      final types = td['types'] as Map<String, dynamic>;
      final clobAuthFields = types['ClobAuth'] as List;
      final names = clobAuthFields
          .map((f) => (f as Map<String, dynamic>)['name'])
          .toList();
      expect(names, containsAll(['address', 'timestamp', 'nonce', 'message']));
    });
  });

  group('buildOrderTypedData', () {
    test('returns correct CTF Exchange domain for regular market', () {
      final td = buildOrderTypedData(
        maker: '0xmaker',
        signer: '0xsigner',
        taker: '0x0000000000000000000000000000000000000000',
        tokenId: '123456',
        makerAmount: '5000000',
        takerAmount: '10000000',
        expiration: '0',
        nonce: '0',
        feeRateBps: '0',
        side: 0,
        signatureType: 0,
        salt: '987654321',
        negRisk: false,
      );

      final domain = td['domain'] as Map<String, dynamic>;
      expect(domain['name'], equals('CTF Exchange'));
      expect(domain['version'], equals('1'));
      expect(domain['chainId'], equals(137));
      expect(
        domain['verifyingContract'],
        equals('0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E'),
      );
    });

    test('uses negRisk contract for neg-risk markets', () {
      final td = buildOrderTypedData(
        maker: '0xmaker',
        signer: '0xsigner',
        taker: '0x0000000000000000000000000000000000000000',
        tokenId: '123456',
        makerAmount: '5000000',
        takerAmount: '10000000',
        expiration: '0',
        nonce: '0',
        feeRateBps: '0',
        side: 0,
        signatureType: 0,
        salt: '987654321',
        negRisk: true,
      );

      final domain = td['domain'] as Map<String, dynamic>;
      expect(
        domain['verifyingContract'],
        equals('0xC5d563A36AE78145C45a50134d48A1215220f80a'),
      );
    });

    test('Order type has all 12 required fields', () {
      final td = buildOrderTypedData(
        maker: '0xmaker',
        signer: '0xsigner',
        taker: '0x0',
        tokenId: '1',
        makerAmount: '1',
        takerAmount: '1',
        expiration: '0',
        nonce: '0',
        feeRateBps: '0',
        side: 0,
        signatureType: 0,
        salt: '1',
      );
      final types = td['types'] as Map<String, dynamic>;
      final orderFields = types['Order'] as List;
      final names = orderFields
          .map((f) => (f as Map<String, dynamic>)['name'])
          .toSet();

      expect(names, containsAll([
        'salt', 'maker', 'signer', 'taker', 'tokenId',
        'makerAmount', 'takerAmount', 'expiration', 'nonce',
        'feeRateBps', 'side', 'signatureType',
      ]));
    });

    test('lowercases maker, signer, and taker addresses', () {
      final td = buildOrderTypedData(
        maker: '0xMAKER',
        signer: '0xSIGNER',
        taker: '0xTAKER',
        tokenId: '1',
        makerAmount: '1',
        takerAmount: '1',
        expiration: '0',
        nonce: '0',
        feeRateBps: '0',
        side: 0,
        signatureType: 0,
        salt: '1',
      );
      final msg = td['message'] as Map<String, dynamic>;
      expect(msg['maker'], equals('0xmaker'));
      expect(msg['signer'], equals('0xsigner'));
      expect(msg['taker'], equals('0xtaker'));
    });

    test('primaryType is Order', () {
      final td = buildOrderTypedData(
        maker: '0x1',
        signer: '0x1',
        taker: '0x0',
        tokenId: '1',
        makerAmount: '1',
        takerAmount: '1',
        expiration: '0',
        nonce: '0',
        feeRateBps: '0',
        side: 1,
        signatureType: 0,
        salt: '1',
      );
      expect(td['primaryType'], equals('Order'));
    });
  });

  group('PrivateKeyWalletAdapter', () {
    // Well-known test private key — DO NOT use with real funds.
    const testPrivKey =
        '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
    const expectedAddress =
        '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266';

    test('derives correct address from private key', () async {
      final wallet = PrivateKeyWalletAdapter(testPrivKey);
      final address = await wallet.getAddress();
      expect(address.toLowerCase(), equals(expectedAddress.toLowerCase()));
    });

    test('signs ClobAuth typed data without throwing', () async {
      final wallet = PrivateKeyWalletAdapter(testPrivKey);
      final address = await wallet.getAddress();
      final typedData = buildClobAuthTypedData(
        address: address,
        timestamp: '1700000000',
        nonce: 0,
      );
      final sig = await wallet.signTypedData(typedData);
      expect(sig, startsWith('0x'));
      expect(sig.length, equals(132)); // 0x + 130 hex chars (65 bytes)
    });

    test('signs Order typed data without throwing', () async {
      final wallet = PrivateKeyWalletAdapter(testPrivKey);
      final address = await wallet.getAddress();
      final typedData = buildOrderTypedData(
        maker: address,
        signer: address,
        taker: '0x0000000000000000000000000000000000000000',
        tokenId: '71321045679252212594626385532706912750332728571942532289631379312455583992563',
        makerAmount: '100000000',
        takerAmount: '200000000',
        expiration: '0',
        nonce: '0',
        feeRateBps: '0',
        side: 0,
        signatureType: 0,
        salt: '1234567890',
      );
      final sig = await wallet.signTypedData(typedData);
      expect(sig, startsWith('0x'));
      expect(sig.length, equals(132));
    });

    test('same input produces same signature (deterministic)', () async {
      final wallet = PrivateKeyWalletAdapter(testPrivKey);
      final address = await wallet.getAddress();
      final typedData = buildClobAuthTypedData(
        address: address,
        timestamp: '1700000000',
        nonce: 0,
      );
      final sig1 = await wallet.signTypedData(typedData);
      final sig2 = await wallet.signTypedData(typedData);
      expect(sig1, equals(sig2));
    });
  });
}
