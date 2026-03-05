/// Data models for the Polymarket Bridge API.
///
/// The Bridge API enables cross-chain deposits (EVM, Solana, Bitcoin)
/// with automatic conversion to USDC.e on Polygon.
library;

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Status of a cross-chain deposit transaction.
enum DepositState {
  depositDetected,
  processing,
  originTxConfirmed,
  submitted,
  completed,
  failed;

  static DepositState fromJson(String value) {
    const map = {
      'DEPOSIT_DETECTED': DepositState.depositDetected,
      'PROCESSING': DepositState.processing,
      'ORIGIN_TX_CONFIRMED': DepositState.originTxConfirmed,
      'SUBMITTED': DepositState.submitted,
      'COMPLETED': DepositState.completed,
      'FAILED': DepositState.failed,
    };
    return map[value.toUpperCase()] ?? DepositState.processing;
  }
}

// ---------------------------------------------------------------------------
// Deposit addresses
// ---------------------------------------------------------------------------

/// Deposit addresses for different chains returned by `createDeposit`.
class DepositAddresses {
  final String evm;
  final String? svm; // Solana
  final String? btc; // Bitcoin

  const DepositAddresses({required this.evm, this.svm, this.btc});

  factory DepositAddresses.fromJson(Map<String, dynamic> json) =>
      DepositAddresses(
        evm: json['evm'] as String? ?? '',
        svm: json['svm'] as String?,
        btc: json['btc'] as String?,
      );
}

/// Response from `POST /deposit`.
class DepositResponse {
  final DepositAddresses address;
  final String? note;

  const DepositResponse({required this.address, this.note});

