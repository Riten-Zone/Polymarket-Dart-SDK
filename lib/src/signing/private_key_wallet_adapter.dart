/// A [WalletAdapter] implementation that signs with a raw private key.
///
/// Useful for bots, CLI tools, scripts, and testing. No external wallet
/// provider needed — just pass a hex private key.
///
/// ```dart
/// final wallet = PrivateKeyWalletAdapter('0xabc123...');
/// final client = ClobClient(wallet: wallet);
/// ```
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/digests/keccak.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';

import 'wallet_adapter.dart';

/// Signs EIP-712 typed data using a raw secp256k1 private key.
///
/// Derives the Ethereum address automatically from the private key.
class PrivateKeyWalletAdapter implements WalletAdapter {
  final BigInt _privateKey;
  final ECDomainParameters _params;
  late final String _address;

  /// Create from a hex private key (with or without `0x` prefix).
  PrivateKeyWalletAdapter(String privateKeyHex)
      : _privateKey = _parseBigInt(privateKeyHex),
        _params = ECCurve_secp256k1() {
    _address = _deriveAddress();
  }

  @override
  Future<String> getAddress() async => _address;

  @override
  Future<String> signTypedData(Map<String, dynamic> typedData) async {
    final domain = typedData['domain'] as Map<String, dynamic>;
    final types = typedData['types'] as Map<String, dynamic>;
    final primaryType = typedData['primaryType'] as String;
    final message = typedData['message'] as Map<String, dynamic>;

    // EIP-712: digest = keccak256("\x19\x01" + domainSeparator + structHash)
    final domainSeparator = _hashStruct('EIP712Domain', domain, types);
    final structHash = _hashStruct(primaryType, message, types);

    final digest = Uint8List(2 + 32 + 32);
    digest[0] = 0x19;
    digest[1] = 0x01;
    digest.setRange(2, 34, domainSeparator);
    digest.setRange(34, 66, structHash);

    final hash = _keccak256(digest);
    return _signHash(hash);
  }

  // ---------------------------------------------------------------------------
  // EIP-712 encoding
  // ---------------------------------------------------------------------------

  Uint8List _hashStruct(
    String typeName,
    Map<String, dynamic> data,
    Map<String, dynamic> types,
  ) {
    final typeHash = _typeHash(typeName, types);
    final encodedData = _encodeData(typeName, data, types);

    final combined = Uint8List(32 + encodedData.length);
    combined.setRange(0, 32, typeHash);
    combined.setRange(32, combined.length, encodedData);

    return _keccak256(combined);
  }

  Uint8List _typeHash(String typeName, Map<String, dynamic> types) {
    final typeString = _encodeType(typeName, types);
    return _keccak256(Uint8List.fromList(utf8.encode(typeString)));
  }

  String _encodeType(String typeName, Map<String, dynamic> types) {
    final fields = types[typeName] as List<dynamic>;
    final params = fields.map((f) {
      final field = f as Map<String, dynamic>;
      return '${field['type']} ${field['name']}';
    }).join(',');
    return '$typeName($params)';
  }

