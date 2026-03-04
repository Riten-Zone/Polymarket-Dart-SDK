/// Type definitions for the Polymarket Data API.
library;

// ---------------------------------------------------------------------------
// Position
// ---------------------------------------------------------------------------

/// A user's active position in a Polymarket prediction market.
///
/// Returned by [DataClient.getPositions]. The [proxyWallet] field is the
/// Polymarket-deployed Safe proxy wallet associated with the user's EOA.
class Position {
  /// The Polymarket Safe proxy wallet address associated with the user's EOA.
  ///
  /// This is the same value for every position belonging to the same user.
  /// Use [DataClient.getProxyWallet] to retrieve this without iterating.
  final String proxyWallet;

  /// The CLOB token ID (outcome token address on Polygon).
  final String asset;

  /// The CTF condition ID for the market.
  final String conditionId;

  /// Current position size in outcome tokens.
  final double size;

  /// Average entry price (0–1 range, where 1 = $1 USDC).
  final double avgPrice;

  /// Current market price for this outcome.
  final double curPrice;

  /// Initial investment value in USDC.
  final double? initialValue;

  /// Current market value in USDC.
  final double? currentValue;

  /// Unrealized P&L in USDC.
  final double? cashPnl;

  /// Unrealized P&L as a percentage.
  final double? percentPnl;

  /// Realized P&L in USDC from closed portions.
  final double? realizedPnl;

  /// Whether the position has been redeemed after market resolution.
  final bool redeemed;

  /// Whether the position can be merged with another.
  final bool mergeable;

  /// Market question / title.
  final String? title;

  /// Market URL slug.
  final String? slug;

  /// Market icon URL.
  final String? icon;

  /// Market end/resolution date (ISO 8601).
  final String? endDate;

  /// The outcome label this position is on (e.g. "Yes", "No").
  final String outcome;

  /// Zero-based index of the outcome in the market's outcome list.
  final int outcomeIndex;

  /// Whether this is a neg-risk market.
  final bool negRisk;

  /// Whether the market is closed/resolved.
  final bool closed;

  const Position({
    required this.proxyWallet,
    required this.asset,
    required this.conditionId,
    required this.size,
    required this.avgPrice,
    required this.curPrice,
    required this.redeemed,
    required this.mergeable,
    required this.outcome,
    required this.outcomeIndex,
    required this.negRisk,
    required this.closed,
    this.initialValue,
    this.currentValue,
    this.cashPnl,
    this.percentPnl,
    this.realizedPnl,
    this.title,
    this.slug,
    this.icon,
    this.endDate,
  });

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      proxyWallet: json['proxyWallet'] as String,
      asset: json['asset'] as String,
      conditionId: json['conditionId'] as String,
      size: _toDouble(json['size']),
      avgPrice: _toDouble(json['avgPrice']),
      curPrice: _toDouble(json['curPrice']),
      initialValue: json['initialValue'] != null
          ? _toDouble(json['initialValue'])
          : null,
      currentValue: json['currentValue'] != null
          ? _toDouble(json['currentValue'])
          : null,
      cashPnl: json['cashPnl'] != null ? _toDouble(json['cashPnl']) : null,
      percentPnl:
          json['percentPnl'] != null ? _toDouble(json['percentPnl']) : null,
      realizedPnl:
          json['realizedPnl'] != null ? _toDouble(json['realizedPnl']) : null,
      redeemed: json['redeemed'] as bool? ?? false,
      mergeable: json['mergeable'] as bool? ?? false,
      title: json['title'] as String?,
      slug: json['slug'] as String?,
      icon: json['icon'] as String?,
      endDate: json['endDate'] as String?,
      outcome: json['outcome'] as String? ?? '',
      outcomeIndex: json['outcomeIndex'] as int? ?? 0,
      negRisk: json['negRisk'] as bool? ?? false,
      closed: json['closed'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'Position(asset: $asset, outcome: $outcome, size: $size, curPrice: $curPrice)';
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.parse(value.toString());
}