  factory DepositResponse.fromJson(Map<String, dynamic> json) =>
      DepositResponse(
        address: DepositAddresses.fromJson(
            json['address'] as Map<String, dynamic>? ?? {}),
        note: json['note'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Supported assets
// ---------------------------------------------------------------------------

/// Token info within a supported asset.
class TokenInfo {
  final String name;
  final String symbol;
  final String address;
  final int decimals;

  const TokenInfo({
    required this.name,
    required this.symbol,
    required this.address,
    required this.decimals,
  });

  factory TokenInfo.fromJson(Map<String, dynamic> json) => TokenInfo(
        name: json['name'] as String? ?? '',
        symbol: json['symbol'] as String? ?? '',
        address: json['address'] as String? ?? '',
        decimals: json['decimals'] as int? ?? 6,
      );
}

/// A chain + token pair that can be deposited via the Bridge API.
class SupportedAsset {
  final String chainId;
  final String chainName;
  final TokenInfo token;
  final double minCheckoutUsd;

  const SupportedAsset({
    required this.chainId,
    required this.chainName,
    required this.token,
    required this.minCheckoutUsd,
  });

  factory SupportedAsset.fromJson(Map<String, dynamic> json) => SupportedAsset(
        chainId: json['chainId'] as String? ?? '',
        chainName: json['chainName'] as String? ?? '',
        token: TokenInfo.fromJson(
            json['token'] as Map<String, dynamic>? ?? {}),
        minCheckoutUsd: _toDouble(json['minCheckoutUsd']),
      );
}

// ---------------------------------------------------------------------------
// Quote
// ---------------------------------------------------------------------------

/// Parameters for requesting a bridge quote.
class BridgeQuoteParams {
  final String fromAmountBaseUnit;
  final String fromChainId;
  final String fromTokenAddress;
  final String recipientAddress;
  final String toChainId;
  final String toTokenAddress;

  const BridgeQuoteParams({
    required this.fromAmountBaseUnit,
    required this.fromChainId,
    required this.fromTokenAddress,
    required this.recipientAddress,
    required this.toChainId,
    required this.toTokenAddress,
  });

  Map<String, dynamic> toJson() => {
        'fromAmountBaseUnit': fromAmountBaseUnit,
        'fromChainId': fromChainId,
        'fromTokenAddress': fromTokenAddress,
        'recipientAddress': recipientAddress,
        'toChainId': toChainId,
        'toTokenAddress': toTokenAddress,
      };
}

/// Fee breakdown within a bridge quote.
class FeeBreakdown {
  final double gasUsd;
  final String? appFeeLabel;
  final double appFeePercent;
  final double appFeeUsd;
  final double fillCostUsd;
  final double maxSlippage;
  final double minReceived;
  final double swapImpact;
  final double totalImpactUsd;

  const FeeBreakdown({
    required this.gasUsd,
    this.appFeeLabel,
    required this.appFeePercent,
    required this.appFeeUsd,
    required this.fillCostUsd,
    required this.maxSlippage,
    required this.minReceived,
    required this.swapImpact,
    required this.totalImpactUsd,
  });

  factory FeeBreakdown.fromJson(Map<String, dynamic> json) => FeeBreakdown(
        gasUsd: _toDouble(json['gasUsd']),
        appFeeLabel: json['appFeeLabel'] as String?,
        appFeePercent: _toDouble(json['appFeePercent']),
        appFeeUsd: _toDouble(json['appFeeUsd']),
        fillCostUsd: _toDouble(json['fillCostUsd']),
        maxSlippage: _toDouble(json['maxSlippage']),
        minReceived: _toDouble(json['minReceived']),
        swapImpact: _toDouble(json['swapImpact']),
        totalImpactUsd: _toDouble(json['totalImpactUsd']),
      );
}

/// Estimated quote returned by `POST /quote`.
///
/// Note: these are estimates — actual amounts may vary due to market conditions.
class BridgeQuote {
  final int estCheckoutTimeMs;
  final double estInputUsd;
  final double estOutputUsd;
  final String estToTokenBaseUnit;
  final String quoteId;
  final FeeBreakdown? estFeeBreakdown;

  const BridgeQuote({
    required this.estCheckoutTimeMs,
    required this.estInputUsd,
    required this.estOutputUsd,
    required this.estToTokenBaseUnit,
    required this.quoteId,
    this.estFeeBreakdown,
  });

  factory BridgeQuote.fromJson(Map<String, dynamic> json) => BridgeQuote(
        estCheckoutTimeMs: json['estCheckoutTimeMs'] as int? ?? 0,
        estInputUsd: _toDouble(json['estInputUsd']),
        estOutputUsd: _toDouble(json['estOutputUsd']),
        estToTokenBaseUnit: json['estToTokenBaseUnit'] as String? ?? '',
        quoteId: json['quoteId'] as String? ?? '',
        estFeeBreakdown: json['estFeeBreakdown'] != null
            ? FeeBreakdown.fromJson(
                json['estFeeBreakdown'] as Map<String, dynamic>)
            : null,
      );
}

// ---------------------------------------------------------------------------
// Deposit status
// ---------------------------------------------------------------------------

/// A single cross-chain transaction in the deposit history.
class DepositTransaction {
  final String fromChainId;
  final String fromTokenAddress;
  final String fromAmountBaseUnit;
  final String toChainId;
  final String toTokenAddress;
  final DepositState status;
  final String? txHash;
  final int? createdTimeMs;

  const DepositTransaction({
    required this.fromChainId,
    required this.fromTokenAddress,
    required this.fromAmountBaseUnit,
    required this.toChainId,
    required this.toTokenAddress,
    required this.status,
    this.txHash,
    this.createdTimeMs,
  });

  factory DepositTransaction.fromJson(Map<String, dynamic> json) =>
      DepositTransaction(
        fromChainId: json['fromChainId'] as String? ?? '',
        fromTokenAddress: json['fromTokenAddress'] as String? ?? '',
        fromAmountBaseUnit: json['fromAmountBaseUnit'] as String? ?? '',
        toChainId: json['toChainId'] as String? ?? '',
        toTokenAddress: json['toTokenAddress'] as String? ?? '',
        status: DepositState.fromJson(json['status'] as String? ?? 'PROCESSING'),
        txHash: json['txHash'] as String?,
        createdTimeMs: json['createdTimeMs'] as int?,
      );
}

/// Response from `GET /status/{address}`.
class DepositStatus {
  final List<DepositTransaction> transactions;

  const DepositStatus({required this.transactions});

  factory DepositStatus.fromJson(Map<String, dynamic> json) {
    final raw = json['transactions'] as List<dynamic>? ?? [];
    return DepositStatus(
      transactions: raw
          .map((e) => DepositTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}
