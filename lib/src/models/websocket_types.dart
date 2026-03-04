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
