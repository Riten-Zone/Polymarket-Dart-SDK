/// Polymarket RFQ (Request for Quote) API client.
///
/// RFQ is a market-maker system: requesters post buy/sell requests,
/// quoters (liquidity providers) respond with competing quotes, and
/// both sides accept/approve to execute the trade.
///
/// All methods require Level 2 (HMAC) authentication.
///
/// ```dart
/// final wallet = PrivateKeyWalletAdapter('0x...');
/// final client = ClobClient(wallet: wallet);
/// final creds = await client.createOrDeriveApiKey();
/// client.setCredentials(creds);
///
/// final rfq = RfqClient(wallet: wallet, credentials: creds);
///
/// // As a requester: post a buy request
/// final req = await rfq.createRequest(RfqUserRequest(
///   tokenId: '0x...',
///   side: 'BUY',
///   price: 0.55,
///   size: 50.0,
/// ));
/// print('Request ID: ${req.requestId}');
///
/// // As a quoter: browse open requests and respond
/// final requests = await rfq.getRequests(
///   GetRfqRequestsParams(state: 'active', limit: 10),
/// );
/// ```
library;

import 'dart:convert';

import '../models/clob_types.dart';
import '../models/rfq_types.dart';
import '../signing/hmac_auth.dart';
import '../signing/wallet_adapter.dart';
import '../transport/http_transport.dart';
import '../utils/constants.dart';

/// Client for the Polymarket RFQ API (`https://clob.polymarket.com/rfq/...`).
///
/// All methods require Level 2 HMAC authentication.
class RfqClient {
  final HttpTransport _transport;
  final WalletAdapter _wallet;
  final HmacAuth _hmac;

  RfqClient({
    required WalletAdapter wallet,
    required ApiCredentials credentials,
    HttpTransport? transport,
  })  : _wallet = wallet,
        _hmac = HmacAuth(
          apiKey: credentials.apiKey,
          secret: credentials.secret,
          passphrase: credentials.passphrase,
        ),
        _transport = transport ?? HttpTransport();

  // ---------------------------------------------------------------------------
  // Request side
  // ---------------------------------------------------------------------------

  /// Create a new RFQ request (requester posts a desired trade).
  ///
  /// The API will match quoters whose offers meet the request parameters.
  Future<RfqRequestResponse> createRequest(RfqUserRequest request) async {
    final address = await _walletAddress();
    const path = '/rfq/request';
    final body = jsonEncode(request.toJson());
    final headers = _l2Headers(method: 'POST', path: path, body: body, address: address);
    final res = await _transport.post(
      PolymarketUrls.clob,
      path,
      body: jsonDecode(body),
      headers: headers,
    ) as Map<String, dynamic>;
    return RfqRequestResponse.fromJson(res);
  }

  /// Cancel an existing RFQ request.
  Future<void> cancelRequest(CancelRfqRequestParams params) async {
    final address = await _walletAddress();
    const path = '/rfq/request';
    final body = jsonEncode(params.toJson());
    final headers = _l2Headers(method: 'DELETE', path: path, body: body, address: address);
    await _transport.delete(
      PolymarketUrls.clob,
      path,
      body: jsonDecode(body),
      headers: headers,
    );
  }

  /// Accept a quote (requester side — locks in the selected quote).
  Future<void> acceptQuote(AcceptQuoteParams params) async {
    final address = await _walletAddress();
    const path = '/rfq/request/accept';
    final body = jsonEncode(params.toJson());
    final headers = _l2Headers(method: 'POST', path: path, body: body, address: address);
    await _transport.post(
      PolymarketUrls.clob,
      path,
      body: jsonDecode(body),
      headers: headers,
    );
  }

  // ---------------------------------------------------------------------------
  // Quote side
  // ---------------------------------------------------------------------------

  /// Create a new RFQ quote (quoter responds to an open request).
  Future<RfqQuoteResponse> createQuote(RfqUserQuote quote) async {
    final address = await _walletAddress();
    const path = '/rfq/quote';
    final body = jsonEncode(quote.toJson());
    final headers = _l2Headers(method: 'POST', path: path, body: body, address: address);
    final res = await _transport.post(
      PolymarketUrls.clob,
      path,
      body: jsonDecode(body),
      headers: headers,
    ) as Map<String, dynamic>;
    return RfqQuoteResponse.fromJson(res);
  }

