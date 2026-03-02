import 'dart:convert';
import 'package:test/test.dart';
import 'package:polymarket_dart/polymarket_dart.dart';

void main() {
  group('HmacAuth', () {
    // Test vector derived from py-clob-client behavior.
    // The secret below is a base64url-encoded 32-byte key.
    const testApiKey = 'test-api-key-abc123';
    const testPassphrase = 'test-passphrase';
    // A base64url-encoded secret (this is what the CLOB returns)
    const testSecret = 'dGVzdC1zZWNyZXQtdGhhdC1pcy1sb25nLWVub3VnaA==';

    late HmacAuth hmac;

    setUp(() {
      hmac = HmacAuth(
        apiKey: testApiKey,
        secret: testSecret,
        passphrase: testPassphrase,
      );
    });

    test('generates headers with correct keys', () {
      const address = '0xabcdef1234567890abcdef1234567890abcdef12';
      final headers = hmac.generateHeaders(
        walletAddress: address,
        method: 'GET',
        path: '/orders',
        timestamp: '1700000000',
      );

      expect(headers['POLY_ADDRESS'], equals(address));
      expect(headers['POLY_TIMESTAMP'], equals('1700000000'));
      expect(headers['POLY_API_KEY'], equals(testApiKey));
      expect(headers['POLY_PASSPHRASE'], equals(testPassphrase));
      expect(headers['POLY_SIGNATURE'], isNotEmpty);
    });

    test('signature is base64url-encoded (no + or / chars)', () {
      final headers = hmac.generateHeaders(
        walletAddress: '0x1234',
        method: 'POST',
        path: '/order',
        body: '{"order":{},"owner":"key","orderType":"GTC","postOnly":false}',
        timestamp: '1700000000',
      );
      final sig = headers['POLY_SIGNATURE']!;
      // base64url uses - and _ instead of + and /
      expect(sig.contains('+'), isFalse);
      expect(sig.contains('/'), isFalse);
    });

    test('different methods produce different signatures', () {
      const ts = '1700000000';
      const address = '0x1234';
      final getHeaders = hmac.generateHeaders(
        walletAddress: address,
        method: 'GET',
        path: '/order',
        timestamp: ts,
      );
      final postHeaders = hmac.generateHeaders(
        walletAddress: address,
        method: 'POST',
        path: '/order',
        timestamp: ts,
      );
      expect(
        getHeaders['POLY_SIGNATURE'],
        isNot(equals(postHeaders['POLY_SIGNATURE'])),
      );
    });

    test('different paths produce different signatures', () {
      const ts = '1700000000';
      const address = '0x1234';
      final h1 = hmac.generateHeaders(
        walletAddress: address,
        method: 'GET',
        path: '/order',
        timestamp: ts,
      );
      final h2 = hmac.generateHeaders(
        walletAddress: address,
        method: 'GET',
        path: '/orders',
        timestamp: ts,
      );
      expect(
        h1['POLY_SIGNATURE'],
        isNot(equals(h2['POLY_SIGNATURE'])),
      );
    });

    test('single quotes in body are replaced with double quotes', () {
      // The body with single quotes should produce the same signature as
      // the equivalent body with double quotes (after normalization).
      const ts = '1700000000';
      const address = '0x1234';
      const path = '/order';

      // Body with double quotes (canonical form)
      const bodyDouble = '{"orderType":"GTC"}';
      // Body with single quotes (Python dict str() output)
      const bodySingle = "{'orderType':'GTC'}";

      final h1 = hmac.generateHeaders(
        walletAddress: address,
        method: 'POST',
        path: path,
        body: bodyDouble,
        timestamp: ts,
      );
      final h2 = hmac.generateHeaders(
        walletAddress: address,
        method: 'POST',
        path: path,
        body: bodySingle,
        timestamp: ts,
      );

      expect(h1['POLY_SIGNATURE'], equals(h2['POLY_SIGNATURE']));
    });

    test('generateHeadersFromMap produces same result as generateHeaders', () {
      const ts = '1700000000';
      const address = '0x1234';
      final bodyMap = {
        'order': {'tokenId': '123'},
        'owner': 'key',
        'orderType': 'GTC',
        'postOnly': false,
      };
      final bodyStr = jsonEncode(bodyMap);

      final h1 = hmac.generateHeaders(
        walletAddress: address,
        method: 'POST',
        path: '/order',
        body: bodyStr,
        timestamp: ts,
      );
      final h2 = hmac.generateHeadersFromMap(
        walletAddress: address,
        method: 'POST',
        path: '/order',
        body: bodyMap,
        timestamp: ts,
      );

      expect(h1['POLY_SIGNATURE'], equals(h2['POLY_SIGNATURE']));
    });

    test('empty body does not throw', () {
      expect(
        () => hmac.generateHeaders(
          walletAddress: '0x1234',
          method: 'DELETE',
          path: '/orders',
          timestamp: '1700000000',
        ),
        returnsNormally,
      );
    });

    test('auto-generates timestamp when not provided', () {
      final headers = hmac.generateHeaders(
        walletAddress: '0x1234',
        method: 'GET',
        path: '/orders',
      );
      final ts = int.parse(headers['POLY_TIMESTAMP']!);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // Should be within 5 seconds of now
      expect((ts - now).abs(), lessThan(5));
    });
  });
}
