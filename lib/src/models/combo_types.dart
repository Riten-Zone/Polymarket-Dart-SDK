/// Data models for the Polymarket Combos / RFQ system.
///
/// Combos are multi-leg positions that combine several underlying market
/// outcomes into a single YES or NO position. Combo trades are executed
/// through a request-for-quote (RFQ) auction: a user posts a Request, market
/// makers ("quoters") compete by submitting signed Quotes, and — when Last
/// Look is enabled — the winning quoter confirms or declines the fill.
///
/// REST hosts:
/// - `https://combos-rfq-api.polymarket.com` — combo markets + maker endpoints
/// - `https://data-api.polymarket.com` — combo positions + activity
library;

// ---------------------------------------------------------------------------
// Combo markets (public)
// ---------------------------------------------------------------------------

/// A market that can be used as a combo leg.
///
/// `positionIds`, `outcomes`, and `outcomePrices` are aligned by index:
/// index 0 is the YES outcome/position, index 1 is the NO outcome/position.
class ComboMarket {
  final String id;
  final String conditionId;

  /// Position IDs for this market. `[YES positionId, NO positionId]`.
  final List<String> positionIds;
  final String slug;
  final String title;

  /// Outcome labels, index-aligned with [positionIds] (0 = YES, 1 = NO).
  final List<String> outcomes;

  /// Outcome prices as strings, index-aligned with [outcomes].
  final List<String> outcomePrices;
  final String? image;
  final double volume;
  final List<String> tags;

  const ComboMarket({
    required this.id,
    required this.conditionId,
    required this.positionIds,
    required this.slug,
    required this.title,
    required this.outcomes,
    required this.outcomePrices,
    this.image,
    required this.volume,
    required this.tags,
  });

  factory ComboMarket.fromJson(Map<String, dynamic> json) => ComboMarket(
        id: json['id'] as String? ?? '',
        conditionId: json['condition_id'] as String? ?? '',
        positionIds: _stringList(json['position_ids']),
        slug: json['slug'] as String? ?? '',
        title: json['title'] as String? ?? '',
        outcomes: _stringList(json['outcomes']),
        outcomePrices: _stringList(json['outcome_prices']),
        image: json['image'] as String?,
        volume: _toDouble(json['volume']),
        tags: _stringList(json['tags']),
      );
}

/// One page of combo markets, with an opaque forward cursor.
class ComboMarketsPage {
  final List<ComboMarket> markets;
  final String? nextCursor;

  const ComboMarketsPage({required this.markets, this.nextCursor});

  factory ComboMarketsPage.fromJson(Map<String, dynamic> json) {
    final raw = json['markets'] as List<dynamic>? ?? [];
    return ComboMarketsPage(
      markets: raw
          .map((e) => ComboMarket.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['next_cursor'] as String?,
    );
  }
}

/// Filter parameters for [ComboClient.getComboMarkets].
class GetComboMarketsParams {
  /// Number of markets to return (default 50, max 100).
  final int? limit;

  /// Opaque cursor from a previous response's `next_cursor`.
  final String? cursor;

  /// Condition IDs to omit from the result.
  final List<String>? exclude;

  const GetComboMarketsParams({this.limit, this.cursor, this.exclude});

  Map<String, String> toQueryParams() {
    final p = <String, String>{};
    if (limit != null) p['limit'] = limit!.toString();
    if (cursor != null) p['cursor'] = cursor!;
    if (exclude != null && exclude!.isNotEmpty) {
      p['exclude'] = exclude!.join(',');
    }
    return p;
  }
}

// ---------------------------------------------------------------------------
// Combo positions + activity (public, Data API)
// ---------------------------------------------------------------------------

/// Cursor/offset pagination block returned by combo Data API endpoints.
class ComboPagination {
  final int limit;
  final int offset;
  final bool hasMore;
  final String? nextCursor;

  const ComboPagination({
    required this.limit,
    required this.offset,
    required this.hasMore,
    this.nextCursor,
  });

  factory ComboPagination.fromJson(Map<String, dynamic> json) =>
      ComboPagination(
        limit: (json['limit'] as num?)?.toInt() ?? 0,
        offset: (json['offset'] as num?)?.toInt() ?? 0,
        hasMore: json['has_more'] as bool? ?? false,
        nextCursor: json['next_cursor'] as String?,
      );
}

/// A user's position in a combo, preserving the raw payload for forward
/// compatibility (`raw`) alongside the commonly used fields.
class ComboPosition {
  final String? comboPositionId;
  final String? comboConditionId;
  final String? status;
  final Map<String, dynamic> raw;

