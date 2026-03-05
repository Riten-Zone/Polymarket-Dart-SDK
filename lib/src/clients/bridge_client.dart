/// Polymarket Bridge API client — cross-chain deposit facilitation.
///
/// Enables deposits from EVM chains (Ethereum, Arbitrum, Base, etc.),
/// Solana, and Bitcoin with automatic conversion to USDC.e on Polygon.
///
/// All endpoints are public — no authentication required.
///
/// ```dart
/// final bridge = BridgeClient();
///
/// // Generate deposit addresses for your Polymarket wallet
/// final deposit = await bridge.createDeposit('0xYourPolymarketAddress');
/// print('Send ETH/USDC to: ${deposit.address.evm}');
/// print('Send SOL/USDC to: ${deposit.address.svm}');
///
/// // Check supported chains and tokens
/// final assets = await bridge.getSupportedAssets();
/// for (final a in assets) {
///   print('${a.chainName}: ${a.token.symbol} (min \$${a.minCheckoutUsd})');
/// }
///
/// bridge.close();
/// ```
library;

import 'dart:convert';

import '../models/bridge_types.dart';
import '../transport/http_transport.dart';
import '../utils/constants.dart';

/// Client for the Polymarket Bridge API (`https://bridge.polymarket.com`).
///
/// No authentication required — all methods are public.
class BridgeClient {
  final HttpTransport _transport;

  BridgeClient({HttpTransport? transport})
      : _transport = transport ?? HttpTransport();

  // ---------------------------------------------------------------------------
  // Deposit addresses
  // ---------------------------------------------------------------------------

  /// Generate deposit addresses for a Polymarket wallet.
  ///
  /// Returns EVM, Solana, and Bitcoin addresses. Send supported tokens to
  /// any of these addresses and they will be automatically converted to
  /// USDC.e on Polygon and credited to [recipientAddress].
  ///
  /// Use [getSupportedAssets] to discover which chains and tokens are accepted.
  Future<DepositResponse> createDeposit(String recipientAddress) async {
    final body = jsonEncode({'address': recipientAddress});
    final res = await _transport.post(
      PolymarketUrls.bridge,
      '/deposit',
      body: jsonDecode(body),
    ) as Map<String, dynamic>;
    return DepositResponse.fromJson(res);
  }

  // ---------------------------------------------------------------------------
  // Supported assets
  // ---------------------------------------------------------------------------

  /// Returns all supported chains and tokens for deposits.
  ///
  /// Each [SupportedAsset] includes the chain, token details, and
  /// the minimum USD value required to initiate a deposit.
  Future<List<SupportedAsset>> getSupportedAssets() async {
    final res = await _transport.get(
      PolymarketUrls.bridge,
      '/supported-assets',
    );
    if (res == null) return [];
    final map = res as Map<String, dynamic>;
    final list = map['supportedAssets'] as List<dynamic>? ?? [];
    return list
        .map((e) => SupportedAsset.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Quote
  // ---------------------------------------------------------------------------

  /// Get an estimated quote for a cross-chain deposit.
  ///
  /// Returns estimated output amount, fees, and checkout time.
  /// Note: quotes are estimates — actual amounts may vary due to market conditions.
  Future<BridgeQuote> getQuote(BridgeQuoteParams params) async {
    final body = jsonEncode(params.toJson());
    final res = await _transport.post(
      PolymarketUrls.bridge,
      '/quote',
      body: jsonDecode(body),
    ) as Map<String, dynamic>;
    return BridgeQuote.fromJson(res);
  }

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  /// Get the status of a deposit by its deposit address.
  ///
  /// [depositAddress] is the EVM, SVM, or BTC address returned by [createDeposit].
  ///
  /// Poll this until `status == DepositState.completed`.
  Future<DepositStatus> getStatus(String depositAddress) async {
    final res = await _transport.get(
      PolymarketUrls.bridge,
      '/status/$depositAddress',
    );
    if (res == null) return const DepositStatus(transactions: []);
    return DepositStatus.fromJson(res as Map<String, dynamic>);
  }

  /// Close the underlying HTTP client.
  void close() => _transport.close();
}
