/// Type definitions for the Polymarket CLOB API.
library;

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum OrderSide { buy, sell }

enum OrderType { gtc, gtd, fok, fak }

enum SignatureType { eoa, polyProxy, gnosisSafe }

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

/// API credentials returned by Level 1 auth (EIP-712 → CLOB).
class ApiCredentials {
  final String apiKey;
  final String secret;
  final String passphrase;

  const ApiCredentials({
    required this.apiKey,
    required this.secret,
    required this.passphrase,
  });

  factory ApiCredentials.fromJson(Map<String, dynamic> json) {
    return ApiCredentials(
      apiKey: json['apiKey'] as String,
      secret: json['secret'] as String,
      passphrase: json['passphrase'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'apiKey': apiKey,
        'secret': secret,
        'passphrase': passphrase,
      };

  @override
  String toString() => 'ApiCredentials(apiKey: $apiKey)';
}

/// Response from GET /auth/api-key (list of managed API keys).
class ApiKeysResponse {
  final List<String> apiKeys;

  const ApiKeysResponse({required this.apiKeys});

  factory ApiKeysResponse.fromJson(dynamic json) {
    if (json is List) {
      return ApiKeysResponse(apiKeys: json.cast<String>());
    }
    final map = json as Map<String, dynamic>;
    final keys = (map['apiKeys'] as List?)?.cast<String>() ?? [];
    return ApiKeysResponse(apiKeys: keys);
  }
}

// ---------------------------------------------------------------------------
// Market
// ---------------------------------------------------------------------------

/// A single YES or NO token for a market.
class Token {
  final String tokenId;
  final String outcome;
  final double? price;
  final bool? winner;

  const Token({
    required this.tokenId,
    required this.outcome,
    this.price,
    this.winner,
  });

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      tokenId: json['token_id'] as String,
      outcome: json['outcome'] as String,
      price: (json['price'] as num?)?.toDouble(),
      winner: json['winner'] as bool?,
    );
  }
}

/// A Polymarket prediction market.
class Market {
  final String conditionId;
  final String questionId;
  final String question;
  final String description;
  final bool active;
  final bool closed;
  final bool acceptingOrders;
  final bool enableOrderBook;
  final double minimumOrderSize;
  final double minimumTickSize;
  final bool negRisk;
  final String? feeRateBps;
  final String? endDateIso;
  final List<Token> tokens;
  final Map<String, dynamic>? rewards;

  const Market({
    required this.conditionId,
    required this.questionId,
    required this.question,
    required this.description,
    required this.active,
    required this.closed,
    required this.acceptingOrders,
    required this.enableOrderBook,
    required this.minimumOrderSize,
    required this.minimumTickSize,
    required this.negRisk,
    this.feeRateBps,
    this.endDateIso,
    required this.tokens,
    this.rewards,
  });

  factory Market.fromJson(Map<String, dynamic> json) {
    return Market(
      conditionId: json['condition_id'] as String,
      questionId: json['question_id'] as String? ?? '',
      question: json['question'] as String? ?? '',
      description: json['description'] as String? ?? '',
      active: json['active'] as bool? ?? false,
      closed: json['closed'] as bool? ?? false,
      acceptingOrders: json['accepting_orders'] as bool? ?? false,
      enableOrderBook: json['enable_order_book'] as bool? ?? false,
      minimumOrderSize:
          (json['minimum_order_size'] as num?)?.toDouble() ?? 0,
      minimumTickSize:
          (json['minimum_tick_size'] as num?)?.toDouble() ?? 0.01,
      negRisk: json['neg_risk'] as bool? ?? false,
      feeRateBps: json['fee_rate_bps']?.toString(),
      endDateIso: json['end_date_iso'] as String?,
      tokens: (json['tokens'] as List?)
              ?.map((t) => Token.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      rewards: json['rewards'] as Map<String, dynamic>?,
    );
  }
}

/// Paginated list of markets.
class MarketsPage {
  final List<Market> data;
  final String? nextCursor;
  final int? limit;
  final int? count;

  const MarketsPage({
    required this.data,
    this.nextCursor,
    this.limit,
    this.count,
  });

  factory MarketsPage.fromJson(Map<String, dynamic> json) {
    return MarketsPage(
      data: (json['data'] as List?)
              ?.map((m) => Market.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      nextCursor: json['next_cursor'] as String?,
      limit: json['limit'] as int?,
      count: json['count'] as int?,
    );
  }
}

// ---------------------------------------------------------------------------
// Orderbook
// ---------------------------------------------------------------------------

/// A single price level in the orderbook.
class OrderLevel {
  final String price;
  final String size;

  const OrderLevel({required this.price, required this.size});

