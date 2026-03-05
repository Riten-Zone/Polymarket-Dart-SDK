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
  return double.tryParse(value.toString()) ?? 0.0;
}

// ---------------------------------------------------------------------------
// UserTrade
// ---------------------------------------------------------------------------

/// A completed trade on Polymarket as returned by the Data API.
///
/// Returned by [DataClient.getTrades]. Note: the CLOB API has its own [Trade]
/// type in [clob_types.dart] — this type is specific to the Data API response.
class UserTrade {
  /// The Polygon transaction hash for this trade.
  final String transactionHash;

  /// The Polymarket Safe proxy wallet that executed the trade.
  final String proxyWallet;

  /// The CLOB token ID (outcome token address on Polygon).
  final String asset;

  /// The CTF condition ID of the market.
  final String conditionId;

  /// Trade side (`"BUY"` or `"SELL"`).
  final String side;

  /// Execution price (0–1 range, where 1 = $1 USDC).
  final double price;

  /// Size of the trade in outcome tokens.
  final double size;

  /// Unix timestamp of the trade in seconds.
  final int timestamp;

  /// Market question / title.
  final String? title;

  /// Market URL slug.
  final String? slug;

  /// The outcome label (e.g. `"Yes"`, `"No"`).
  final String outcome;

  const UserTrade({
    required this.transactionHash,
    required this.proxyWallet,
    required this.asset,
    required this.conditionId,
    required this.side,
    required this.price,
    required this.size,
    required this.timestamp,
    required this.outcome,
    this.title,
    this.slug,
  });

  factory UserTrade.fromJson(Map<String, dynamic> json) {
    return UserTrade(
      transactionHash: json['transactionHash'] as String? ?? '',
      proxyWallet: json['proxyWallet'] as String? ?? '',
      asset: json['asset'] as String? ?? '',
      conditionId: json['conditionId'] as String? ?? '',
      side: json['side'] as String? ?? '',
      price: _toDouble(json['price']),
      size: _toDouble(json['size']),
      timestamp: json['timestamp'] as int? ?? 0,
      outcome: json['outcome'] as String? ?? '',
      title: json['title'] as String?,
      slug: json['slug'] as String?,
    );
  }

  @override
  String toString() =>
      'UserTrade(txHash: $transactionHash, side: $side, price: $price, size: $size)';
}

// ---------------------------------------------------------------------------
// Activity
// ---------------------------------------------------------------------------

/// A user activity event on Polymarket (trade, redemption, deposit, etc.).
///
/// Returned by [DataClient.getActivity].
class Activity {
  /// Activity type (e.g. `"TRADE"`, `"REDEEM"`, `"TRANSFER"`).
  final String type;

  /// The CTF condition ID of the related market.
  final String conditionId;

  /// Trade side if applicable (`"BUY"`, `"SELL"`, or `""`).
  final String side;

  /// Execution price if applicable.
  final double price;

  /// Size of the transaction in tokens.
  final double size;

  /// Unix timestamp in seconds.
  final int timestamp;

  const Activity({
    required this.type,
    required this.conditionId,
    required this.side,
    required this.price,
    required this.size,
    required this.timestamp,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      type: json['type'] as String? ?? '',
      conditionId: json['conditionId'] as String? ?? '',
      side: json['side'] as String? ?? '',
      price: _toDouble(json['price']),
      size: _toDouble(json['size']),
      timestamp: json['timestamp'] as int? ?? 0,
    );
  }

  @override
  String toString() =>
      'Activity(type: $type, conditionId: $conditionId, size: $size)';
}

// ---------------------------------------------------------------------------
// Holder
// ---------------------------------------------------------------------------

/// A holder of a specific prediction market outcome token.
///
/// Returned by [DataClient.getHolders].
class Holder {
  /// The holder's wallet address (proxy wallet or EOA).
  final String address;

  /// Polymarket display name or pseudonym.
  final String pseudonym;

  /// The Polymarket Safe proxy wallet address.
  final String proxyWallet;

  /// Amount of outcome tokens held.
  final double amount;

  const Holder({
    required this.address,
    required this.pseudonym,
    required this.proxyWallet,
    required this.amount,
  });

  factory Holder.fromJson(Map<String, dynamic> json) {
    return Holder(
      address: json['address'] as String? ?? '',
      pseudonym: json['pseudonym'] as String? ?? '',
      proxyWallet: json['proxyWallet'] as String? ?? '',
      amount: _toDouble(json['amount']),
    );
  }

  @override
  String toString() =>
      'Holder(address: $address, pseudonym: $pseudonym, amount: $amount)';
}

// ---------------------------------------------------------------------------
// LeaderboardEntry
// ---------------------------------------------------------------------------

/// A leaderboard entry showing top Polymarket traders.
///
/// Returned by [DataClient.getLeaderboard].
class LeaderboardEntry {
  /// Wallet address (proxy wallet).
  final String address;

  /// Polymarket display name or pseudonym.
  final String pseudonym;

  /// Total trading volume (USDC).
  final double volume;

  /// Realized profit and loss (USDC).
  final double pnl;

  /// Leaderboard rank (1-indexed).
  final int rank;

  const LeaderboardEntry({
    required this.address,
    required this.pseudonym,
    required this.volume,
    required this.pnl,
    required this.rank,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      address: json['address'] as String? ?? '',
      pseudonym: json['pseudonym'] as String? ?? '',
      volume: _toDouble(json['volume']),
      pnl: _toDouble(json['pnl']),
      rank: json['rank'] as int? ?? 0,
    );
  }

  @override
  String toString() =>
      'LeaderboardEntry(rank: $rank, address: $address, pnl: $pnl)';
}
