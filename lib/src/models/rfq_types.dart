/// Data models for the Polymarket RFQ (Request for Quote) API.
///
/// RFQ is a market-maker system where requesters post buy/sell requests
/// and quoters (liquidity providers) respond with competing quotes.
library;

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// How the matching engine fills the RFQ order.
enum MatchType {
  complementary,
  mint,
  merge;

  String toJson() => name.toUpperCase();

  static MatchType fromJson(String value) {
    return MatchType.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => MatchType.complementary,
    );
  }
}

// ---------------------------------------------------------------------------
// Request params (caller → API)
// ---------------------------------------------------------------------------

/// Parameters for creating an RFQ request (requester side).
class RfqUserRequest {
  final String tokenId;
  final double price;
  final String side; // 'BUY' or 'SELL'
  final double size;

  const RfqUserRequest({
    required this.tokenId,
    required this.price,
    required this.side,
    required this.size,
  });

  Map<String, dynamic> toJson() => {
        'token_id': tokenId,
        'price': price,
        'side': side.toUpperCase(),
        'size': size,
      };
}

/// Parameters for creating an RFQ quote (quoter side).
class RfqUserQuote {
  final String requestId;
  final String tokenId;
  final double price;
  final String side; // 'BUY' or 'SELL'
  final double size;

  const RfqUserQuote({
    required this.requestId,
    required this.tokenId,
    required this.price,
    required this.side,
    required this.size,
  });

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'token_id': tokenId,
        'price': price,
        'side': side.toUpperCase(),
        'size': size,
      };
}

/// Parameters for accepting a quote (requester side).
class AcceptQuoteParams {
  final String requestId;
  final String quoteId;
  final int expiration; // unix timestamp

  const AcceptQuoteParams({
    required this.requestId,
    required this.quoteId,
    required this.expiration,
  });

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'quote_id': quoteId,
        'expiration': expiration,
      };
}

/// Parameters for approving an order (quoter side).
class ApproveOrderParams {
  final String requestId;
  final String quoteId;
  final int expiration; // unix timestamp

  const ApproveOrderParams({
    required this.requestId,
    required this.quoteId,
    required this.expiration,
  });

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'quote_id': quoteId,
        'expiration': expiration,
      };
}

/// Parameters for cancelling an RFQ request.
class CancelRfqRequestParams {
  final String requestId;

  const CancelRfqRequestParams({required this.requestId});

  Map<String, dynamic> toJson() => {'request_id': requestId};
}

/// Parameters for cancelling an RFQ quote.
class CancelRfqQuoteParams {
  final String quoteId;

  const CancelRfqQuoteParams({required this.quoteId});

  Map<String, dynamic> toJson() => {'quote_id': quoteId};
}

/// Filter parameters for listing RFQ requests.
class GetRfqRequestsParams {
  final String? state;
  final List<String>? requestIds;
  final List<String>? markets;
  final double? sizeMin;
  final double? sizeMax;
  final double? priceMin;
  final double? priceMax;
  final String? sortBy;
  final String? sortDir; // 'asc' or 'desc'
  final int? limit;
  final String? offset;

  const GetRfqRequestsParams({
    this.state,
    this.requestIds,
    this.markets,
    this.sizeMin,
    this.sizeMax,
    this.priceMin,
    this.priceMax,
    this.sortBy,
    this.sortDir,
    this.limit,
    this.offset,
  });

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (state != null) params['state'] = state!;
    if (requestIds != null) params['request_ids'] = requestIds!.join(',');
    if (markets != null) params['markets'] = markets!.join(',');
    if (sizeMin != null) params['size_min'] = sizeMin!.toString();
    if (sizeMax != null) params['size_max'] = sizeMax!.toString();
    if (priceMin != null) params['price_min'] = priceMin!.toString();
    if (priceMax != null) params['price_max'] = priceMax!.toString();
    if (sortBy != null) params['sort_by'] = sortBy!;
    if (sortDir != null) params['sort_dir'] = sortDir!;
    if (limit != null) params['limit'] = limit!.toString();
    if (offset != null) params['offset'] = offset!;
    return params;
  }
}