  const ComboPosition({
    this.comboPositionId,
    this.comboConditionId,
    this.status,
    required this.raw,
  });

  factory ComboPosition.fromJson(Map<String, dynamic> json) => ComboPosition(
        comboPositionId: json['combo_position_id'] as String?,
        comboConditionId: json['combo_condition_id'] as String?,
        status: json['status'] as String?,
        raw: json,
      );
}

/// One page of combo positions.
class ComboPositionsPage {
  final List<ComboPosition> combos;
  final ComboPagination? pagination;

  const ComboPositionsPage({required this.combos, this.pagination});

  factory ComboPositionsPage.fromJson(Map<String, dynamic> json) {
    final raw = json['combos'] as List<dynamic>? ?? [];
    final page = json['pagination'];
    return ComboPositionsPage(
      combos: raw
          .map((e) => ComboPosition.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: page is Map<String, dynamic>
          ? ComboPagination.fromJson(page)
          : null,
    );
  }
}

/// Filter parameters for [ComboClient.getComboPositions].
class GetComboPositionsParams {
  /// Wallet address to query (required).
  final String user;
  final int? limit;
  final int? offset;
  final String? cursor;

  /// Filter by combo `condition_id`.
  final String? marketId;

  /// Filter by a specific combo position ID.
  final String? comboPositionId;

  /// Comma-separated status filter:
  /// OPEN, PARTIAL, RESOLVED_PARTIAL, RESOLVED_WIN, RESOLVED_LOSS.
  final List<String>? status;

  /// Sort key, e.g. `first_entry_desc` or `updated_asc`.
  final String? sort;

  /// Epoch seconds — return only positions updated after this (incremental).
  final int? updatedAfter;

  const GetComboPositionsParams({
    required this.user,
    this.limit,
    this.offset,
    this.cursor,
    this.marketId,
    this.comboPositionId,
    this.status,
    this.sort,
    this.updatedAfter,
  });

  Map<String, String> toQueryParams() {
    final p = <String, String>{'user': user};
    if (limit != null) p['limit'] = limit!.toString();
    if (offset != null) p['offset'] = offset!.toString();
    if (cursor != null) p['cursor'] = cursor!;
    if (marketId != null) p['market_id'] = marketId!;
    if (comboPositionId != null) p['combo_position_id'] = comboPositionId!;
    if (status != null && status!.isNotEmpty) {
      p['status'] = status!.join(',');
    }
    if (sort != null) p['sort'] = sort!;
    if (updatedAfter != null) p['updatedAfter'] = updatedAfter!.toString();
    return p;
  }
}

/// A combo lifecycle event (SPLIT, MERGE, CONVERT, COMPRESS, WRAP, UNWRAP,
/// REDEEM). The raw payload is preserved for forward compatibility.
class ComboActivity {
  final String? type;
  final String? comboConditionId;
  final int? timestamp;
  final Map<String, dynamic> raw;

  const ComboActivity({
    this.type,
    this.comboConditionId,
    this.timestamp,
    required this.raw,
  });

  factory ComboActivity.fromJson(Map<String, dynamic> json) => ComboActivity(
        type: json['type'] as String?,
        comboConditionId: json['combo_condition_id'] as String?,
        timestamp: (json['timestamp'] as num?)?.toInt(),
        raw: json,
      );
}

/// One page of combo activity events.
class ComboActivityPage {
  final List<ComboActivity> activity;
  final ComboPagination? pagination;

  const ComboActivityPage({required this.activity, this.pagination});

  factory ComboActivityPage.fromJson(Map<String, dynamic> json) {
    final raw = json['activity'] as List<dynamic>? ?? [];
    final page = json['pagination'];
    return ComboActivityPage(
      activity: raw
          .map((e) => ComboActivity.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: page is Map<String, dynamic>
          ? ComboPagination.fromJson(page)
          : null,
    );
  }
}

/// Filter parameters for [ComboClient.getComboActivity].
class GetComboActivityParams {
  final String user;
  final int? limit;
  final int? offset;
  final String? cursor;

  /// Comma-separated combo condition IDs.
  final List<String>? marketId;
  final String? sort;

  const GetComboActivityParams({
    required this.user,
    this.limit,
    this.offset,
    this.cursor,
    this.marketId,
    this.sort,
  });

