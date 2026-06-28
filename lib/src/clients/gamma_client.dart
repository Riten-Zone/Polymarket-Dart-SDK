/// Polymarket Gamma API client — market and event discovery.
library;

import '../models/gamma_types.dart';
import '../transport/http_transport.dart';
import '../utils/constants.dart';

/// Client for the Polymarket Gamma API (`https://gamma-api.polymarket.com`).
///
/// All methods are public — no authentication required.
///
/// ```dart
/// final gamma = GammaClient();
///
/// // Browse active markets sorted by 24h volume
/// final markets = await gamma.getMarkets(
///   active: true,
///   closed: false,
///   order: 'volume24hr',
///   ascending: false,
///   limit: 20,
/// );
///
/// // Get all tags
/// final tags = await gamma.getTags();
///
/// // Search
/// final results = await gamma.searchMarkets('election');
/// ```
class GammaClient {
  final HttpTransport _transport;

  GammaClient({HttpTransport? transport})
    : _transport = transport ?? HttpTransport();

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  /// Returns a list of Polymarket events.
  ///
  /// [nextCursor] — opaque pagination cursor from a previous call.
  /// [active] — filter to active-only events.
  /// [order] — field to sort by (e.g. `"startDate"`, `"endDate"`).
  /// [ascending] — sort direction (`"true"` / `"false"`).
  /// [limit] — max number of results.
  Future<List<GammaEvent>> getEvents({
    String? nextCursor,
    bool? active,
    String? order,
    bool? ascending,
    int? limit,
  }) async {
    final params = <String, String>{};
    if (nextCursor != null) params['next_cursor'] = nextCursor;
    if (active != null) params['active'] = active.toString();
    if (order != null) params['order'] = order;
    if (ascending != null) params['ascending'] = ascending.toString();
    if (limit != null) params['limit'] = limit.toString();

    final response = await _transport.get(
      PolymarketUrls.gamma,
      '/events',
      queryParams: params.isEmpty ? null : params,
    );

    if (response == null) return [];
    final list = response as List<dynamic>;
    return list
        .map((j) => GammaEvent.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Returns the event identified by [eventId].
  Future<GammaEvent> getEvent(int eventId) async {
    final response =
        await _transport.get(PolymarketUrls.gamma, '/events/$eventId')
            as Map<String, dynamic>;
    return GammaEvent.fromJson(response);
  }

  // ---------------------------------------------------------------------------
  // Series
  // ---------------------------------------------------------------------------

  /// Returns a list of Polymarket series.
  ///
  /// [slugs], [categoryIds], and [categoryLabels] are sent as comma-separated
  /// values to match the Gamma API's documented array query filters.
  Future<List<GammaSeries>> getSeries({
    int? limit,
    int? offset,
    String? order,
    bool? ascending,
    List<String>? slugs,
    List<int>? categoryIds,
    List<String>? categoryLabels,
    bool? closed,
    bool? includeChat,
    String? recurrence,
    bool? excludeEvents,
  }) async {
    final params = <String, String>{};
    if (limit != null) params['limit'] = limit.toString();
    if (offset != null) params['offset'] = offset.toString();
    if (order != null) params['order'] = order;
    if (ascending != null) params['ascending'] = ascending.toString();
    if (slugs != null && slugs.isNotEmpty) params['slug'] = slugs.join(',');
    if (categoryIds != null && categoryIds.isNotEmpty) {
      params['categories_ids'] = categoryIds.join(',');
    }
    if (categoryLabels != null && categoryLabels.isNotEmpty) {
      params['categories_labels'] = categoryLabels.join(',');
    }
    if (closed != null) params['closed'] = closed.toString();
    if (includeChat != null) params['include_chat'] = includeChat.toString();
    if (recurrence != null) params['recurrence'] = recurrence;
    if (excludeEvents != null) {
      params['exclude_events'] = excludeEvents.toString();
    }

    final response = await _transport.get(
      PolymarketUrls.gamma,
      '/series',
      queryParams: params.isEmpty ? null : params,
    );

    if (response == null) return [];
    final list = response as List<dynamic>;
    return list
        .map((j) => GammaSeries.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Returns a single series by its [id].
  Future<GammaSeries> getSeriesById(String id) async {
    final response =
        await _transport.get(PolymarketUrls.gamma, '/series/$id')
            as Map<String, dynamic>;
    return GammaSeries.fromJson(response);
  }

  // ---------------------------------------------------------------------------
  // Markets
  // ---------------------------------------------------------------------------

  /// Returns a list of Polymarket markets.
  ///
  /// [nextCursor] — opaque pagination cursor.
  /// [active] — filter to currently active markets.
  /// [closed] — include closed/resolved markets.
  /// [order] — sort field (e.g. `"volume24hr"`, `"liquidity"`, `"endDate"`).
  /// [ascending] — sort direction.
  /// [limit] — max number of results (default 100, max 500).
  Future<List<GammaMarket>> getMarkets({
    String? nextCursor,
    bool? active,
    bool? closed,
    String? order,
    bool? ascending,
    int? limit,
  }) async {
    final params = <String, String>{};
    if (nextCursor != null) params['next_cursor'] = nextCursor;
    if (active != null) params['active'] = active.toString();
    if (closed != null) params['closed'] = closed.toString();
    if (order != null) params['order'] = order;
    if (ascending != null) params['ascending'] = ascending.toString();
    if (limit != null) params['limit'] = limit.toString();

    final response = await _transport.get(
      PolymarketUrls.gamma,
      '/markets',
      queryParams: params.isEmpty ? null : params,
    );

    if (response == null) return [];
    final list = response as List<dynamic>;
    return list
        .map((j) => GammaMarket.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Returns a single market by its numeric [id].
  ///
  /// The numeric [id] is the [GammaMarket.id] field returned by [getMarkets].
  /// Note: the Gamma API does NOT accept conditionId or slug as path parameters —
  /// only the numeric integer ID works.
  Future<GammaMarket> getMarket(int id) async {
    final response =
        await _transport.get(PolymarketUrls.gamma, '/markets/$id')
            as Map<String, dynamic>;
    return GammaMarket.fromJson(response);
  }

  // ---------------------------------------------------------------------------
  // Tags
  // ---------------------------------------------------------------------------

  /// Returns all available market category tags.
  Future<List<Tag>> getTags() async {
    final response = await _transport.get(PolymarketUrls.gamma, '/tags');

    if (response == null) return [];
    final list = response as List<dynamic>;
    return list.map((j) => Tag.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Returns a single tag by numeric [id].
  Future<Tag> getTag(int id, {bool? includeTemplate}) async {
    final params = <String, String>{};
    if (includeTemplate != null) {
      params['include_template'] = includeTemplate.toString();
    }

    final response =
        await _transport.get(
              PolymarketUrls.gamma,
              '/tags/$id',
              queryParams: params.isEmpty ? null : params,
            )
            as Map<String, dynamic>;
    return Tag.fromJson(response);
  }

  /// Returns a single tag by URL [slug].
  Future<Tag> getTagBySlug(String slug, {bool? includeTemplate}) async {
    final params = <String, String>{};
    if (includeTemplate != null) {
      params['include_template'] = includeTemplate.toString();
    }

    final encodedSlug = Uri.encodeComponent(slug);
    final response =
        await _transport.get(
              PolymarketUrls.gamma,
              '/tags/slug/$encodedSlug',
              queryParams: params.isEmpty ? null : params,
            )
            as Map<String, dynamic>;
    return Tag.fromJson(response);
  }

  /// Returns raw related-tag relationship rows for tag [id].
  Future<List<RelatedTag>> getRelatedTagsById(
    int id, {
    bool? omitEmpty,
    String? status,
  }) async {
    final params = _relatedTagParams(omitEmpty: omitEmpty, status: status);
    final response = await _transport.get(
      PolymarketUrls.gamma,
      '/tags/$id/related-tags',
      queryParams: params.isEmpty ? null : params,
    );

    if (response == null) return [];
    final list = response as List<dynamic>;
    return list
        .map((j) => RelatedTag.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Returns raw related-tag relationship rows for tag [slug].
  Future<List<RelatedTag>> getRelatedTagsBySlug(
    String slug, {
    bool? omitEmpty,
    String? status,
  }) async {
    final params = _relatedTagParams(omitEmpty: omitEmpty, status: status);
    final encodedSlug = Uri.encodeComponent(slug);
    final response = await _transport.get(
      PolymarketUrls.gamma,
      '/tags/slug/$encodedSlug/related-tags',
      queryParams: params.isEmpty ? null : params,
    );

    if (response == null) return [];
    final list = response as List<dynamic>;
    return list
        .map((j) => RelatedTag.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Returns full related tag objects for tag [id].
  Future<List<Tag>> getTagsRelatedToTagById(
    int id, {
    bool? omitEmpty,
    String? status,
  }) async {
    final params = _relatedTagParams(omitEmpty: omitEmpty, status: status);
    final response = await _transport.get(
      PolymarketUrls.gamma,
      '/tags/$id/related-tags/tags',
      queryParams: params.isEmpty ? null : params,
    );

    if (response == null) return [];
    final list = response as List<dynamic>;
    return list.map((j) => Tag.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Returns full related tag objects for tag [slug].
  Future<List<Tag>> getTagsRelatedToTagBySlug(
    String slug, {
    bool? omitEmpty,
    String? status,
  }) async {
    final params = _relatedTagParams(omitEmpty: omitEmpty, status: status);
    final encodedSlug = Uri.encodeComponent(slug);
    final response = await _transport.get(
      PolymarketUrls.gamma,
      '/tags/slug/$encodedSlug/related-tags/tags',
      queryParams: params.isEmpty ? null : params,
    );

    if (response == null) return [];
    final list = response as List<dynamic>;
    return list.map((j) => Tag.fromJson(j as Map<String, dynamic>)).toList();
  }

  Map<String, String> _relatedTagParams({bool? omitEmpty, String? status}) {
    final params = <String, String>{};
    if (omitEmpty != null) params['omit_empty'] = omitEmpty.toString();
    if (status != null) params['status'] = status;
    return params;
  }

  // ---------------------------------------------------------------------------
  // Sports
  // ---------------------------------------------------------------------------

  /// Returns sports metadata configuration from `/sports`.
  Future<List<SportsMetadata>> getSportsMetadata() async {
    final response = await _transport.get(PolymarketUrls.gamma, '/sports');

    if (response == null) return [];
    final list = response as List<dynamic>;
    return list
        .map((j) => SportsMetadata.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Returns all valid sports market type identifiers.
  Future<List<String>> getSportsMarketTypes() async {
    final response =
        await _transport.get(PolymarketUrls.gamma, '/sports/market-types')
            as Map<String, dynamic>;

    final list = response['marketTypes'] as List<dynamic>? ?? [];
    return list.map((e) => e.toString()).toList();
  }

  /// Returns teams from `/teams`.
  ///
  /// [leagues], [names], and [abbreviations] are sent as comma-separated
  /// values to match the Gamma API's documented array query filters.
  Future<List<SportsTeam>> getTeams({
    int? limit,
    int? offset,
    String? order,
    bool? ascending,
    List<String>? leagues,
    List<String>? names,
    List<String>? abbreviations,
  }) async {
    final params = <String, String>{};
    if (limit != null) params['limit'] = limit.toString();
    if (offset != null) params['offset'] = offset.toString();
    if (order != null) params['order'] = order;
    if (ascending != null) params['ascending'] = ascending.toString();
    if (leagues != null && leagues.isNotEmpty) {
      params['league'] = leagues.join(',');
    }
    if (names != null && names.isNotEmpty) params['name'] = names.join(',');
    if (abbreviations != null && abbreviations.isNotEmpty) {
      params['abbreviation'] = abbreviations.join(',');
    }

    final response = await _transport.get(
      PolymarketUrls.gamma,
      '/teams',
      queryParams: params.isEmpty ? null : params,
    );

    if (response == null) return [];
    final list = response as List<dynamic>;
    return list
        .map((j) => SportsTeam.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Comments
  // ---------------------------------------------------------------------------

  /// Returns comments for a parent entity.
  ///
  /// The Gamma API documents [parentEntityType] as `Event`, `Series`, or
  /// `market`. In practice, the API rejects unscoped `/comments` requests, so
  /// callers should provide both [parentEntityType] and [parentEntityId].
  Future<List<GammaComment>> getComments({
    int? limit,
    int? offset,
    String? order,
    bool? ascending,
    String? parentEntityType,
    int? parentEntityId,
    bool? getPositions,
    bool? holdersOnly,
  }) async {
    final params = <String, String>{};
    if (limit != null) params['limit'] = limit.toString();
    if (offset != null) params['offset'] = offset.toString();
    if (order != null) params['order'] = order;
    if (ascending != null) params['ascending'] = ascending.toString();
    if (parentEntityType != null) {
      params['parent_entity_type'] = parentEntityType;
    }
    if (parentEntityId != null) {
      params['parent_entity_id'] = parentEntityId.toString();
    }
    if (getPositions != null) params['get_positions'] = getPositions.toString();
    if (holdersOnly != null) params['holders_only'] = holdersOnly.toString();

    final response = await _transport.get(
      PolymarketUrls.gamma,
      '/comments',
      queryParams: params.isEmpty ? null : params,
    );

    if (response == null) return [];
    final list = response as List<dynamic>;
    return list
        .map((j) => GammaComment.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Returns replies/children for a comment [id].
  Future<List<GammaComment>> getCommentsById(String id) async {
    final response = await _transport.get(
      PolymarketUrls.gamma,
      '/comments/$id',
    );

    if (response == null) return [];
    final list = response as List<dynamic>;
    return list
        .map((j) => GammaComment.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Returns comments made by [userAddress].
  Future<List<GammaComment>> getCommentsByUserAddress(
    String userAddress,
  ) async {
    final response = await _transport.get(
      PolymarketUrls.gamma,
      '/comments/user_address/$userAddress',
    );

    if (response == null) return [];
    final list = response as List<dynamic>;
    return list
        .map((j) => GammaComment.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// Searches markets by [query] text.
  ///
  /// Returns markets whose question or description matches the query.
  Future<List<GammaMarket>> searchMarkets(String query) async {
    final response = await _transport.get(
      PolymarketUrls.gamma,
      '/markets',
      queryParams: {'q': query},
    );

    if (response == null) return [];
    final list = response as List<dynamic>;
    return list
        .map((j) => GammaMarket.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Searches public markets, events, tags, and profiles via `/public-search`.
  ///
  /// This is the current unified Gamma search endpoint. Market matches are
  /// returned inside [GammaSearchResult.events] as nested event markets.
  Future<GammaSearchResult> publicSearch(
    String query, {
    bool? cache,
    String? eventsStatus,
    int? limitPerType,
    int? page,
    List<String>? eventTags,
    int? keepClosedMarkets,
    String? sort,
    bool? ascending,
    bool? searchTags,
    bool? searchProfiles,
    String? recurrence,
    List<int>? excludeTagIds,
    bool? optimized,
  }) async {
    final params = <String, String>{'q': query};
    if (cache != null) params['cache'] = cache.toString();
    if (eventsStatus != null) params['events_status'] = eventsStatus;
    if (limitPerType != null) {
      params['limit_per_type'] = limitPerType.toString();
    }
    if (page != null) params['page'] = page.toString();
    if (eventTags != null && eventTags.isNotEmpty) {
      params['events_tag'] = eventTags.join(',');
    }
    if (keepClosedMarkets != null) {
      params['keep_closed_markets'] = keepClosedMarkets.toString();
    }
    if (sort != null) params['sort'] = sort;
    if (ascending != null) params['ascending'] = ascending.toString();
    if (searchTags != null) params['search_tags'] = searchTags.toString();
    if (searchProfiles != null) {
      params['search_profiles'] = searchProfiles.toString();
    }
    if (recurrence != null) params['recurrence'] = recurrence;
    if (excludeTagIds != null && excludeTagIds.isNotEmpty) {
      params['exclude_tag_id'] = excludeTagIds.join(',');
    }
    if (optimized != null) params['optimized'] = optimized.toString();

    final response =
        await _transport.get(
              PolymarketUrls.gamma,
              '/public-search',
              queryParams: params,
            )
            as Map<String, dynamic>;
    return GammaSearchResult.fromJson(response);
  }

  /// Closes the underlying HTTP client.
  void close() => _transport.close();
}