  factory OrderLevel.fromJson(Map<String, dynamic> json) {
    return OrderLevel(
      price: json['price'].toString(),
      size: json['size'].toString(),
    );
  }
}

/// Parameters to identify a specific token side.
class BookParams {
  final String tokenId;
  final String? side; // 'BUY' or 'SELL'

  const BookParams({required this.tokenId, this.side});

  Map<String, dynamic> toJson() => {
        'token_id': tokenId,
        if (side != null) 'side': side,
      };
}

/// Full orderbook snapshot for a token.
class OrderBookSummary {
  final String market;
  final String asset;
  final String? hash;
  final List<OrderLevel> bids;
  final List<OrderLevel> asks;
  final int? timestamp;

  const OrderBookSummary({
    required this.market,
    required this.asset,
    this.hash,
    required this.bids,
    required this.asks,
    this.timestamp,
  });

  factory OrderBookSummary.fromJson(Map<String, dynamic> json) {
    return OrderBookSummary(
      market: json['market'] as String? ?? '',
      asset: json['asset_id'] as String? ?? '',
      hash: json['hash'] as String?,
      bids: (json['bids'] as List?)
              ?.map((b) => OrderLevel.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
      asks: (json['asks'] as List?)
              ?.map((a) => OrderLevel.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      timestamp: json['timestamp'] as int?,
    );
  }
}

// ---------------------------------------------------------------------------
// Pricing
// ---------------------------------------------------------------------------

class LastTradePrice {
  final String price;
  const LastTradePrice({required this.price});

  factory LastTradePrice.fromJson(Map<String, dynamic> json) {
    return LastTradePrice(price: json['price'].toString());
  }
}

class Spread {
  final String spread;
  const Spread({required this.spread});

  factory Spread.fromJson(Map<String, dynamic> json) {
    return Spread(spread: json['spread'].toString());
  }
}

/// A single point in price history.
class PricePoint {
  final int t; // unix timestamp
  final String p; // price

  const PricePoint({required this.t, required this.p});

  factory PricePoint.fromJson(Map<String, dynamic> json) {
    return PricePoint(
      t: json['t'] as int,
      p: json['p'].toString(),
    );
  }
}

/// Parameters for querying price history.
class PriceHistoryParams {
  final String market;
  final int? startTs;
  final int? endTs;
  final String? interval; // e.g. '1d', '1w', '1m', '3m', '6m', '1y', 'all'
  final String? fidelity; // number of data points

  const PriceHistoryParams({
    required this.market,
    this.startTs,
    this.endTs,
    this.interval,
    this.fidelity,
  });

  Map<String, String> toQueryParams() {
    final params = <String, String>{'market': market};
    if (startTs != null) params['startTs'] = startTs.toString();
    if (endTs != null) params['endTs'] = endTs.toString();
    if (interval != null) params['interval'] = interval!;
    if (fidelity != null) params['fidelity'] = fidelity!;
    return params;
  }
}

/// A market trade event (recent trade).
class MarketTradeEvent {
  final String id;
  final String market;
  final String timestamp;
  final String price;
  final String size;
  final String side;
  final String type;

  const MarketTradeEvent({
    required this.id,
    required this.market,
    required this.timestamp,
    required this.price,
    required this.size,
    required this.side,
    required this.type,
  });

  factory MarketTradeEvent.fromJson(Map<String, dynamic> json) {
    return MarketTradeEvent(
      id: json['id']?.toString() ?? '',
      market: json['market']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      side: json['side']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// Orders
// ---------------------------------------------------------------------------

/// Arguments to build a limit order.
class OrderArgs {
  final String tokenId;
  final double price; // 0.0001 to 0.9999
  final double size;
  final OrderSide side;
  final int feeRateBps;
  final String? nonce; // defaults to '0'
  final String? expiration; // unix timestamp string; '0' = no expiry
  final String? taker; // defaults to zero address

  const OrderArgs({
    required this.tokenId,
    required this.price,
    required this.size,
    required this.side,
    this.feeRateBps = 0,
    this.nonce,
    this.expiration,
    this.taker,
  });
}

/// Arguments to build a market order (dollar-amount based).
class MarketOrderArgs {
  final String tokenId;
  final double amount; // USDC amount to spend (BUY) or shares to sell (SELL)
  final OrderSide side;
  final int feeRateBps;
  final String? taker;

  const MarketOrderArgs({
    required this.tokenId,
    required this.amount,
    required this.side,
    this.feeRateBps = 0,
    this.taker,
  });
}

/// Options when building an order.
class CreateOrderOptions {
  final String? tickSize; // '0.1' | '0.01' | '0.001' | '0.0001'
  final bool negRisk;
  final String? funder; // override maker address

  const CreateOrderOptions({
    this.tickSize,
    this.negRisk = false,
    this.funder,
  });
}

/// A fully signed order ready for submission.
class SignedOrder {
  final String salt;
  final String maker;
  final String signer;
  final String taker;
  final String tokenId;
  final String makerAmount;
  final String takerAmount;
  final String expiration;
  final String nonce;
  final String feeRateBps;
  final int side; // 0 = BUY, 1 = SELL
  final int signatureType;
  final String signature;

  const SignedOrder({
    required this.salt,
    required this.maker,
    required this.signer,
    required this.taker,
    required this.tokenId,
    required this.makerAmount,
    required this.takerAmount,
    required this.expiration,
    required this.nonce,
    required this.feeRateBps,
    required this.side,
    required this.signatureType,
    required this.signature,
  });

  Map<String, dynamic> toJson() => {
        'salt': salt,
        'maker': maker,
        'signer': signer,
        'taker': taker,
        'tokenId': tokenId,
        'makerAmount': makerAmount,
        'takerAmount': takerAmount,
        'expiration': expiration,
        'nonce': nonce,
        'feeRateBps': feeRateBps,
        'side': side,
        'signatureType': signatureType,
        'signature': signature,
      };
}

/// Arguments for posting a single order.
class PostOrderArgs {
  final SignedOrder order;
  final String orderType; // 'GTC', 'GTD', 'FOK', 'FAK'
  final bool postOnly;

  const PostOrderArgs({
    required this.order,
    this.orderType = 'GTC',
    this.postOnly = false,
  });

  Map<String, dynamic> toJson(String apiKey) => {
        'order': order.toJson(),
        'owner': apiKey,
        'orderType': orderType,
        'postOnly': postOnly,
      };
}

/// Response from POST /order or POST /orders.
class PostOrderResponse {
  final String? orderId;
  final String? takingAmount;
  final String? makingAmount;
  final String? errorMsg;
  final String? orderType;
  final String? transactTime;
  final String? status;

  const PostOrderResponse({
    this.orderId,
    this.takingAmount,
    this.makingAmount,
    this.errorMsg,
    this.orderType,
    this.transactTime,
    this.status,
  });

  bool get isSuccess => errorMsg == null || errorMsg!.isEmpty;

  factory PostOrderResponse.fromJson(Map<String, dynamic> json) {
    return PostOrderResponse(
      orderId: json['orderID'] as String?,
      takingAmount: json['takingAmount']?.toString(),
      makingAmount: json['makingAmount']?.toString(),
      errorMsg: json['errorMsg'] as String?,
      orderType: json['orderType'] as String?,
      transactTime: json['transactTime']?.toString(),
      status: json['status'] as String?,
    );
  }
}

/// An open/active order.
class OpenOrder {
  final String id;
  final String asset;
  final String? tokenId;
  final String side;
  final String price;
  final String size;
  final String? sizeMatched;
  final String? originalSize;
  final String? orderType;
  final String? created;
  final String? expiration;
  final String? status;

  const OpenOrder({
    required this.id,
    required this.asset,
    this.tokenId,
    required this.side,
    required this.price,
    required this.size,
    this.sizeMatched,
    this.originalSize,
    this.orderType,
    this.created,
    this.expiration,
    this.status,
  });

  factory OpenOrder.fromJson(Map<String, dynamic> json) {
    return OpenOrder(
      id: json['id']?.toString() ?? '',
      asset: json['asset_id']?.toString() ?? '',
      tokenId: json['token_id']?.toString(),
      side: json['side']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
      size: json['size_remaining']?.toString() ?? json['size']?.toString() ?? '',
      sizeMatched: json['size_matched']?.toString(),
      originalSize: json['original_size']?.toString(),
      orderType: json['order_type']?.toString(),
      created: json['created_at']?.toString(),
      expiration: json['expiration']?.toString(),
      status: json['status']?.toString(),
    );
  }
}

class OpenOrderParams {
  final String? market;
  final String? owner;
  final String? id;

  const OpenOrderParams({this.market, this.owner, this.id});

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (market != null) params['market'] = market!;
    if (owner != null) params['owner'] = owner!;
    if (id != null) params['id'] = id!;
    return params;
  }
}

/// Paginated open orders response.
class OpenOrdersPage {
  final List<OpenOrder> data;
  final String? nextCursor;
  final int? limit;
  final int? count;

  const OpenOrdersPage({
    required this.data,
    this.nextCursor,
    this.limit,
    this.count,
  });

  factory OpenOrdersPage.fromJson(Map<String, dynamic> json) {
    return OpenOrdersPage(
      data: (json['data'] as List?)
              ?.map((o) => OpenOrder.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [],
      nextCursor: json['next_cursor'] as String?,
      limit: json['limit'] as int?,
      count: json['count'] as int?,
    );
  }
}

// ---------------------------------------------------------------------------
// Trades
// ---------------------------------------------------------------------------

class TradeParams {
  final String? marketId;
  final String? assetId;
  final String? side;
  final String? maker;
  final String? taker;
  final int? startTs;
  final int? endTs;

  const TradeParams({
    this.marketId,
    this.assetId,
    this.side,
    this.maker,
    this.taker,
    this.startTs,
    this.endTs,
  });

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (marketId != null) params['market'] = marketId!;
    if (assetId != null) params['asset_id'] = assetId!;
    if (side != null) params['side'] = side!;
    if (maker != null) params['maker'] = maker!;
    if (taker != null) params['taker'] = taker!;
    if (startTs != null) params['start_ts'] = startTs.toString();
    if (endTs != null) params['end_ts'] = endTs.toString();
    return params;
  }
}

class Trade {
  final String tradeId;
  final String orderId;
  final String maker;
  final String taker;
  final String price;
  final String size;
  final String side;
  final String matchTime;
  final String? type;

  const Trade({
    required this.tradeId,
    required this.orderId,
    required this.maker,
    required this.taker,
    required this.price,
    required this.size,
    required this.side,
    required this.matchTime,
    this.type,
  });

  factory Trade.fromJson(Map<String, dynamic> json) {
    return Trade(
      tradeId: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      maker: json['maker']?.toString() ?? '',
      taker: json['taker']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      side: json['side']?.toString() ?? '',
      matchTime: json['match_time']?.toString() ?? '',
      type: json['type']?.toString(),
    );
  }
}

class TradesPage {
  final List<Trade> data;
  final String? nextCursor;
  final int? limit;
  final int? count;

  const TradesPage({
    required this.data,
    this.nextCursor,
    this.limit,
    this.count,
  });

  factory TradesPage.fromJson(Map<String, dynamic> json) {
    return TradesPage(
      data: (json['data'] as List?)
              ?.map((t) => Trade.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      nextCursor: json['next_cursor'] as String?,
      limit: json['limit'] as int?,
      count: json['count'] as int?,
    );
  }
}

// ---------------------------------------------------------------------------
// Account
// ---------------------------------------------------------------------------

class BalanceAllowanceParams {
  final String? assetType; // 'collateral' or 'conditional'
  final String? tokenId;

  const BalanceAllowanceParams({this.assetType, this.tokenId});

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (assetType != null) params['asset_type'] = assetType!;
    if (tokenId != null) params['token_id'] = tokenId!;
    return params;
  }
}

class BalanceAllowance {
  final String? balance;
  final String? allowance;
  final String? assetAddress;

  const BalanceAllowance({this.balance, this.allowance, this.assetAddress});

  factory BalanceAllowance.fromJson(Map<String, dynamic> json) {
    return BalanceAllowance(
      balance: json['balance']?.toString(),
      allowance: json['allowance']?.toString(),
      assetAddress: json['asset_address']?.toString(),
    );
  }
}

class BanStatus {
  final bool isBanned;
  final String? reason;

  const BanStatus({required this.isBanned, this.reason});

  factory BanStatus.fromJson(Map<String, dynamic> json) {
    return BanStatus(
      isBanned: json['closed_only'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

class Notification {
  final String id;
  final String type;
  final String? message;
  final String? timestamp;

  const Notification({
    required this.id,
    required this.type,
    this.message,
    this.timestamp,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      message: json['message'] as String?,
      timestamp: json['timestamp']?.toString(),
    );
  }
}

class DropNotificationParams {
  final List<String>? ids;

  const DropNotificationParams({this.ids});

  Map<String, dynamic> toJson() => {
        if (ids != null) 'ids': ids,
      };
}

// ---------------------------------------------------------------------------
// Order scoring
// ---------------------------------------------------------------------------

class OrderScoring {
  final bool scoring;
  const OrderScoring({required this.scoring});

  factory OrderScoring.fromJson(Map<String, dynamic> json) {
    return OrderScoring(scoring: json['scoring'] as bool? ?? false);
  }
}

class OrdersScoring {
  final Map<String, bool> ordersScoring;

  const OrdersScoring({required this.ordersScoring});

  factory OrdersScoring.fromJson(Map<String, dynamic> json) {
    final raw = json['ordersScoring'] as Map<String, dynamic>? ?? {};
    return OrdersScoring(
      ordersScoring: raw.map((k, v) => MapEntry(k, v as bool)),
    );
  }
}

// ---------------------------------------------------------------------------
// Heartbeat
// ---------------------------------------------------------------------------

class HeartbeatResponse {
  final String? id;
  const HeartbeatResponse({this.id});

  factory HeartbeatResponse.fromJson(Map<String, dynamic> json) {
    return HeartbeatResponse(id: json['id']?.toString());
  }
}