  /// Cancel an existing RFQ quote.
  Future<void> cancelQuote(CancelRfqQuoteParams params) async {
    final address = await _walletAddress();
    const path = '/rfq/quote';
    final body = jsonEncode(params.toJson());
    final headers = _l2Headers(method: 'DELETE', path: path, body: body, address: address);
    await _transport.delete(
      PolymarketUrls.clob,
      path,
      body: jsonDecode(body),
      headers: headers,
    );
  }

  /// Approve an order (quoter side — finalises trade execution).
  Future<void> approveOrder(ApproveOrderParams params) async {
    final address = await _walletAddress();
    const path = '/rfq/quote/approve';
    final body = jsonEncode(params.toJson());
    final headers = _l2Headers(method: 'POST', path: path, body: body, address: address);
    await _transport.post(
      PolymarketUrls.clob,
      path,
      body: jsonDecode(body),
      headers: headers,
    );
  }

  // ---------------------------------------------------------------------------
  // Data queries
  // ---------------------------------------------------------------------------

  /// List RFQ requests with optional filters.
  Future<RfqPaginatedResponse<RfqRequest>> getRequests([
    GetRfqRequestsParams? params,
  ]) async {
    final address = await _walletAddress();
    const hmacPath = '/rfq/data/requests';
    final headers = _l2Headers(method: 'GET', path: hmacPath, address: address);
    final res = await _transport.get(
      PolymarketUrls.clob,
      hmacPath,
      queryParams: params?.toQueryParams(),
      headers: headers,
    ) as Map<String, dynamic>;
    return RfqPaginatedResponse.fromJson(res, RfqRequest.fromJson);
  }

  /// List quotes received on the authenticated requester's open requests.
  Future<RfqPaginatedResponse<RfqQuote>> getRequesterQuotes([
    GetRfqQuotesParams? params,
  ]) async {
    final address = await _walletAddress();
    const hmacPath = '/rfq/data/requester/quotes';
    final headers = _l2Headers(method: 'GET', path: hmacPath, address: address);
    final res = await _transport.get(
      PolymarketUrls.clob,
      hmacPath,
      queryParams: params?.toQueryParams(),
      headers: headers,
    ) as Map<String, dynamic>;
    return RfqPaginatedResponse.fromJson(res, RfqQuote.fromJson);
  }

  /// List quotes created by the authenticated quoter.
  Future<RfqPaginatedResponse<RfqQuote>> getQuoterQuotes([
    GetRfqQuotesParams? params,
  ]) async {
    final address = await _walletAddress();
    const hmacPath = '/rfq/data/quoter/quotes';
    final headers = _l2Headers(method: 'GET', path: hmacPath, address: address);
    final res = await _transport.get(
      PolymarketUrls.clob,
      hmacPath,
      queryParams: params?.toQueryParams(),
      headers: headers,
    ) as Map<String, dynamic>;
    return RfqPaginatedResponse.fromJson(res, RfqQuote.fromJson);
  }

  /// Get the best available quote for an open request.
  Future<RfqQuote> getBestQuote(GetRfqBestQuoteParams params) async {
    final address = await _walletAddress();
    const hmacPath = '/rfq/data/best-quote';
    final headers = _l2Headers(method: 'GET', path: hmacPath, address: address);
    final res = await _transport.get(
      PolymarketUrls.clob,
      hmacPath,
      queryParams: params.toQueryParams(),
      headers: headers,
    ) as Map<String, dynamic>;
    return RfqQuote.fromJson(res);
  }

  /// Get global RFQ configuration parameters.
  Future<Map<String, dynamic>> getConfig() async {
    final address = await _walletAddress();
    const hmacPath = '/rfq/config';
    final headers = _l2Headers(method: 'GET', path: hmacPath, address: address);
    final res = await _transport.get(
      PolymarketUrls.clob,
      hmacPath,
      headers: headers,
    );
    return res as Map<String, dynamic>? ?? {};
  }

  /// Close the underlying HTTP client.
  void close() => _transport.close();

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<String> _walletAddress() async =>
      (await _wallet.getAddress()).toLowerCase();

  Map<String, String> _l2Headers({
    required String method,
    required String path,
    required String address,
    String body = '',
  }) =>
      _hmac.generateHeaders(
        walletAddress: address,
        method: method,
        path: path,
        body: body,
      );
}
