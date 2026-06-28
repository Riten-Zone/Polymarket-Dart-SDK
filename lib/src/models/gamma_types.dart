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

  final bool? forceShow;
  final bool? forceHide;
  final bool? isCarousel;
  final bool? requiresTranslation;
  final String? publishedAt;
  final int? createdBy;
  final int? updatedBy;
  final String? createdAt;
  final String? updatedAt;
  final int? activeEventsCount;

  const Tag({
    required this.id,
    required this.label,
    required this.slug,
    this.forceShow,
    this.forceHide,
    this.isCarousel,
    this.requiresTranslation,
    this.publishedAt,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.activeEventsCount,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: _parseInt(json['id']),
      label: json['label'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      forceShow: json['forceShow'] as bool?,
      forceHide: json['forceHide'] as bool?,
      isCarousel: json['isCarousel'] as bool?,
      requiresTranslation: json['requiresTranslation'] as bool?,
      publishedAt: json['publishedAt'] as String?,
      createdBy: json['createdBy'] == null
          ? null
          : _parseInt(json['createdBy']),
      updatedBy: json['updatedBy'] == null
          ? null
          : _parseInt(json['updatedBy']),
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      activeEventsCount: json['activeEventsCount'] == null
          ? null
          : _parseInt(json['activeEventsCount']),
    );
  }

  @override
  String toString() => 'Tag(id: $id, label: $label)';
}

/// A relationship row linking one tag to another.
class RelatedTag {
  final String id;
  final int? tagId;
  final int? relatedTagId;
  final int? rank;

  const RelatedTag({
    required this.id,
    this.tagId,
    this.relatedTagId,
    this.rank,
  });

  factory RelatedTag.fromJson(Map<String, dynamic> json) {
    return RelatedTag(
      id: json['id']?.toString() ?? '',
      tagId: json['tagID'] == null ? null : _parseInt(json['tagID']),
      relatedTagId: json['relatedTagID'] == null
          ? null
          : _parseInt(json['relatedTagID']),
      rank: json['rank'] == null ? null : _parseInt(json['rank']),
    );
  }
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

  /// Current outcome prices (e.g. [0.72, 0.28] for YES/NO).
  ///
  /// The Gamma API returns this as a JSON-encoded string —
  /// this field is already decoded to a list of doubles.
  final List<double> outcomePrices;

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
    required this.outcomePrices,
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

    // outcomePrices is a JSON-encoded string: "[\"0.72\", \"0.28\"]"
    final rawPrices = json['outcomePrices'];
    List<double> outcomePrices = [];
    if (rawPrices is String && rawPrices.isNotEmpty) {
      final decoded = jsonDecode(rawPrices);
      if (decoded is List) {
        outcomePrices = decoded
            .map((e) => double.tryParse(e.toString()) ?? 0.0)
            .toList();
      }
    } else if (rawPrices is List) {
      outcomePrices = rawPrices
          .map((e) => double.tryParse(e.toString()) ?? 0.0)
          .toList();
    }