  Uint8List _encodeData(
    String typeName,
    Map<String, dynamic> data,
    Map<String, dynamic> types,
  ) {
    final fields = types[typeName] as List<dynamic>;
    final chunks = <Uint8List>[];

    for (final f in fields) {
      final field = f as Map<String, dynamic>;
      final fieldType = field['type'] as String;
      final fieldName = field['name'] as String;
      final value = data[fieldName];

      chunks.add(_encodeField(fieldType, value, types));
    }

    final totalLength = chunks.fold<int>(0, (sum, c) => sum + c.length);
    final result = Uint8List(totalLength);
    var offset = 0;
    for (final chunk in chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }

  Uint8List _encodeField(
    String type,
    dynamic value,
    Map<String, dynamic> types,
  ) {
    if (type == 'string') {
      final bytes = Uint8List.fromList(utf8.encode(value as String));
      return _keccak256(bytes);
    } else if (type == 'bytes') {
      final bytes = _hexToBytes(value as String);
      return _keccak256(bytes);
    } else if (type == 'bytes32') {
      return _hexToBytes32(value as String);
    } else if (type == 'address') {
      return _encodeAddress(value as String);
    } else if (type.startsWith('uint') || type.startsWith('int')) {
      return _encodeUint(value);
    } else if (type == 'bool') {
      return _encodeUint(value == true ? 1 : 0);
    } else if (types.containsKey(type)) {
      return _hashStruct(type, value as Map<String, dynamic>, types);
    }

    return _encodeUint(value);
  }

  Uint8List _encodeAddress(String address) {
    final hex = address.startsWith('0x') ? address.substring(2) : address;
    final bytes = _hexToBytes(hex);
    final padded = Uint8List(32);
    padded.setRange(32 - bytes.length, 32, bytes);
    return padded;
  }

  Uint8List _encodeUint(dynamic value) {
    BigInt bigVal;
    if (value is int) {
      bigVal = BigInt.from(value);
    } else if (value is BigInt) {
      bigVal = value;
    } else if (value is String) {
      bigVal = BigInt.parse(value);
    } else {
      bigVal = BigInt.from(value as num);
    }
    return _bigIntToBytes32(bigVal);
  }

  Uint8List _hexToBytes32(String hex) {
    final h = hex.startsWith('0x') ? hex.substring(2) : hex;
    final raw = _hexToBytes(h);
    if (raw.length == 32) return raw;
    final padded = Uint8List(32);
    padded.setRange(32 - raw.length, 32, raw);
    return padded;
  }

  Uint8List _bigIntToBytes32(BigInt value) {
    final result = Uint8List(32);
    var v = value;
    for (var i = 31; i >= 0; i--) {
      result[i] = (v & BigInt.from(0xff)).toInt();
      v = v >> 8;
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // ECDSA signing
  // ---------------------------------------------------------------------------

  String _signHash(Uint8List hash) {
    final privKey = ECPrivateKey(_privateKey, _params);

    // RFC 6979 deterministic ECDSA: HMAC-DRBG uses SHA-256 (standard for secp256k1).
    // Using KeccakDigest here produces non-standard nonces that differ from ethers.js.
    final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
    signer.init(true, PrivateKeyParameter<ECPrivateKey>(privKey));

    final sig = signer.generateSignature(hash) as ECSignature;

    final halfN = _params.n >> 1;
    BigInt s = sig.s;
    if (s.compareTo(halfN) > 0) {
      s = _params.n - s;
    }

    final v = _computeRecoveryId(hash, sig.r, s, privKey);

    final rBytes = _bigIntToBytes32(sig.r);
    final sBytes = _bigIntToBytes32(s);

    final result = Uint8List(65);
    result.setRange(0, 32, rBytes);
    result.setRange(32, 64, sBytes);
    result[64] = v;

    return '0x${_bytesToHex(result)}';
  }

  int _computeRecoveryId(
      Uint8List hash, BigInt r, BigInt s, ECPrivateKey privKey) {
    final pubKey = (_params.G * privKey.d)!;
    final pubKeyEncoded = pubKey.getEncoded(false);

    for (var recId = 0; recId < 2; recId++) {
      try {
        final recovered = _recoverPublicKey(hash, r, s, recId);
        if (recovered != null) {
          final recoveredEncoded = recovered.getEncoded(false);
          if (_bytesEqual(pubKeyEncoded, recoveredEncoded)) {
            return 27 + recId;
          }
        }
      } catch (_) {
        continue;
      }
    }

    return 27;
  }

  ECPoint? _recoverPublicKey(Uint8List hash, BigInt r, BigInt s, int recId) {
    final n = _params.n;
    final curve = _params.curve;
    final g = _params.G;

    final x = r;
    if (x.compareTo(n) >= 0) return null;

    final prime = (curve as dynamic).q as BigInt;
    final xField = curve.fromBigInteger(x);
    final y2 =
        (xField * xField * xField) + (curve.a! * xField) + curve.b!;
    final y = y2.sqrt();
    if (y == null) return null;

    final yBigInt = y.toBigInteger()!;
    final isOdd = yBigInt.isOdd;
    ECPoint rPoint;
    if ((recId & 1) == 0) {
      rPoint = isOdd
          ? curve.createPoint(x, prime - yBigInt)
          : curve.createPoint(x, yBigInt);
    } else {
      rPoint = isOdd
          ? curve.createPoint(x, yBigInt)
          : curve.createPoint(x, prime - yBigInt);
    }

    final e = _bytesToBigInt(hash);
    final rInv = r.modInverse(n);
    final u1 = (n - (e % n)) % n;
    final u2 = s % n;

    final point = _sumOfTwoMultiplies(g, u1, rPoint, u2);
    if (point == null || point.isInfinity) return null;

    return (point * rInv);
  }

  ECPoint? _sumOfTwoMultiplies(ECPoint p, BigInt a, ECPoint q, BigInt b) {
    return (p * a)! + (q * b);
  }

  // ---------------------------------------------------------------------------
  // Address derivation
  // ---------------------------------------------------------------------------

  String _deriveAddress() {
    final pubKeyPoint = (_params.G * _privateKey)!;
    final pubKeyEncoded = pubKeyPoint.getEncoded(false);
    final pubKeyBody = Uint8List.sublistView(pubKeyEncoded, 1);
    final hash = _keccak256(pubKeyBody);
    final addressBytes = Uint8List.sublistView(hash, 12);
    return '0x${_bytesToHex(addressBytes)}';
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  static BigInt _parseBigInt(String hex) {
    final h = hex.startsWith('0x') ? hex.substring(2) : hex;
    return BigInt.parse(h, radix: 16);
  }

  static Uint8List _keccak256(Uint8List data) {
    final digest = KeccakDigest(256);
    final hash = Uint8List(digest.digestSize);
    digest.update(data, 0, data.length);
    digest.doFinal(hash, 0);
    return hash;
  }

  static Uint8List _hexToBytes(String hex) {
    final h = hex.startsWith('0x') ? hex.substring(2) : hex;
    final result = Uint8List(h.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  static String _bytesToHex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b);
    }
    return result;
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
