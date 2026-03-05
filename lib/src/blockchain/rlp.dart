/// Minimal RLP (Recursive Length Prefix) encoder for Ethereum transaction signing.
///
/// Supports the subset of RLP needed to encode EIP-155 raw transactions:
/// integers, byte arrays, and lists of the above.
library;

import 'dart:typed_data';

/// RLP-encode a value.
///
/// [value] may be:
/// - [int] or [BigInt] — encoded as a minimal big-endian byte array then RLP'd
/// - [Uint8List] — encoded as an RLP byte string
/// - [List] — encoded as an RLP list of recursively encoded items
Uint8List rlpEncode(dynamic value) {
  if (value is int) {
    return rlpEncode(_intToBytes(BigInt.from(value)));
  } else if (value is BigInt) {
    return rlpEncode(_intToBytes(value));
  } else if (value is Uint8List) {
    return _encodeBytes(value);
  } else if (value is List) {
    final encoded = value.map((e) => rlpEncode(e)).toList();
    final totalLength = encoded.fold<int>(0, (s, b) => s + b.length);
    return _concat([_encodeLength(totalLength, 0xc0), ...encoded]);
  }
  throw ArgumentError('Unsupported RLP type: ${value.runtimeType}');
}

Uint8List _encodeBytes(Uint8List bytes) {
  if (bytes.length == 1 && bytes[0] < 0x80) {
    return bytes; // single byte < 0x80 is its own RLP encoding
  }
  return _concat([_encodeLength(bytes.length, 0x80), bytes]);
}

Uint8List _encodeLength(int length, int offset) {
  if (length < 56) {
    return Uint8List.fromList([length + offset]);
  }
  final lenBytes = _intToBytes(BigInt.from(length));
  return Uint8List.fromList([lenBytes.length + offset + 55, ...lenBytes]);
}

/// Convert a non-negative BigInt to its minimal big-endian byte representation.
/// Returns empty bytes for zero (RLP integer 0 = empty string).
Uint8List _intToBytes(BigInt value) {
  if (value == BigInt.zero) return Uint8List(0);
  final hex = value.toRadixString(16);
  final padded = hex.length.isOdd ? '0$hex' : hex;
  final result = Uint8List(padded.length ~/ 2);
  for (var i = 0; i < result.length; i++) {
    result[i] = int.parse(padded.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}

Uint8List _concat(List<Uint8List> parts) {
  final total = parts.fold<int>(0, (s, p) => s + p.length);
  final result = Uint8List(total);
  var offset = 0;
  for (final part in parts) {
    result.setRange(offset, offset + part.length, part);
    offset += part.length;
  }
  return result;
}
