/// Type definitions for Polymarket WebSocket streams.
library;

// ---------------------------------------------------------------------------
// CLOB WebSocket
// ---------------------------------------------------------------------------

/// A single level update in an orderbook stream event.
class WsOrderLevel {
  final String price;
  final String size;

  const WsOrderLevel({required this.price, required this.size});

  factory WsOrderLevel.fromJson(dynamic json) {
    if (json is List) {
      return WsOrderLevel(
        price: json[0].toString(),
        size: json[1].toString(),
      );
    }
    final map = json as Map<String, dynamic>;
    return WsOrderLevel(
      price: map['price'].toString(),
      size: map['size'].toString(),
    );
  }
}

/// An orderbook update from the CLOB WebSocket.
class OrderbookUpdate {
  final String market;
  final String assetId;
  final List<WsOrderLevel> bids;
  final List<WsOrderLevel> asks;
  final int? timestamp;

  const OrderbookUpdate({
    required this.market,
    required this.assetId,
    required this.bids,
    required this.asks,
    this.timestamp,
  });

  factory OrderbookUpdate.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return OrderbookUpdate(
      market: data['market']?.toString() ?? '',
      assetId: data['asset_id']?.toString() ?? '',
      bids: (data['bids'] as List?)
              ?.map((b) => WsOrderLevel.fromJson(b))
              .toList() ??
          [],
      asks: (data['asks'] as List?)
              ?.map((a) => WsOrderLevel.fromJson(a))
              .toList() ??
          [],
      timestamp: data['timestamp'] == null
          ? null
          : int.tryParse(data['timestamp'].toString()),
    );
  }
}

/// A trade event from the CLOB WebSocket.
class WsTrade {
  final String tradeId;
  final String market;
  final String price;
  final String size;
  final String side;
  final String matchTime;
  final String? type;

  const WsTrade({
    required this.tradeId,
    required this.market,
    required this.price,
    required this.size,
    required this.side,
    required this.matchTime,
    this.type,
  });

  factory WsTrade.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return WsTrade(
      tradeId: data['id']?.toString() ?? '',
      market: data['market']?.toString() ?? '',
      price: data['price']?.toString() ?? '',
      size: data['size']?.toString() ?? '',
      side: data['side']?.toString() ?? '',
      matchTime: data['match_time']?.toString() ?? '',
      type: data['type']?.toString(),
    );
  }
}

// ---------------------------------------------------------------------------
// RTDS WebSocket
// ---------------------------------------------------------------------------

/// A real-time crypto price update from RTDS.
class RtdsPriceUpdate {
  final String asset; // 'BTC', 'ETH', 'SOL', 'XRP'
  final String price;
  final String? source; // 'binance', 'chainlink'
  final int? timestamp;

  const RtdsPriceUpdate({
    required this.asset,
    required this.price,
    this.source,
    this.timestamp,
  });

  factory RtdsPriceUpdate.fromJson(Map<String, dynamic> json) {
    return RtdsPriceUpdate(
      asset: json['asset']?.toString() ?? json['symbol']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
      source: json['source']?.toString(),
      timestamp: json['timestamp'] as int?,
    );
  }
}

/// A comment event from the RTDS WebSocket.
class RtdsComment {
  final String marketId;
  final String author;
  final String content;
  final int? timestamp;

  const RtdsComment({
    required this.marketId,
    required this.author,
    required this.content,
    this.timestamp,
  });

  factory RtdsComment.fromJson(Map<String, dynamic> json) {
    return RtdsComment(
      marketId: json['market_id']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      timestamp: json['timestamp'] as int?,
    );
  }
}

// ---------------------------------------------------------------------------
// CLOB user channel (authenticated)
// ---------------------------------------------------------------------------

/// One maker order inside a [UserChannelTrade] match.
class UserChannelMakerOrder {
  final String assetId;
  final String matchedAmount;
  final String orderId;
  final String outcome;
  final String owner;
  final String price;

  const UserChannelMakerOrder({
    required this.assetId,
    required this.matchedAmount,
    required this.orderId,
    required this.outcome,
    required this.owner,
    required this.price,
  });

  factory UserChannelMakerOrder.fromJson(Map<String, dynamic> json) =>
      UserChannelMakerOrder(
        assetId: json['asset_id']?.toString() ?? '',
        matchedAmount: json['matched_amount']?.toString() ?? '',
        orderId: json['order_id']?.toString() ?? '',
        outcome: json['outcome']?.toString() ?? '',
        owner: json['owner']?.toString() ?? '',
        price: json['price']?.toString() ?? '',
      );
}

/// A `trade` event on the authenticated user channel — fires when the user's
/// orders match or a match changes status
/// (MATCHED → MINED → CONFIRMED, or → FAILED).
class UserChannelTrade {
  final String id;
  final String assetId;
  final String market;
  final String side;
  final String size;
  final String price;
  final String outcome;
  final String owner;
  final String status;
  final String? matchTime;
  final String? takerOrderId;
  final String? tradeOwner;
  final String? timestamp;
  final List<UserChannelMakerOrder> makerOrders;
  final Map<String, dynamic> raw;

