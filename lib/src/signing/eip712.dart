/// EIP-712 typed data builders for Polymarket.
///
/// Two separate signing domains are used:
/// 1. [buildClobAuthTypedData] — Level 1 auth (ClobAuthDomain) to get API credentials.
/// 2. [buildOrderTypedData] — Order signing (CTF Exchange) per trade.
library;

import '../utils/constants.dart';

// ---------------------------------------------------------------------------
// Level 1: ClobAuth (get API credentials)
// ---------------------------------------------------------------------------

/// Build EIP-712 typed data for Level 1 authentication.
///
/// This is signed once per session to obtain [apiKey], [secret], [passphrase]
/// from the CLOB API. The resulting signature is sent as [POLY_SIGNATURE] header.
///
/// [address] — the wallet's Ethereum address (lowercase).
/// [timestamp] — current unix timestamp as a string.
/// [nonce] — use 0 for Level 1 credential fetch; nonzero for Level 2 derivation.
Map<String, dynamic> buildClobAuthTypedData({
  required String address,
  required String timestamp,
  int nonce = 0,
}) {
  return {
    'domain': {
      'name': 'ClobAuthDomain',
      'version': '1',
      'chainId': PolymarketChain.chainId,
    },
    'types': {
      'EIP712Domain': [
        {'name': 'name', 'type': 'string'},
        {'name': 'version', 'type': 'string'},
        {'name': 'chainId', 'type': 'uint256'},
      ],
      'ClobAuth': [
        {'name': 'address', 'type': 'address'},
        {'name': 'timestamp', 'type': 'string'},
        {'name': 'nonce', 'type': 'uint256'},
        {'name': 'message', 'type': 'string'},
      ],
    },
    'primaryType': 'ClobAuth',
    'message': {
      'address': address.toLowerCase(),
      'timestamp': timestamp,
      'nonce': nonce,
      // Must match character-for-character with the Python/TS SDK.
      'message': 'This message attests that I control the given wallet',
    },
  };
}

// ---------------------------------------------------------------------------
// Order signing: CTF Exchange
// ---------------------------------------------------------------------------

/// Build EIP-712 typed data for signing a Polymarket order.
///
/// This is a separate signing domain from [buildClobAuthTypedData].
/// The signed order is submitted with Level 2 (HMAC) auth.
///
/// [negRisk] — true for neg-risk markets (uses a different contract address).
Map<String, dynamic> buildOrderTypedData({
  required String maker,
  required String signer,
  required String taker,
  required String tokenId,
  required String makerAmount,
  required String takerAmount,
  required String expiration,
  required String nonce,
  required String feeRateBps,
  required int side, // 0 = BUY, 1 = SELL
  required int signatureType, // 0 = EOA, 1 = PolyProxy, 2 = GnosisSafe
  required String salt,
  bool negRisk = false,
}) {
  final verifyingContract = negRisk
      ? PolymarketChain.negRiskExchangeAddress
      : PolymarketChain.exchangeAddress;

  return {
    'domain': {
      'name': 'CTF Exchange',
      'version': '1',
      'chainId': PolymarketChain.chainId,
      'verifyingContract': verifyingContract,
    },
    'types': {
      'EIP712Domain': [
        {'name': 'name', 'type': 'string'},
        {'name': 'version', 'type': 'string'},
        {'name': 'chainId', 'type': 'uint256'},
        {'name': 'verifyingContract', 'type': 'address'},
      ],
      'Order': [
        {'name': 'salt', 'type': 'uint256'},
        {'name': 'maker', 'type': 'address'},
        {'name': 'signer', 'type': 'address'},
        {'name': 'taker', 'type': 'address'},
        {'name': 'tokenId', 'type': 'uint256'},
        {'name': 'makerAmount', 'type': 'uint256'},
        {'name': 'takerAmount', 'type': 'uint256'},
        {'name': 'expiration', 'type': 'uint256'},
        {'name': 'nonce', 'type': 'uint256'},
        {'name': 'feeRateBps', 'type': 'uint256'},
        {'name': 'side', 'type': 'uint256'},
        {'name': 'signatureType', 'type': 'uint256'},
      ],
    },
    'primaryType': 'Order',
    'message': {
      'salt': salt,
      'maker': maker.toLowerCase(),
      'signer': signer.toLowerCase(),
      'taker': taker.toLowerCase(),
      'tokenId': tokenId,
      'makerAmount': makerAmount,
      'takerAmount': takerAmount,
      'expiration': expiration,
      'nonce': nonce,
      'feeRateBps': feeRateBps,
      'side': side,
      'signatureType': signatureType,
    },
  };
}