  Map<String, String> toQueryParams() {
    final p = <String, String>{'user': user};
    if (limit != null) p['limit'] = limit!.toString();
    if (offset != null) p['offset'] = offset!.toString();
    if (cursor != null) p['cursor'] = cursor!;
    if (marketId != null && marketId!.isNotEmpty) {
      p['market_id'] = marketId!.join(',');
    }
    if (sort != null) p['sort'] = sort!;
    return p;
  }
}

// ---------------------------------------------------------------------------
// Maker quote flow (authenticated)
// ---------------------------------------------------------------------------

/// A signed CTF Exchange order attached to a quote.
///
/// All amounts are strings in base units. This mirrors the exact field names
/// the Combos/RFQ API expects, including the `builder` attribution field.
class SignedRfqOrder {
  final String salt;
  final String maker;
  final String signer;
  final String tokenId;
  final String makerAmount;
  final String takerAmount;

  /// Order side as the numeric enum (0 = BUY, 1 = SELL).
  final int side;

  /// Signature type (0 = EOA, 1 = POLY_PROXY, 2 = POLY_GNOSIS_SAFE,
  /// 3 = POLY_1271 deposit wallet).
  final int signatureType;
  final String timestamp;
  final String metadata;
  final String builder;
  final String signature;

  const SignedRfqOrder({
    required this.salt,
    required this.maker,
    required this.signer,
    required this.tokenId,
    required this.makerAmount,
    required this.takerAmount,
    required this.side,
    required this.signatureType,
    required this.timestamp,
    this.metadata = '',
    this.builder = '',
    required this.signature,
  });

  Map<String, dynamic> toJson() => {
        'salt': salt,
        'maker': maker,
        'signer': signer,
        'tokenId': tokenId,
        'makerAmount': makerAmount,
        'takerAmount': takerAmount,
        'side': side,
        'signatureType': signatureType,
        'timestamp': timestamp,
        'metadata': metadata,
        'builder': builder,
        'signature': signature,
      };

  factory SignedRfqOrder.fromJson(Map<String, dynamic> json) => SignedRfqOrder(
        salt: json['salt']?.toString() ?? '',
        maker: json['maker'] as String? ?? '',
        signer: json['signer'] as String? ?? '',
        tokenId: json['tokenId']?.toString() ?? '',
        makerAmount: json['makerAmount']?.toString() ?? '',
        takerAmount: json['takerAmount']?.toString() ?? '',
        side: (json['side'] as num?)?.toInt() ?? 0,
        signatureType: (json['signatureType'] as num?)?.toInt() ?? 0,
        timestamp: json['timestamp']?.toString() ?? '',
        metadata: json['metadata'] as String? ?? '',
        builder: json['builder'] as String? ?? '',
        signature: json['signature'] as String? ?? '',
      );
}

/// Parameters for submitting a quote (`POST /v1/maker/quotes`).
class SubmitQuoteParams {
  /// Client-generated quote identifier.
  final String quoteId;
  final String rfqId;
  final String signerAddress;
  final String makerAddress;

  /// Signature type of the maker wallet (0–3).
  final int signatureType;

  /// Price in base units (1e6-scaled), as a string.
  final String priceE6;

  /// Size in base units (1e6-scaled), as a string.
  final String sizeE6;
  final SignedRfqOrder signedOrder;

  const SubmitQuoteParams({
    required this.quoteId,
    required this.rfqId,
    required this.signerAddress,
    required this.makerAddress,
    required this.signatureType,
    required this.priceE6,
    required this.sizeE6,
    required this.signedOrder,
  });

  Map<String, dynamic> toJson() => {
        'quote_id': quoteId,
        'rfq_id': rfqId,
        'signer_address': signerAddress,
        'maker_address': makerAddress,
        'signature_type': signatureType,
        'price_e6': priceE6,
        'size_e6': sizeE6,
        'signed_order': signedOrder.toJson(),
      };
}

/// Parameters for cancelling a quote (`POST /v1/maker/quotes/cancel`).
class CancelQuoteParams {
  final String rfqId;
  final String quoteId;
  final String signerAddress;
  final String makerAddress;
  final int signatureType;

  const CancelQuoteParams({
    required this.rfqId,
    required this.quoteId,
    required this.signerAddress,
    required this.makerAddress,
    required this.signatureType,
  });

  Map<String, dynamic> toJson() => {
        'rfq_id': rfqId,
        'quote_id': quoteId,
        'signer_address': signerAddress,
        'maker_address': makerAddress,
        'signature_type': signatureType,
      };
}

/// Last-look decision.
enum LastLookDecision {
  confirm,
  decline;

  String toJson() => name.toUpperCase();
}

/// Parameters for a last-look confirmation (`POST /v1/maker/confirmations`).
class ConfirmationParams {
  final String rfqId;
  final String quoteId;
  final String signerAddress;
  final String makerAddress;
  final int signatureType;
  final LastLookDecision decision;