  const UserChannelTrade({
    required this.id,
    required this.assetId,
    required this.market,
    required this.side,
    required this.size,
    required this.price,
    required this.outcome,
    required this.owner,
    required this.status,
    this.matchTime,
    this.takerOrderId,
    this.tradeOwner,
    this.timestamp,
    required this.makerOrders,
    required this.raw,
  });

  factory UserChannelTrade.fromJson(Map<String, dynamic> json) {
    final makers = json['maker_orders'] as List<dynamic>? ?? const [];
    return UserChannelTrade(
      id: json['id']?.toString() ?? '',
      assetId: json['asset_id']?.toString() ?? '',
      market: json['market']?.toString() ?? '',
      side: json['side']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
      outcome: json['outcome']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      matchTime: json['match_time']?.toString(),
      takerOrderId: json['taker_order_id']?.toString(),
      tradeOwner: json['trade_owner']?.toString(),
      timestamp: json['timestamp']?.toString(),
      makerOrders: makers
          .whereType<Map<String, dynamic>>()
          .map(UserChannelMakerOrder.fromJson)
          .toList(),
      raw: json,
    );
  }
}

/// An `order` event on the authenticated user channel — fires on placement,
/// partial matching, or cancellation. [type] is PLACEMENT, UPDATE, or
/// CANCELLATION.
class UserChannelOrder {
  final String id;
  final String assetId;
  final String market;
  final String side;
  final String price;
  final String outcome;
  final String owner;
  final String orderOwner;
  final String originalSize;
  final String sizeMatched;

  /// PLACEMENT, UPDATE, or CANCELLATION.
  final String type;
  final String? timestamp;
  final List<String> associateTrades;
  final Map<String, dynamic> raw;

  const UserChannelOrder({
    required this.id,
    required this.assetId,
    required this.market,
    required this.side,
    required this.price,
    required this.outcome,
    required this.owner,
    required this.orderOwner,
    required this.originalSize,
    required this.sizeMatched,
    required this.type,
    this.timestamp,
    required this.associateTrades,
    required this.raw,
  });

  factory UserChannelOrder.fromJson(Map<String, dynamic> json) {
    final trades = json['associate_trades'] as List<dynamic>? ?? const [];
    return UserChannelOrder(
      id: json['id']?.toString() ?? '',
      assetId: json['asset_id']?.toString() ?? '',
      market: json['market']?.toString() ?? '',
      side: json['side']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
      outcome: json['outcome']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      orderOwner: json['order_owner']?.toString() ?? '',
      originalSize: json['original_size']?.toString() ?? '',
      sizeMatched: json['size_matched']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      timestamp: json['timestamp']?.toString(),
      associateTrades: trades.map((e) => e.toString()).toList(),
      raw: json,
    );
  }
}

// ---------------------------------------------------------------------------
// Sports channel
// ---------------------------------------------------------------------------

/// A `sport_result` event from the sports WebSocket — emitted when matches go
/// live, scores or periods change, matches end, or possession changes
/// (NFL/CFB only). The feed is unauthenticated and broadcasts every active
/// game; filter by [gameId] / [slug] / [leagueAbbreviation] as needed.
class SportResult {
  final int gameId;
  final String leagueAbbreviation;

  /// `{league}-{team1}-{team2}-{date}`.
  final String slug;
  final String homeTeam;
  final String awayTeam;

  /// Sport-specific status string (e.g. `InProgress`, `Final`).
  final String status;

  /// Current score, e.g. `"3-16"`.
  final String score;
  final String period;

  /// Game clock, when live.
  final String? elapsed;
  final bool live;
  final bool ended;

  /// Possession indicator (NFL/CFB only).
  final String? turn;

  /// ISO 8601 end time, present only when [ended] is true.
  final String? finishedTimestamp;
  final Map<String, dynamic> raw;

  const SportResult({
    required this.gameId,
    required this.leagueAbbreviation,
    required this.slug,
    required this.homeTeam,
    required this.awayTeam,
    required this.status,
    required this.score,
    required this.period,
    this.elapsed,
    required this.live,
    required this.ended,
    this.turn,
    this.finishedTimestamp,
    required this.raw,
  });

  factory SportResult.fromJson(Map<String, dynamic> json) => SportResult(
        gameId: (json['gameId'] as num?)?.toInt() ?? 0,
        leagueAbbreviation: json['leagueAbbreviation']?.toString() ?? '',
        slug: json['slug']?.toString() ?? '',
        homeTeam: json['homeTeam']?.toString() ?? '',
        awayTeam: json['awayTeam']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        score: json['score']?.toString() ?? '',
        period: json['period']?.toString() ?? '',
        elapsed: json['elapsed']?.toString(),
        live: json['live'] as bool? ?? false,
        ended: json['ended'] as bool? ?? false,
        turn: json['turn']?.toString(),
        finishedTimestamp: json['finished_timestamp']?.toString(),
        raw: json,
      );
}