    final rawTags = json['tags'] as List?;
    final tags =
        rawTags?.map((t) => Tag.fromJson(t as Map<String, dynamic>)).toList() ??
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
      outcomePrices: outcomePrices,
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
    final markets =
        rawMarkets
            ?.map((m) => GammaMarket.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [];

    final rawTags = json['tags'] as List?;
    final tags =
        rawTags?.map((t) => Tag.fromJson(t as Map<String, dynamic>)).toList() ??
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
// GammaSeries
// ---------------------------------------------------------------------------

/// A Polymarket series — a recurring or grouped set of events.
class GammaSeries {
  final String id;
  final String ticker;
  final String slug;
  final String title;
  final String subtitle;
  final String seriesType;
  final String recurrence;
  final String description;
  final String? image;
  final String? icon;
  final String layout;
  final bool active;
  final bool closed;
  final bool archived;
  final bool featured;
  final bool restricted;
  final bool commentsEnabled;
  final double volume24hr;
  final double volume;
  final double liquidity;
  final int score;
  final int commentCount;
  final List<GammaEvent> events;
  final List<Tag> tags;
  final String? startDate;
  final String? createdAt;
  final String? updatedAt;

  const GammaSeries({
    required this.id,
    required this.ticker,
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.seriesType,
    required this.recurrence,
    required this.description,
    required this.layout,
    required this.active,
    required this.closed,
    required this.archived,
    required this.featured,
    required this.restricted,
    required this.commentsEnabled,
    required this.volume24hr,
    required this.volume,
    required this.liquidity,
    required this.score,
    required this.commentCount,
    required this.events,
    required this.tags,
    this.image,
    this.icon,
    this.startDate,
    this.createdAt,
    this.updatedAt,
  });

  factory GammaSeries.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'] as List?;
    final events =
        rawEvents
            ?.map((e) => GammaEvent.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final rawTags = json['tags'] as List?;
    final tags =
        rawTags?.map((t) => Tag.fromJson(t as Map<String, dynamic>)).toList() ??
        [];

    return GammaSeries(
      id: json['id']?.toString() ?? '',
      ticker: json['ticker'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      seriesType: json['seriesType'] as String? ?? '',
      recurrence: json['recurrence'] as String? ?? '',
      description: json['description'] as String? ?? '',
      image: json['image'] as String?,
      icon: json['icon'] as String?,
      layout: json['layout'] as String? ?? '',
      active: json['active'] as bool? ?? false,
      closed: json['closed'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      featured: json['featured'] as bool? ?? false,
      restricted: json['restricted'] as bool? ?? false,
      commentsEnabled: json['commentsEnabled'] as bool? ?? false,
      volume24hr: _toDouble(json['volume24hr']),
      volume: _toDouble(json['volume']),
      liquidity: _toDouble(json['liquidity']),
      score: _parseInt(json['score']),
      commentCount: _parseInt(json['commentCount']),
      events: events,
      tags: tags,
      startDate: json['startDate'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  @override
  String toString() => 'GammaSeries(id: $id, title: $title, active: $active)';
}

// ---------------------------------------------------------------------------
// GammaComment
// ---------------------------------------------------------------------------

/// A comment on a Gamma entity such as an event, series, or market.
class GammaComment {
  final String id;
  final String body;
  final String parentEntityType;
  final int parentEntityId;
  final String parentCommentId;
  final String userAddress;
  final String replyAddress;
  final String? createdAt;
  final String? updatedAt;
  final GammaCommentProfile? profile;
  final List<GammaCommentReaction> reactions;
  final int reportCount;
  final int reactionCount;

  const GammaComment({
    required this.id,
    required this.body,
    required this.parentEntityType,
    required this.parentEntityId,
    required this.parentCommentId,
    required this.userAddress,
    required this.replyAddress,
    required this.reactions,
    required this.reportCount,
    required this.reactionCount,
    this.createdAt,
    this.updatedAt,
    this.profile,
  });

  factory GammaComment.fromJson(Map<String, dynamic> json) {
    final rawReactions = json['reactions'] as List?;
    final reactions =
        rawReactions
            ?.map(
              (r) => GammaCommentReaction.fromJson(r as Map<String, dynamic>),
            )
            .toList() ??
        [];

    return GammaComment(
      id: json['id']?.toString() ?? '',
      body: json['body'] as String? ?? '',
      parentEntityType: json['parentEntityType'] as String? ?? '',
      parentEntityId: _parseInt(json['parentEntityID']),
      parentCommentId: json['parentCommentID']?.toString() ?? '',
      userAddress: json['userAddress'] as String? ?? '',
      replyAddress: json['replyAddress'] as String? ?? '',
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      profile: json['profile'] is Map<String, dynamic>
          ? GammaCommentProfile.fromJson(
              json['profile'] as Map<String, dynamic>,
            )
          : null,
      reactions: reactions,
      reportCount: _parseInt(json['reportCount']),
      reactionCount: _parseInt(json['reactionCount']),
    );
  }
}

/// Profile metadata attached to a Gamma comment or reaction.
class GammaCommentProfile {
  final String name;
  final String pseudonym;
  final bool displayUsernamePublic;
  final String bio;
  final bool isMod;
  final bool isCreator;
  final String proxyWallet;
  final String baseAddress;
  final String profileImage;
  final List<GammaCommentPosition> positions;

  const GammaCommentProfile({
    required this.name,
    required this.pseudonym,
    required this.displayUsernamePublic,
    required this.bio,
    required this.isMod,
    required this.isCreator,
    required this.proxyWallet,
    required this.baseAddress,
    required this.profileImage,
    required this.positions,
  });

  factory GammaCommentProfile.fromJson(Map<String, dynamic> json) {
    final rawPositions = json['positions'] as List?;
    final positions =
        rawPositions
            ?.map(
              (p) => GammaCommentPosition.fromJson(p as Map<String, dynamic>),
            )
            .toList() ??
        [];

    return GammaCommentProfile(
      name: json['name'] as String? ?? '',
      pseudonym: json['pseudonym'] as String? ?? '',
      displayUsernamePublic: json['displayUsernamePublic'] as bool? ?? false,
      bio: json['bio'] as String? ?? '',
      isMod: json['isMod'] as bool? ?? false,
      isCreator: json['isCreator'] as bool? ?? false,
      proxyWallet: json['proxyWallet'] as String? ?? '',
      baseAddress: json['baseAddress'] as String? ?? '',
      profileImage: json['profileImage'] as String? ?? '',
      positions: positions,
    );
  }
}

/// A user position summary included with comment profile metadata.
class GammaCommentPosition {
  final String tokenId;
  final String positionSize;

  const GammaCommentPosition({
    required this.tokenId,
    required this.positionSize,
  });

  factory GammaCommentPosition.fromJson(Map<String, dynamic> json) {
    return GammaCommentPosition(
      tokenId: json['tokenId']?.toString() ?? '',
      positionSize: json['positionSize']?.toString() ?? '',
    );
  }
}

/// A reaction attached to a Gamma comment.
class GammaCommentReaction {
  final String id;
  final int commentId;
  final String reactionType;
  final String icon;
  final String userAddress;
  final String? createdAt;
  final GammaCommentProfile? profile;

  const GammaCommentReaction({
    required this.id,
    required this.commentId,
    required this.reactionType,
    required this.icon,
    required this.userAddress,
    this.createdAt,
    this.profile,
  });

  factory GammaCommentReaction.fromJson(Map<String, dynamic> json) {
    return GammaCommentReaction(
      id: json['id']?.toString() ?? '',
      commentId: _parseInt(json['commentID']),
      reactionType: json['reactionType'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      userAddress: json['userAddress'] as String? ?? '',
      createdAt: json['createdAt'] as String?,
      profile: json['profile'] is Map<String, dynamic>
          ? GammaCommentProfile.fromJson(
              json['profile'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Sports
// ---------------------------------------------------------------------------

/// Sports metadata configuration returned by [GammaClient.getSportsMetadata].
class SportsMetadata {
  final int id;
  final String sport;
  final String image;
  final String resolution;
  final String ordering;
  final String tags;
  final String series;
  final String? createdAt;

  const SportsMetadata({
    required this.id,
    required this.sport,
    required this.image,
    required this.resolution,
    required this.ordering,
    required this.tags,
    required this.series,
    this.createdAt,
  });

  factory SportsMetadata.fromJson(Map<String, dynamic> json) {
    return SportsMetadata(
      id: _parseInt(json['id']),
      sport: json['sport'] as String? ?? '',
      image: json['image'] as String? ?? '',
      resolution: json['resolution'] as String? ?? '',
      ordering: json['ordering'] as String? ?? '',
      tags: json['tags']?.toString() ?? '',
      series: json['series']?.toString() ?? '',
      createdAt: json['createdAt'] as String?,
    );
  }

  /// Tag IDs parsed from the comma-separated [tags] field.
  List<int> get tagIds => tags
      .split(',')
      .where((e) => e.trim().isNotEmpty)
      .map((e) => int.tryParse(e.trim()) ?? 0)
      .where((e) => e != 0)
      .toList();
}

/// A sports team returned by [GammaClient.getTeams].
class SportsTeam {
  final int id;
  final String? name;
  final String? league;
  final String? record;
  final String? logo;
  final String? abbreviation;
  final String? alias;
  final int? providerId;
  final String? color;
  final String? createdAt;
  final String? updatedAt;

  const SportsTeam({
    required this.id,
    this.name,
    this.league,
    this.record,
    this.logo,
    this.abbreviation,
    this.alias,
    this.providerId,
    this.color,
    this.createdAt,
    this.updatedAt,
  });

  factory SportsTeam.fromJson(Map<String, dynamic> json) {
    final providerId = json['providerId'];
    return SportsTeam(
      id: _parseInt(json['id']),
      name: json['name'] as String?,
      league: json['league'] as String?,
      record: json['record'] as String?,
      logo: json['logo'] as String?,
      abbreviation: json['abbreviation'] as String?,
      alias: json['alias'] as String?,
      providerId: providerId == null ? null : _parseInt(providerId),
      color: json['color'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
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
