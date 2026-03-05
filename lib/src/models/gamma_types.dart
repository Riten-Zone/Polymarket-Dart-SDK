/// Type definitions for the Polymarket Gamma API.
library;

import 'dart:convert';

// ---------------------------------------------------------------------------
// Tag
// ---------------------------------------------------------------------------

/// A category tag used to group Polymarket prediction markets.
class Tag {
  /// Unique tag identifier.
  final int id;

  /// Human-readable label (e.g. "Politics", "Crypto").
  final String label;

  /// URL slug for the tag.
  final String slug;

  const Tag({
    required this.id,
    required this.label,
    required this.slug,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: _parseInt(json['id']),
      label: json['label'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
    );
  }

  @override
  String toString() => 'Tag(id: $id, label: $label)';
}

// ---------------------------------------------------------------------------
// GammaMarket
// ---------------------------------------------------------------------------

/// A Polymarket prediction market as returned by the Gamma API.
///
/// Unlike the CLOB [Market] type, [GammaMarket] includes richer metadata such
/// as volume, liquidity, tags, and the question image URL. Use this for market
/// discovery and display.
class GammaMarket {
  /// Numeric market ID (used with [GammaClient.getMarket]).
  final int id;

  /// The CTF condition ID (hex string starting with 0x).
  final String conditionId;

  /// URL-friendly slug (e.g. "will-trump-win-2024").
  final String slug;

  /// Market question text.
  final String question;

  /// Extended description of the market.
  final String description;

  /// Whether the market is currently open for trading.
  final bool active;

  /// Whether the market has been closed/resolved.
  final bool closed;

  /// Whether the market is accepting new orders on the CLOB.
  final bool acceptingOrders;

  /// Whether this is a neg-risk market.
  final bool negRisk;

  /// Market image URL.
  final String? image;

  /// Market icon URL (smaller than [image]).
  final String? icon;

  /// Total cumulative volume (USDC).
  final double volume;

  /// 24-hour trading volume (USDC).
  final double volume24hr;

  /// Total on-book liquidity (USDC).
  final double liquidity;

  /// CLOB token IDs for each outcome (YES/NO).
  ///
  /// Note: the Gamma API returns this as a JSON-encoded string —
  /// this field is already decoded to a list.
  final List<String> clobTokenIds;

  /// Tags attached to this market.
  final List<Tag> tags;

  /// Market start date (ISO 8601) if set.
  final String? startDate;

  /// Market end/resolution date (ISO 8601).
  final String? endDate;

  const GammaMarket({
    required this.id,
    required this.conditionId,
    required this.slug,
    required this.question,
    required this.description,
    required this.active,
    required this.closed,
    required this.acceptingOrders,
    required this.negRisk,
    required this.volume,
    required this.volume24hr,
    required this.liquidity,
    required this.clobTokenIds,
    required this.tags,
    this.image,
    this.icon,
    this.startDate,
    this.endDate,
  });

  factory GammaMarket.fromJson(Map<String, dynamic> json) {
    // clobTokenIds is stored as a JSON-encoded string in the Gamma API response.
    final rawTokenIds = json['clobTokenIds'];
    List<String> tokenIds = [];
    if (rawTokenIds is String && rawTokenIds.isNotEmpty) {
      final decoded = jsonDecode(rawTokenIds);
      if (decoded is List) {
        tokenIds = decoded.map((e) => e.toString()).toList();
      }
    } else if (rawTokenIds is List) {
      tokenIds = rawTokenIds.map((e) => e.toString()).toList();
    }

    final rawTags = json['tags'] as List?;
    final tags = rawTags
            ?.map((t) => Tag.fromJson(t as Map<String, dynamic>))
            .toList() ??
        [];

    return GammaMarket(
      id: _parseInt(json['id']),
      conditionId: json['conditionId'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      question: json['question'] as String? ?? '',
      description: json['description'] as String? ?? '',
      active: json['active'] as bool? ?? false,
      closed: json['closed'] as bool? ?? false,
      acceptingOrders: json['acceptingOrders'] as bool? ?? false,
      negRisk: json['negRisk'] as bool? ?? false,
      image: json['image'] as String?,
      icon: json['icon'] as String?,
      volume: _toDouble(json['volume']),
      volume24hr: _toDouble(json['volume24hr']),
      liquidity: _toDouble(json['liquidity']),
      clobTokenIds: tokenIds,
      tags: tags,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
    );
  }

  @override
  String toString() =>
      'GammaMarket(conditionId: $conditionId, question: $question, active: $active)';
}

// ---------------------------------------------------------------------------
// GammaEvent
// ---------------------------------------------------------------------------

/// A Polymarket event — a grouping of related prediction markets.
///
/// Events represent real-world happenings (e.g. "2024 US Election") that
/// contain multiple [GammaMarket] instances (e.g. "Will Trump win?", "Will
/// Harris win?").
class GammaEvent {
  /// Unique event ID.
  final int id;

  /// Event title.
  final String title;

  /// Event description.
  final String description;

  /// URL slug (e.g. "2024-us-election").
  final String slug;

  /// Whether the event is currently active.
  final bool active;

  /// Whether the event has been archived/closed.
  final bool closed;

  /// Markets belonging to this event.
  final List<GammaMarket> markets;

  /// Tags attached to this event.
  final List<Tag> tags;

  /// Event start date (ISO 8601).
  final String? startDate;

  /// Event end date (ISO 8601).
  final String? endDate;

  const GammaEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.slug,
    required this.active,
    required this.closed,
    required this.markets,
    required this.tags,
    this.startDate,
    this.endDate,
  });

  factory GammaEvent.fromJson(Map<String, dynamic> json) {
    final rawMarkets = json['markets'] as List?;
    final markets = rawMarkets
            ?.map((m) => GammaMarket.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [];

    final rawTags = json['tags'] as List?;
    final tags = rawTags
            ?.map((t) => Tag.fromJson(t as Map<String, dynamic>))
            .toList() ??
        [];

    return GammaEvent(
      id: _parseInt(json['id']),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      active: json['active'] as bool? ?? false,
      closed: json['closed'] as bool? ?? false,
      markets: markets,
      tags: tags,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
    );
  }

  @override
  String toString() => 'GammaEvent(id: $id, title: $title, active: $active)';
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}

/// Parses an int that the Gamma API may return as either int or String.
int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? 0;
}