/// Filter parameters for listing RFQ quotes.
class GetRfqQuotesParams {
  final String? state;
  final int? limit;
  final String? offset;

  const GetRfqQuotesParams({this.state, this.limit, this.offset});

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (state != null) params['state'] = state!;
    if (limit != null) params['limit'] = limit!.toString();
    if (offset != null) params['offset'] = offset!;
    return params;
  }
}

/// Parameters for fetching the best quote for a request.
class GetRfqBestQuoteParams {
  final String requestId;

  const GetRfqBestQuoteParams({required this.requestId});

  Map<String, String> toQueryParams() => {'request_id': requestId};
}

// ---------------------------------------------------------------------------
// Response objects (API → caller)
// ---------------------------------------------------------------------------

/// Response after creating an RFQ request.
class RfqRequestResponse {
  final String? requestId;
  final String? error;

  const RfqRequestResponse({this.requestId, this.error});

  factory RfqRequestResponse.fromJson(Map<String, dynamic> json) =>
      RfqRequestResponse(
        requestId: json['requestId'] as String?,
        error: json['error'] as String?,
      );
}

/// Response after creating an RFQ quote.
class RfqQuoteResponse {
  final String? quoteId;
  final String? error;

  const RfqQuoteResponse({this.quoteId, this.error});

  factory RfqQuoteResponse.fromJson(Map<String, dynamic> json) =>
      RfqQuoteResponse(
        quoteId: json['quoteId'] as String?,
        error: json['error'] as String?,
      );
}

/// Full RFQ request object returned by the API.
class RfqRequest {
  final String requestId;
  final String maker;
  final String tokenId;
  final double price;
  final String side;
  final double size;
  final int? timestamp;
  final String? status;

  const RfqRequest({
    required this.requestId,
    required this.maker,
    required this.tokenId,
    required this.price,
    required this.side,
    required this.size,
    this.timestamp,
    this.status,
  });

  factory RfqRequest.fromJson(Map<String, dynamic> json) => RfqRequest(
        requestId: json['requestId'] as String? ?? '',
        maker: json['maker'] as String? ?? '',
        tokenId: json['tokenId'] as String? ?? '',
        price: _toDouble(json['price']),
        side: json['side'] as String? ?? '',
        size: _toDouble(json['size']),
        timestamp: json['timestamp'] as int?,
        status: json['status'] as String?,
      );
}

/// Full RFQ quote object returned by the API.
class RfqQuote {
  final String quoteId;
  final String quoter;
  final String requestId;
  final String tokenId;
  final double price;
  final String side;
  final double size;
  final int? timestamp;
  final String? status;

  const RfqQuote({
    required this.quoteId,
    required this.quoter,
    required this.requestId,
    required this.tokenId,
    required this.price,
    required this.side,
    required this.size,
    this.timestamp,
    this.status,
  });

  factory RfqQuote.fromJson(Map<String, dynamic> json) => RfqQuote(
        quoteId: json['quoteId'] as String? ?? '',
        quoter: json['quoter'] as String? ?? '',
        requestId: json['requestId'] as String? ?? '',
        tokenId: json['tokenId'] as String? ?? '',
        price: _toDouble(json['price']),
        side: json['side'] as String? ?? '',
        size: _toDouble(json['size']),
        timestamp: json['timestamp'] as int?,
        status: json['status'] as String?,
      );
}

/// Paginated response for RFQ list endpoints.
class RfqPaginatedResponse<T> {
  final List<T> data;
  final String? cursor;
  final String? nextCursor;
  final int count;
  final int totalCount;

  const RfqPaginatedResponse({
    required this.data,
    this.cursor,
    this.nextCursor,
    required this.count,
    required this.totalCount,
  });

  factory RfqPaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromItem,
  ) {
    final rawData = json['data'] as List<dynamic>? ?? [];
    return RfqPaginatedResponse(
      data: rawData.map((e) => fromItem(e as Map<String, dynamic>)).toList(),
      cursor: json['cursor'] as String?,
      nextCursor: json['next_cursor'] as String?,
      count: json['count'] as int? ?? 0,
      totalCount: json['total_count'] as int? ?? 0,
    );
  }
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}
