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
    final response = await _transport.get(
      PolymarketUrls.gamma,
      '/events/$eventId',
    ) as Map<String, dynamic>;
    return GammaEvent.fromJson(response);
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
    final response = await _transport.get(
      PolymarketUrls.gamma,
      '/markets/$id',
    ) as Map<String, dynamic>;
    return GammaMarket.fromJson(response);
  }

  // ---------------------------------------------------------------------------
  // Tags
  // ---------------------------------------------------------------------------

  /// Returns all available market category tags.
  Future<List<Tag>> getTags() async {
    final response = await _transport.get(
      PolymarketUrls.gamma,
      '/tags',
    );

    if (response == null) return [];
    final list = response as List<dynamic>;
    return list.map((j) => Tag.fromJson(j as Map<String, dynamic>)).toList();
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

  /// Closes the underlying HTTP client.
  void close() => _transport.close();
}
