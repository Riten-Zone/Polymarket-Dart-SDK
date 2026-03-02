/// Abstract wallet adapter interface for signing Polymarket transactions.
///
/// Implement this interface for your wallet provider (Privy, Web3Auth,
/// MetaMask, raw private key, etc.).
///
/// Example implementation for a raw private key:
/// ```dart
/// class PrivateKeyWalletAdapter implements WalletAdapter {
///   final String _privateKey;
///   final String _address;
///
///   PrivateKeyWalletAdapter(this._privateKey, this._address);
///
///   @override
///   Future<String> getAddress() async => _address;
///
///   @override
///   Future<String> signTypedData(Map<String, dynamic> typedData) async {
///     return signEip712(typedData, _privateKey);
///   }
/// }
/// ```
abstract class WalletAdapter {
  /// Returns the wallet's Ethereum address.
  Future<String> getAddress();

  /// Signs EIP-712 typed data and returns the full signature as a hex string.
  ///
  /// The [typedData] map contains:
  /// - `domain`: The EIP-712 domain separator.
  /// - `types`: The type definitions.
  /// - `primaryType`: The primary type name.
  /// - `message`: The message to sign.
  ///
  /// Returns a hex string signature (with or without `0x` prefix).
  Future<String> signTypedData(Map<String, dynamic> typedData);
}
