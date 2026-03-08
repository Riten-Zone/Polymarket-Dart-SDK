/// Polymarket Data API client — user positions and proxy wallet lookup.
library;

import '../models/data_types.dart';
import '../transport/http_transport.dart';
import '../utils/constants.dart';

/// Client for the Polymarket Data API (`https://data-api.polymarket.com`).
///
/// All methods are public — no authentication required.
///
/// ```dart
/// final data = DataClient();
///
/// // Get all holdings for an EOA
/// final positions = await data.getPositions('0xYourEOAAddress');
///
/// // Get the Polymarket Safe proxy wallet for an EOA
/// final proxy = await data.getProxyWallet('0xYourEOAAddress');
/// print(proxy); // 0xProxyWalletAddress
/// ```
class DataClient {
  final HttpTransport _transport;

  DataClient({HttpTransport? transport})
      : _transport = transport ?? HttpTransport();

  /// Returns all active positions held by [userAddress].
  ///
  /// [userAddress] can be the EOA **or** the Polymarket proxy wallet — the API
  /// accepts both. Each [Position] includes a [Position.proxyWallet] field
  /// identifying the Safe proxy deployed by Polymarket for that EOA.
  ///
  /// Set [sizeThreshold] to filter out dust positions (default 0 = show all).
  Future<List<Position>> getPositions(
    String userAddress, {
    double sizeThreshold = 0,
  }) async {
    final params = <String, String>{
      'user': userAddress,
      'sizeThreshold': sizeThreshold.toString(),
    };

    final response = await _transport.get(
      PolymarketUrls.data,
      '/positions',
      queryParams: params,
    );

    if (response == null) return [];
    final list = response as List<dynamic>;
    return list
        .map((j) => Position.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Returns the Polymarket Safe proxy wallet address associated with [eoaAddress].
  ///
  /// Polymarket deploys a Gnosis Safe proxy for every user on first login.
  /// Orders on the CLOB are placed from this proxy (not the EOA directly).
  ///
  /// Internally calls [getPositions] and extracts [Position.proxyWallet] from
  /// the first result. Returns `null` if the EOA has never held any positions.
  Future<String?> getProxyWallet(String eoaAddress) async {
    final positions = await getPositions(eoaAddress);
    if (positions.isEmpty) return null;
    return positions.first.proxyWallet;
  }

  // ---------------------------------------------------------------------------
  // Trades
  // ---------------------------------------------------------------------------

  /// Returns completed trades for [userAddress].
  ///
  /// [limit] — max number of results.
  /// [offset] — number of results to skip (for pagination).
  Future<List<UserTrade>> getTrades(
    String userAddress, {
    int? limit,
    int? offset,
  }) async {
    final params = <String, String>{'user': userAddress};
    if (limit != null) params['limit'] = limit.toString();
    if (offset != null) params['offset'] = offset.toString();

    final response = await _transport.get(
      PolymarketUrls.data,
      '/trades',
      queryParams: params,
    );

    if (response == null) return [];
    final list = response as List<dynamic>;
    return list
        .map((j) => UserTrade.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Activity
  // ---------------------------------------------------------------------------

  /// Returns activity events for [userAddress] (trades, redemptions, etc.).
  ///
  /// [limit] — max number of results.
  Future<List<Activity>> getActivity(
    String userAddress, {
    int? limit,
  }) async {
    final params = <String, String>{'user': userAddress};
    if (limit != null) params['limit'] = limit.toString();

    final response = await _transport.get(
      PolymarketUrls.data,
      '/activity',
      queryParams: params,
    );

    if (response == null) return [];
    final list = response as List<dynamic>;
    return list
        .map((j) => Activity.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Holders
  // ---------------------------------------------------------------------------

  /// Returns holders of the outcome token for the market identified by [conditionId].
  ///
  /// [conditionId] — the CTF condition ID (0x-prefixed hex). Passed to the API
  /// as the `market` query parameter.
  /// [limit] — max number of results.
  Future<List<Holder>> getHolders(
    String conditionId, {
    int? limit,
  }) async {
    final params = <String, String>{'market': conditionId};
    if (limit != null) params['limit'] = limit.toString();

    final response = await _transport.get(
      PolymarketUrls.data,
      '/holders',
      queryParams: params,
    );

    if (response == null) return [];
    final list = response as List<dynamic>;
    return list
        .map((j) => Holder.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Closes the underlying HTTP client.
  void close() => _transport.close();
}