  const ConfirmationParams({
    required this.rfqId,
    required this.quoteId,
    required this.signerAddress,
    required this.makerAddress,
    required this.signatureType,
    required this.decision,
  });

  Map<String, dynamic> toJson() => {
        'rfq_id': rfqId,
        'quote_id': quoteId,
        'signer_address': signerAddress,
        'maker_address': makerAddress,
        'signature_type': signatureType,
        'decision': decision.toJson(),
      };
}

/// A snapshot of an RFQ returned by the maker quote/cancel/confirmation
/// endpoints. The raw payload is preserved for forward compatibility.
class RfqSnapshot {
  final String? rfqId;
  final String? status;
  final Map<String, dynamic> raw;

  const RfqSnapshot({this.rfqId, this.status, required this.raw});

  factory RfqSnapshot.fromJson(Map<String, dynamic> json) => RfqSnapshot(
        rfqId: json['rfq_id'] as String? ?? json['rfqId'] as String?,
        status: json['status'] as String?,
        raw: json,
      );
}

// ---------------------------------------------------------------------------
// Quoter Gateway WebSocket messages
// ---------------------------------------------------------------------------

/// An inbound RFQ request pushed to a connected quoter over the gateway.
class RfqRequestEvent {
  final String rfqId;
  final String? requestorPublicId;
  final List<String> legPositionIds;
  final String? conditionId;
  final String? yesPositionId;
  final String? noPositionId;

  /// `BUY` or `SELL`.
  final String? direction;
  final String? side;

  /// Requested size unit: `notional` or `shares`.
  final String? sizeUnit;

  /// Requested size in base units (1e6-scaled), as a string.
  final String? sizeValueE6;

  /// Epoch millis by which a quote must be submitted.
  final int? submissionDeadline;
  final Map<String, dynamic> raw;

  const RfqRequestEvent({
    required this.rfqId,
    this.requestorPublicId,
    required this.legPositionIds,
    this.conditionId,
    this.yesPositionId,
    this.noPositionId,
    this.direction,
    this.side,
    this.sizeUnit,
    this.sizeValueE6,
    this.submissionDeadline,
    required this.raw,
  });

  factory RfqRequestEvent.fromJson(Map<String, dynamic> json) {
    final size = json['requested_size'];
    return RfqRequestEvent(
      rfqId: json['rfq_id'] as String? ?? '',
      requestorPublicId: json['requestor_public_id'] as String?,
      legPositionIds: _stringList(json['leg_position_ids']),
      conditionId: json['condition_id'] as String?,
      yesPositionId: json['yes_position_id'] as String?,
      noPositionId: json['no_position_id'] as String?,
      direction: json['direction'] as String?,
      side: json['side'] as String?,
      sizeUnit: size is Map<String, dynamic> ? size['unit'] as String? : null,
      sizeValueE6:
          size is Map<String, dynamic> ? size['value_e6']?.toString() : null,
      submissionDeadline: (json['submission_deadline'] as num?)?.toInt(),
      raw: json,
    );
  }
}

/// An inbound last-look confirmation request pushed to a quoter.
class RfqConfirmationRequestEvent {
  final String rfqId;
  final String quoteId;
  final String? signerAddress;
  final String? makerAddress;
  final int? signatureType;
  final String? conditionId;
  final String? direction;
  final String? fillSizeE6;
  final String? priceE6;

  /// Epoch millis by which the confirmation must be sent.
  final int? confirmBy;
  final Map<String, dynamic> raw;

  const RfqConfirmationRequestEvent({
    required this.rfqId,
    required this.quoteId,
    this.signerAddress,
    this.makerAddress,
    this.signatureType,
    this.conditionId,
    this.direction,
    this.fillSizeE6,
    this.priceE6,
    this.confirmBy,
    required this.raw,
  });

  factory RfqConfirmationRequestEvent.fromJson(Map<String, dynamic> json) =>
      RfqConfirmationRequestEvent(
        rfqId: json['rfq_id'] as String? ?? '',
        quoteId: json['quote_id'] as String? ?? '',
        signerAddress: json['signer_address'] as String?,
        makerAddress: json['maker_address'] as String?,
        signatureType: (json['signature_type'] as num?)?.toInt(),
        conditionId: json['condition_id'] as String?,
        direction: json['direction'] as String?,
        fillSizeE6: json['fill_size_e6']?.toString(),
        priceE6: json['price_e6']?.toString(),
        confirmBy: (json['confirm_by'] as num?)?.toInt(),
        raw: json,
      );
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  return const [];
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}
