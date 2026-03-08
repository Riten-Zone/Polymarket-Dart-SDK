/// Polymarket CLOB API client.
///
/// Covers all three authentication levels:
/// - Level 0: public endpoints (no auth required)
/// - Level 1: EIP-712 signed requests (API key management)
/// - Level 2: HMAC-SHA256 signed requests (order management, account data)
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'package:pointycastle/digests/keccak.dart';

import '../models/clob_types.dart';
import '../signing/builder_auth.dart';
import '../signing/eip712.dart';
import '../signing/hmac_auth.dart';
import '../signing/wallet_adapter.dart';
import '../transport/http_transport.dart';
import '../utils/constants.dart';

/// Client for the Polymarket Central Limit Order Book (CLOB) API.
///
/// Usage:
/// ```dart
/// // Level 0 — public data, no wallet needed
/// final client = ClobClient();
/// final markets = await client.getMarkets();
///
/// // Level 1 + 2 — trading, needs a wallet
/// final wallet = PrivateKeyWalletAdapter('0xYourPrivateKey');
/// final client = ClobClient(wallet: wallet);
/// final creds = await client.createOrDeriveApiKey();
/// client.setCredentials(creds);
/// final order = await client.createOrder(OrderArgs(...));
/// await client.postOrder(order);
/// ```
class ClobClient {
  final HttpTransport _transport;
  final WalletAdapter? _wallet;
  ApiCredentials? _credentials;
  HmacAuth? _hmac;
  final BuilderCredentials? _builderCredentials;

  ClobClient({
    WalletAdapter? wallet,
    ApiCredentials? credentials,
    BuilderCredentials? builderCredentials,
    HttpTransport? transport,
  })  : _wallet = wallet,
        _builderCredentials = builderCredentials,
        _transport = transport ?? HttpTransport() {
    if (credentials != null) {
      setCredentials(credentials);
    }
  }

  /// Set or update the API credentials for Level 2 auth.
  void setCredentials(ApiCredentials creds) {
    _credentials = creds;
    _hmac = HmacAuth(
      apiKey: creds.apiKey,
      secret: creds.secret,
      passphrase: creds.passphrase,
    );
  }

  /// Close the underlying HTTP client.
  void close() => _transport.close();

  // ---------------------------------------------------------------------------
  // Level 0: Health & server time
  // ---------------------------------------------------------------------------

  /// Check if the CLOB API is alive.
  Future<bool> getOk() async {
    final res = await _transport.get(PolymarketUrls.clob, '/');
    return res != null;
  }

  /// Get the server's current unix timestamp in seconds.
  Future<int> getServerTime() async {
    final res = await _transport.get(PolymarketUrls.clob, '/time');
    // API returns a raw integer, not a JSON object
    if (res is int) return res;
    return (res as Map<String, dynamic>)['time'] as int;
  }

  // ---------------------------------------------------------------------------
  // Level 0: Markets
  // ---------------------------------------------------------------------------

  /// List markets with optional pagination.
  Future<MarketsPage> getMarkets({String? nextCursor}) async {
    final params = <String, String>{};
    if (nextCursor != null) params['next_cursor'] = nextCursor;
    final res = await _transport.get(
      PolymarketUrls.clob,
      '/markets',
      queryParams: params.isEmpty ? null : params,
    ) as Map<String, dynamic>;
    return MarketsPage.fromJson(res);
  }

  /// Get a single market by its condition ID.
  Future<Market> getMarket(String conditionId) async {
    final res = await _transport.get(
      PolymarketUrls.clob,
      '/markets/$conditionId',
    ) as Map<String, dynamic>;
    return Market.fromJson(res);
  }

  /// List sampling markets (subset used for rewards computation).
  Future<MarketsPage> getSamplingMarkets({String? nextCursor}) async {
    final params = <String, String>{};
    if (nextCursor != null) params['next_cursor'] = nextCursor;
    final res = await _transport.get(
      PolymarketUrls.clob,
      '/sampling-markets',
      queryParams: params.isEmpty ? null : params,
    ) as Map<String, dynamic>;
    return MarketsPage.fromJson(res);
  }

  /// Get simplified market data (lighter payload).
  Future<MarketsPage> getSimplifiedMarkets({String? nextCursor}) async {
    final params = <String, String>{};
    if (nextCursor != null) params['next_cursor'] = nextCursor;
    final res = await _transport.get(
      PolymarketUrls.clob,
      '/simplified-markets',
      queryParams: params.isEmpty ? null : params,
    ) as Map<String, dynamic>;
    return MarketsPage.fromJson(res);
  }

  /// Get sampling simplified markets (lighter payload, subset for rewards).
  Future<MarketsPage> getSamplingSimplifiedMarkets({String? nextCursor}) async {
    final params = <String, String>{};
    if (nextCursor != null) params['next_cursor'] = nextCursor;
    final res = await _transport.get(
      PolymarketUrls.clob,
      '/sampling-simplified-markets',
      queryParams: params.isEmpty ? null : params,
    ) as Map<String, dynamic>;
    return MarketsPage.fromJson(res);
  }

  /// Get recent trade events for a market.
  Future<List<MarketTradeEvent>> getMarketTradesEvents(
      String conditionId) async {
    final res = await _transport.get(
      PolymarketUrls.clob,
      '/live-activity/events/$conditionId',
    );
    final list = res as List;
    return list
        .map((e) => MarketTradeEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Level 0: Orderbook
  // ---------------------------------------------------------------------------

  /// Get the full orderbook for a token.
  Future<OrderBookSummary> getOrderBook(String tokenId) async {
    final res = await _transport.get(
      PolymarketUrls.clob,
      '/book',
      queryParams: {'token_id': tokenId},
    ) as Map<String, dynamic>;
    return OrderBookSummary.fromJson(res);
  }

  /// Get orderbooks for multiple tokens.
  Future<List<OrderBookSummary>> getOrderBooks(
      List<BookParams> params) async {
    final res = await _transport.post(
      PolymarketUrls.clob,
      '/books',
      body: params.map((p) => p.toJson()).toList(),
    ) as List;
    return res
        .map((e) => OrderBookSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Calculates the server-compatible SHA-1 hash for an orderbook snapshot.
  ///
  /// The hash is computed over a compact JSON payload with a specific key order,
  /// matching the Go server implementation. The `hash` field is set to empty
  /// while hashing.
  String getOrderBookHash(OrderBookSummary orderbook) {
    final payload = {
      'market': orderbook.market,
      'asset_id': orderbook.asset,
      'timestamp': orderbook.timestamp?.toString() ?? '',
      'hash': '',
      'bids': orderbook.bids
          .map((o) => {'price': o.price, 'size': o.size})
          .toList(),
      'asks': orderbook.asks
          .map((o) => {'price': o.price, 'size': o.size})
          .toList(),
    };
    final serialized = jsonEncode(payload);
    final bytes = utf8.encode(serialized);
    return crypto.sha1.convert(bytes).toString();
  }

  // ---------------------------------------------------------------------------
  // Level 0: Pricing
  // ---------------------------------------------------------------------------

  /// Get the mid-price for a token.
  Future<String> getMidpoint(String tokenId) async {
    final res = await _transport.get(
      PolymarketUrls.clob,
      '/midpoint',
      queryParams: {'token_id': tokenId},
    ) as Map<String, dynamic>;
    return res['mid'].toString();
  }

  /// Get mid-prices for multiple tokens.
  Future<Map<String, String>> getMidpoints(List<BookParams> params) async {
    final res = await _transport.post(
      PolymarketUrls.clob,
      '/midpoints',
      body: params.map((p) => p.toJson()).toList(),
    ) as Map<String, dynamic>;
    return res.map((k, v) => MapEntry(k, v.toString()));
  }

  /// Get the best price for a token on a given side.
  Future<String> getPrice(String tokenId, String side) async {
    final res = await _transport.get(
      PolymarketUrls.clob,
      '/price',
      queryParams: {'token_id': tokenId, 'side': side},
    ) as Map<String, dynamic>;
    return res['price'].toString();
  }

  /// Get prices for multiple token+side combos.
  Future<Map<String, String>> getPrices(List<BookParams> params) async {
    final res = await _transport.post(
      PolymarketUrls.clob,
      '/prices',
      body: params.map((p) => p.toJson()).toList(),
    ) as Map<String, dynamic>;
    return res.map((k, v) => MapEntry(k, v.toString()));
  }

  /// Get the spread for a token.
  Future<String> getSpread(String tokenId) async {
    final res = await _transport.get(
      PolymarketUrls.clob,
      '/spread',
      queryParams: {'token_id': tokenId},
    ) as Map<String, dynamic>;
    return res['spread'].toString();
  }

  /// Get spreads for multiple tokens.
  Future<Map<String, String>> getSpreads(List<BookParams> params) async {
    final res = await _transport.post(
      PolymarketUrls.clob,
      '/spreads',
      body: params.map((p) => p.toJson()).toList(),
    ) as Map<String, dynamic>;
    return res.map((k, v) => MapEntry(k, v.toString()));
  }

  /// Get the last trade price for a token.
  Future<String> getLastTradePrice(String tokenId) async {
    final res = await _transport.get(
      PolymarketUrls.clob,
      '/last-trade-price',
      queryParams: {'token_id': tokenId},
    ) as Map<String, dynamic>;
    return res['price'].toString();
  }

  /// Get last trade prices for multiple tokens.
  Future<List<LastTradePrice>> getLastTradesPrices(
      List<BookParams> params) async {
    final res = await _transport.post(
      PolymarketUrls.clob,
      '/last-trades-prices',
      body: params.map((p) => p.toJson()).toList(),
    ) as List;
    return res
        .map((e) => LastTradePrice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Level 0: Market configuration
  // ---------------------------------------------------------------------------

  /// Get the tick size for a token (e.g. "0.01").
  Future<String> getTickSize(String tokenId) async {
    final res = await _transport.get(
      PolymarketUrls.clob,
      '/tick-size',
      queryParams: {'token_id': tokenId},
    ) as Map<String, dynamic>;
    return res['minimum_tick_size'].toString();
  }

  /// Whether a token is a neg-risk market.
  Future<bool> getNegRisk(String tokenId) async {
    final res = await _transport.get(
      PolymarketUrls.clob,
      '/neg-risk',
      queryParams: {'token_id': tokenId},
    ) as Map<String, dynamic>;
    return res['neg_risk'] as bool? ?? false;
  }

  /// Get the fee rate (in basis points) for a token.
  Future<int> getFeeRateBps(String tokenId) async {
    final res = await _transport.get(
      PolymarketUrls.clob,
      '/fee-rate',
      queryParams: {'token_id': tokenId},
    ) as Map<String, dynamic>;
    return (res['base_fee'] as num).toInt();
  }

  // ---------------------------------------------------------------------------
  // Level 0: Price history
  // ---------------------------------------------------------------------------

  /// Get price history for a market.
  Future<List<PricePoint>> getPricesHistory(PriceHistoryParams params) async {
    final res = await _transport.get(
      PolymarketUrls.clob,
      '/prices-history',
      queryParams: params.toQueryParams(),
    ) as Map<String, dynamic>;
    final history = res['history'] as List? ?? [];
    return history
        .map((e) => PricePoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Level 0: Market price calculation
  // ---------------------------------------------------------------------------

  /// Calculates the matching price for a market order given the current
  /// orderbook, matching the Python SDK's `calculate_market_price`.
  ///
  /// [tokenId] — the token to trade.
  /// [side] — `'BUY'` or `'SELL'`.
  /// [amount] — the USDC amount (for BUY) or share quantity (for SELL).
  /// [orderType] — the order type; if [OrderType.fok] and the book cannot
  ///   fill the full amount, an exception is thrown.
  ///
  /// Returns the worst price level needed to fill the order.
  Future<double> calculateMarketPrice(
    String tokenId,
    String side,
    double amount,
    OrderType orderType,
  ) async {
    final book = await getOrderBook(tokenId);
    if (side.toUpperCase() == 'BUY') {
      if (book.asks.isEmpty) throw StateError('No asks available for matching');
      return _calculateBuyMarketPrice(book.asks, amount, orderType);
    } else {
      if (book.bids.isEmpty) throw StateError('No bids available for matching');
      return _calculateSellMarketPrice(book.bids, amount, orderType);
    }
  }

  /// Walk asks in reverse to find the price that fills [amountToMatch] USDC.
  double _calculateBuyMarketPrice(
    List<OrderLevel> asks,
    double amountToMatch,
    OrderType orderType,
  ) {
    var sum = 0.0;
    for (final p in asks.reversed) {
      sum += double.parse(p.size) * double.parse(p.price);
      if (sum >= amountToMatch) return double.parse(p.price);
    }
    if (orderType == OrderType.fok) throw StateError('No match for FOK order');
    return double.parse(asks.first.price);
  }

  /// Walk bids in reverse to find the price that fills [amountToMatch] shares.
  double _calculateSellMarketPrice(
    List<OrderLevel> bids,
    double amountToMatch,
    OrderType orderType,
  ) {
    var sum = 0.0;
    for (final p in bids.reversed) {
      sum += double.parse(p.size);
      if (sum >= amountToMatch) return double.parse(p.price);
    }
    if (orderType == OrderType.fok) throw StateError('No match for FOK order');
    return double.parse(bids.first.price);
  }

  // ---------------------------------------------------------------------------
  // Level 1: API key management
  // ---------------------------------------------------------------------------

  /// Create a new API key for this wallet (Level 1 auth).
  Future<ApiCredentials> createApiKey({int nonce = 0}) async {
    final headers = await _buildLevel1Headers(nonce: nonce);
    final res = await _transport.post(
      PolymarketUrls.clob,
      '/auth/api-key',
      headers: headers,
    ) as Map<String, dynamic>;
    return ApiCredentials.fromJson(res);
  }

  /// Derive an existing API key deterministically from the wallet (Level 1 auth).
  Future<ApiCredentials> deriveApiKey({int nonce = 0}) async {
    final headers = await _buildLevel1Headers(nonce: nonce);
    final res = await _transport.get(
      PolymarketUrls.clob,
      '/auth/derive-api-key',
      headers: headers,
    ) as Map<String, dynamic>;
    return ApiCredentials.fromJson(res);
  }

  /// Create API key if none exists, otherwise derive it (Level 1 auth).
  Future<ApiCredentials> createOrDeriveApiKey({int nonce = 0}) async {
    try {
      return await deriveApiKey(nonce: nonce);
    } catch (_) {
      return await createApiKey(nonce: nonce);
    }
  }

  /// Get all API keys associated with this wallet (Level 2 auth).
  Future<ApiKeysResponse> getApiKeys() async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    final headers = _buildLevel2Headers(
      method: 'GET',
      path: '/auth/api-keys',
      walletAddress: address,
    );
    final res = await _transport.get(
      PolymarketUrls.clob,
      '/auth/api-keys',
      headers: headers,
    );
    return ApiKeysResponse.fromJson(res);
  }

  /// Delete the current API key (Level 2 auth).
  Future<void> deleteApiKey() async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    final headers = _buildLevel2Headers(
      method: 'DELETE',
      path: '/auth/api-key',
      walletAddress: address,
    );
    await _transport.delete(
      PolymarketUrls.clob,
      '/auth/api-key',
      headers: headers,
    );
  }

  // ---------------------------------------------------------------------------
  // Level 2: Order building
  // ---------------------------------------------------------------------------

  /// Build and sign a limit order.
  ///
  /// Does NOT submit it — call [postOrder] after this.
  Future<SignedOrder> createOrder(
    OrderArgs args, {
    CreateOrderOptions? options,
  }) async {
    _requireWallet();
    final wallet = _wallet!;
    final address = (await wallet.getAddress()).toLowerCase();
    final tickSize = options?.tickSize ?? '0.01';
    final negRisk = options?.negRisk ?? false;
    final funder = options?.funder ?? address;

    final roundConfig = _getRoundConfig(tickSize);
    final sideInt = args.side == OrderSide.buy ? 0 : 1;

    final makerAmount = _calcMakerAmount(
      price: args.price,
      size: args.size,
      side: args.side,
      roundConfig: roundConfig,
    );
    final takerAmount = _calcTakerAmount(
      price: args.price,
      size: args.size,
      side: args.side,
      roundConfig: roundConfig,
    );

    final salt = _generateSalt();
    final nonce = args.nonce ?? '0';
    final expiration = args.expiration ?? '0';
    final taker = args.taker ?? PolymarketChain.zeroAddress;

    final sigType = options?.signatureType ?? 0;

    final typedData = buildOrderTypedData(
      maker: funder,
      signer: address,
      taker: taker,
      tokenId: args.tokenId,
      makerAmount: makerAmount,
      takerAmount: takerAmount,
      expiration: expiration,
      nonce: nonce,
      feeRateBps: args.feeRateBps.toString(),
      side: sideInt,
      signatureType: sigType,
      salt: salt,
      negRisk: negRisk,
    );

    final signature = await wallet.signTypedData(typedData);

    return SignedOrder(
      salt: salt,
      maker: _checksumAddress(funder),
      signer: _checksumAddress(address),
      taker: taker,
      tokenId: args.tokenId,
      makerAmount: makerAmount,
      takerAmount: takerAmount,
      expiration: expiration,
      nonce: nonce,
      feeRateBps: args.feeRateBps.toString(),
      side: sideInt,
      signatureType: sigType,
      signature: signature,
    );
  }

  /// Build and sign a market order (amount-based).
  Future<SignedOrder> createMarketOrder(
    MarketOrderArgs args, {
    CreateOrderOptions? options,
  }) async {
    _requireWallet();
    final wallet = _wallet!;
    final address = (await wallet.getAddress()).toLowerCase();
    final negRisk = options?.negRisk ?? false;
    final funder = options?.funder ?? address;
    final sideInt = args.side == OrderSide.buy ? 0 : 1;

    // For market orders: makerAmount = full amount, takerAmount = 0
    final amountMicro = _toMicro(args.amount, decimals: 2);
    final makerAmount = sideInt == 0 ? amountMicro : amountMicro;
    final takerAmount = '0';

    final salt = _generateSalt();
    final taker = args.taker ?? PolymarketChain.zeroAddress;

    final sigType = options?.signatureType ?? 0;

    final typedData = buildOrderTypedData(
      maker: funder,
      signer: address,
      taker: taker,
      tokenId: args.tokenId,
      makerAmount: makerAmount,
      takerAmount: takerAmount,
      expiration: '0',
      nonce: '0',
      feeRateBps: args.feeRateBps.toString(),
      side: sideInt,
      signatureType: sigType,
      salt: salt,
      negRisk: negRisk,
    );

    final signature = await wallet.signTypedData(typedData);

    return SignedOrder(
      salt: salt,
      maker: _checksumAddress(funder),
      signer: _checksumAddress(address),
      taker: taker,
      tokenId: args.tokenId,
      makerAmount: makerAmount,
      takerAmount: takerAmount,
      expiration: '0',
      nonce: '0',
      feeRateBps: args.feeRateBps.toString(),
      side: sideInt,
      signatureType: sigType,
      signature: signature,
    );
  }

  // ---------------------------------------------------------------------------
  // Level 2: Order submission
  // ---------------------------------------------------------------------------

  /// Post a single signed order.
  Future<PostOrderResponse> postOrder(
    SignedOrder order, {
    String orderType = 'GTC',
    bool postOnly = false,
  }) async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    final body = jsonEncode({
      'order': order.toJson(),
      'owner': _credentials!.apiKey,
      'orderType': orderType,
      'postOnly': postOnly,
    });
    final headers = _buildLevel2Headers(
      method: 'POST',
      path: '/order',
      body: body,
      walletAddress: address,
    );
    final res = await _transport.post(
      PolymarketUrls.clob,
      '/order',
      body: jsonDecode(body),
      headers: headers,
    ) as Map<String, dynamic>;
    return PostOrderResponse.fromJson(res);
  }

  /// Post multiple signed orders in a batch.
  Future<List<PostOrderResponse>> postOrders(
    List<PostOrderArgs> args,
  ) async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    final bodyList = args
        .map((a) => a.toJson(_credentials!.apiKey))
        .toList();
    final body = jsonEncode(bodyList);
    final headers = _buildLevel2Headers(
      method: 'POST',
      path: '/orders',
      body: body,
      walletAddress: address,
    );
    final res = await _transport.post(
      PolymarketUrls.clob,
      '/orders',
      body: jsonDecode(body),
      headers: headers,
    ) as List;
    return res
        .map((e) => PostOrderResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Convenience method: creates, signs, and posts an order in one call.
  ///
  /// Equivalent to calling [createOrder] followed by [postOrder].
  Future<PostOrderResponse> createAndPostOrder(
    OrderArgs args, {
    CreateOrderOptions? options,
    String orderType = 'GTC',
    bool postOnly = false,
  }) async {
    final order = await createOrder(args, options: options);
    return postOrder(order, orderType: orderType, postOnly: postOnly);
  }

  // ---------------------------------------------------------------------------
  // Level 2: Order queries
  // ---------------------------------------------------------------------------

  /// Get a single order by ID.
  Future<OpenOrder> getOrder(String orderId) async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    final path = '/data/order/$orderId';
    final headers = _buildLevel2Headers(
      method: 'GET',
      path: path,
      walletAddress: address,
    );
    final res = await _transport.get(
      PolymarketUrls.clob,
      path,
      headers: headers,
    ) as Map<String, dynamic>;
    return OpenOrder.fromJson(res);
  }

  /// Get all open orders for the current wallet.
  Future<OpenOrdersPage> getOpenOrders({
    OpenOrderParams? params,
    String? nextCursor,
  }) async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    final query = <String, String>{
      'owner': _checksumAddress(address),
      ...?params?.toQueryParams(),
    };
    if (nextCursor != null) query['next_cursor'] = nextCursor;

    // HMAC signs just the bare path — query params are added to the URL only.
    const hmacPath = '/data/orders';
    final headers = _buildLevel2Headers(
      method: 'GET',
      path: hmacPath,
      walletAddress: address,
    );
    final res = await _transport.get(
      PolymarketUrls.clob,
      hmacPath,
      queryParams: query,
      headers: headers,
    ) as Map<String, dynamic>;
    return OpenOrdersPage.fromJson(res);
  }

  // ---------------------------------------------------------------------------
  // Level 2: Order cancellation
  // ---------------------------------------------------------------------------

  /// Cancel a single order by ID.
  Future<void> cancelOrder(String orderId) async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    final body = jsonEncode({'orderID': orderId});
    final headers = _buildLevel2Headers(
      method: 'DELETE',
      path: '/order',
      body: body,
      walletAddress: address,
    );
    await _transport.delete(
      PolymarketUrls.clob,
      '/order',
      body: jsonDecode(body),
      headers: headers,
    );
  }

  /// Cancel multiple orders by their IDs.
  Future<void> cancelOrders(List<String> orderIds) async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    final body = jsonEncode(orderIds.map((id) => {'orderID': id}).toList());
    final headers = _buildLevel2Headers(
      method: 'DELETE',
      path: '/orders',
      body: body,
      walletAddress: address,
    );
    await _transport.delete(
      PolymarketUrls.clob,
      '/orders',
      body: jsonDecode(body),
      headers: headers,
    );
  }

  /// Cancel all open orders for the current wallet.
  Future<void> cancelAll() async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    final headers = _buildLevel2Headers(
      method: 'DELETE',
      path: '/cancel-all',
      walletAddress: address,
    );
    await _transport.delete(
      PolymarketUrls.clob,
      '/cancel-all',
      headers: headers,
    );
  }

  /// Cancel all orders for a specific market or asset.
  Future<void> cancelMarketOrders({String? market, String? assetId}) async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    final bodyMap = <String, String>{};
    if (market != null) bodyMap['market'] = market;
    if (assetId != null) bodyMap['asset_id'] = assetId;
    final body = jsonEncode(bodyMap);
    final headers = _buildLevel2Headers(
      method: 'DELETE',
      path: '/cancel-market-orders',
      body: body,
      walletAddress: address,
    );
    await _transport.delete(
      PolymarketUrls.clob,
      '/cancel-market-orders',
      body: jsonDecode(body),
      headers: headers,
    );
  }

  // ---------------------------------------------------------------------------
  // Level 2: Trade history
  // ---------------------------------------------------------------------------

  /// Get trade history for the current wallet.
  Future<TradesPage> getTrades({
    TradeParams? params,
    String? nextCursor,
  }) async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    final query = <String, String>{
      'maker': _checksumAddress(address),
      ...?params?.toQueryParams(),
    };
    if (nextCursor != null) query['next_cursor'] = nextCursor;

    // HMAC signs just the bare path — query params are added to the URL only.
    const hmacPath = '/data/trades';
    final headers = _buildLevel2Headers(
      method: 'GET',
      path: hmacPath,
      walletAddress: address,
    );
    final res = await _transport.get(
      PolymarketUrls.clob,
      hmacPath,
      queryParams: query,
      headers: headers,
    ) as Map<String, dynamic>;
    return TradesPage.fromJson(res);
  }

  // ---------------------------------------------------------------------------
  // Level 2: Account
  // ---------------------------------------------------------------------------

  /// Get USDC balance and allowance for the current wallet.
  Future<BalanceAllowance> getBalanceAllowance({
    BalanceAllowanceParams? params,
  }) async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    final query = <String, String>{
      'user': _checksumAddress(address),
      'signature_type': '0',
      ...?params?.toQueryParams(),
    };

    // HMAC signs just the bare path — query params are added to the URL only.
    const hmacPath = '/balance-allowance';
    final headers = _buildLevel2Headers(
      method: 'GET',
      path: hmacPath,
      walletAddress: address,
    );
    final res = await _transport.get(
      PolymarketUrls.clob,
      hmacPath,
      queryParams: query,
      headers: headers,
    ) as Map<String, dynamic>;
    return BalanceAllowance.fromJson(res);
  }

  /// Update USDC or conditional token allowance.
  ///
  /// Triggers a Polymarket backend meta-transaction that sets the on-chain
  /// approval (USDC `approve` or CTF `setApprovalForAll`) on behalf of the
  /// user — no on-chain transaction needed from the caller.
  ///
  /// Pass `assetType: 'COLLATERAL'` to approve USDC spending.
  /// Pass `assetType: 'CONDITIONAL'` with a `tokenId` to approve CTF token transfers.
  /// Pass `signatureType: 2` in [params] to update allowances for a Gnosis Safe funder.
  Future<void> updateBalanceAllowance({
    BalanceAllowanceParams? params,
  }) async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    final query = <String, String>{
      'signature_type': '0',
      ...?params?.toQueryParams(),
    };
    // HMAC signs the bare path only — query params go to URL, same as getBalanceAllowance.
    const hmacPath = '/balance-allowance/update';
    final headers = _buildLevel2Headers(
      method: 'GET',
      path: hmacPath,
      walletAddress: address,
    );
    await _transport.get(
      PolymarketUrls.clob,
      hmacPath,
      queryParams: query,
      headers: headers,
    );
  }

  /// Whether the account is in closed-only mode (banned from opening positions).
  Future<BanStatus> getClosedOnlyMode() async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    const path = '/auth/ban-status/closed-only';
    final headers = _buildLevel2Headers(
      method: 'GET',
      path: path,
      walletAddress: address,
    );
    final res = await _transport.get(
      PolymarketUrls.clob,
      path,
      headers: headers,
    ) as Map<String, dynamic>;
    return BanStatus.fromJson(res);
  }

  // ---------------------------------------------------------------------------
  // Level 2: Notifications
  // ---------------------------------------------------------------------------

  /// Get notifications for the current wallet.
  Future<List<Notification>> getNotifications() async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    // HMAC signs just the bare path; signature_type is added to URL only.
    const hmacPath = '/notifications';
    final headers = _buildLevel2Headers(
      method: 'GET',
      path: hmacPath,
      walletAddress: address,
    );
    final res = await _transport.get(
      PolymarketUrls.clob,
      hmacPath,
      queryParams: {'signature_type': '0'},
      headers: headers,
    ) as List;
    return res
        .map((e) => Notification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Drop (dismiss) notifications.
  Future<void> dropNotifications({DropNotificationParams? params}) async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    final path = '/notifications';
    final body = jsonEncode(params?.toJson() ?? {});
    final headers = _buildLevel2Headers(
      method: 'DELETE',
      path: path,
      body: body,
      walletAddress: address,
    );
    await _transport.delete(
      PolymarketUrls.clob,
      path,
      body: jsonDecode(body),
      headers: headers,
    );
  }

  // ---------------------------------------------------------------------------
  // Level 2: Order scoring
  // ---------------------------------------------------------------------------

  /// Check if a specific order is currently scoring rewards.
  Future<OrderScoring> isOrderScoring(String orderId) async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    const hmacPath = '/order-scoring';
    final headers = _buildLevel2Headers(
      method: 'GET',
      path: hmacPath,
      walletAddress: address,
    );
    final res = await _transport.get(
      PolymarketUrls.clob,
      hmacPath,
      queryParams: {'order_id': orderId},
      headers: headers,
    ) as Map<String, dynamic>;
    return OrderScoring.fromJson(res);
  }

  /// Check if multiple orders are scoring rewards.
  Future<OrdersScoring> areOrdersScoring(List<String> orderIds) async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    final body = jsonEncode({'order_ids': orderIds});
    final headers = _buildLevel2Headers(
      method: 'POST',
      path: '/orders-scoring',
      body: body,
      walletAddress: address,
    );
    final res = await _transport.post(
      PolymarketUrls.clob,
      '/orders-scoring',
      body: jsonDecode(body),
      headers: headers,
    ) as Map<String, dynamic>;
    return OrdersScoring.fromJson(res);
  }

  // ---------------------------------------------------------------------------
  // Level 2: Heartbeat
  // ---------------------------------------------------------------------------

  /// Post a heartbeat to keep the session alive.
  Future<HeartbeatResponse> postHeartbeat({String? heartbeatId}) async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    // Always include heartbeat_id key (even as null) to match Python SDK body format.
    final bodyMap = <String, dynamic>{'heartbeat_id': heartbeatId};
    final body = jsonEncode(bodyMap);
    final headers = _buildLevel2Headers(
      method: 'POST',
      path: '/v1/heartbeats',
      body: body,
      walletAddress: address,
    );
    final res = await _transport.post(
      PolymarketUrls.clob,
      '/v1/heartbeats',
      body: bodyMap,
      headers: headers,
    ) as Map<String, dynamic>;
    return HeartbeatResponse.fromJson(res);
  }

  // ---------------------------------------------------------------------------
  // Rewards (Level 2 — HMAC required)
  // ---------------------------------------------------------------------------

  /// Returns LP reward earnings for the current wallet on [date] (YYYY-MM-DD).
  ///
  /// Requires Level 2 auth. Calls `GET /rewards/user`.
  Future<Map<String, dynamic>> getEarningsForDay(String date) async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    const path = '/rewards/user';
    final query = {'date': date, 'address': _checksumAddress(address)};
    final headers = _buildLevel2Headers(method: 'GET', path: path, walletAddress: address);
    final res = await _transport.get(PolymarketUrls.clob, path, queryParams: query, headers: headers);
    return res as Map<String, dynamic>;
  }

  /// Returns total LP reward earnings for the current wallet on [date] (YYYY-MM-DD).
  ///
  /// Requires Level 2 auth. Calls `GET /rewards/user/total`.
  Future<Map<String, dynamic>> getTotalEarningsForDay(String date) async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    const path = '/rewards/user/total';
    final query = {'date': date, 'address': _checksumAddress(address)};
    final headers = _buildLevel2Headers(method: 'GET', path: path, walletAddress: address);
    final res = await _transport.get(PolymarketUrls.clob, path, queryParams: query, headers: headers);
    return res as Map<String, dynamic>;
  }

  /// Returns per-user earnings and per-market reward config for [date] (YYYY-MM-DD).
  ///
  /// Requires Level 2 auth. Calls `GET /rewards/user/markets`.
  Future<Map<String, dynamic>> getUserEarningsAndMarketsConfig(String date) async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    const path = '/rewards/user/markets';
    final query = {'date': date, 'address': _checksumAddress(address)};
    final headers = _buildLevel2Headers(method: 'GET', path: path, walletAddress: address);
    final res = await _transport.get(PolymarketUrls.clob, path, queryParams: query, headers: headers);
    return res as Map<String, dynamic>;
  }

  /// Returns LP reward percentage allocations for the current wallet.
  ///
  /// Requires Level 2 auth. Calls `GET /rewards/user/percentages`.
  /// [signatureType] — `0` for EOA (default), `2` for Gnosis Safe.
  Future<Map<String, dynamic>> getRewardPercentages({int signatureType = 0}) async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    const path = '/rewards/user/percentages';
    final query = {'signature_type': signatureType.toString()};
    final headers = _buildLevel2Headers(method: 'GET', path: path, walletAddress: address);
    final res = await _transport.get(PolymarketUrls.clob, path, queryParams: query, headers: headers);
    return res as Map<String, dynamic>;
  }

  /// Returns the current active rewards markets configuration.
  ///
  /// Requires Level 2 auth. Calls `GET /rewards/markets/current`.
  Future<Map<String, dynamic>> getCurrentRewards() async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    const path = '/rewards/markets/current';
    final headers = _buildLevel2Headers(method: 'GET', path: path, walletAddress: address);
    final res = await _transport.get(PolymarketUrls.clob, path, headers: headers);
    return res as Map<String, dynamic>;
  }

  /// Returns rewards data for the market identified by [conditionId].
  ///
  /// Requires Level 2 auth. Calls `GET /rewards/markets/{conditionId}`.
  Future<Map<String, dynamic>> getRawRewardsForMarket(String conditionId) async {
    _requireCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    final path = '/rewards/markets/$conditionId';
    final headers = _buildLevel2Headers(method: 'GET', path: path, walletAddress: address);
    final res = await _transport.get(PolymarketUrls.clob, path, headers: headers);
    return res as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Read-Only API Keys (Level 2 — HMAC required)
  // ---------------------------------------------------------------------------

  /// Creates a new read-only API key for third-party integrations.
  ///
  /// Read-only keys can query account data but cannot place or cancel orders.
  /// Requires [setCredentials] to have been called first.
  Future<ApiCredentials> createReadonlyApiKey() async {
    _requireCredentials();
    final address = await _wallet!.getAddress();
    final headers = _buildLevel2Headers(
      method: 'POST',
      path: '/auth/readonly-api-key',
      walletAddress: address,
    );
    final res = await _transport.post(
      PolymarketUrls.clob,
      '/auth/readonly-api-key',
      headers: headers,
    ) as Map<String, dynamic>;
    return ApiCredentials.fromJson(res);
  }

  /// Returns all read-only API keys associated with the current wallet.
  ///
  /// Requires [setCredentials] to have been called first.
  Future<List<ApiCredentials>> getReadonlyApiKeys() async {
    _requireCredentials();
    final address = await _wallet!.getAddress();
    final headers = _buildLevel2Headers(
      method: 'GET',
      path: '/auth/readonly-api-keys',
      walletAddress: address,
    );
    final res = await _transport.get(
      PolymarketUrls.clob,
      '/auth/readonly-api-keys',
      headers: headers,
    );
    if (res == null) return [];
    final list = res as List<dynamic>;
    return list
        .map((j) => ApiCredentials.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Revokes the read-only API key [apiKey].
  ///
  /// Requires [setCredentials] to have been called first.
  Future<void> deleteReadonlyApiKey(String apiKey) async {
    _requireCredentials();
    final address = await _wallet!.getAddress();
    final bodyMap = {'apiKey': apiKey};
    final headers = _buildLevel2Headers(
      method: 'DELETE',
      path: '/auth/readonly-api-key',
      body: jsonEncode(bodyMap),
      walletAddress: address,
    );
    await _transport.delete(
      PolymarketUrls.clob,
      '/auth/readonly-api-key',
      body: bodyMap,
      headers: headers,
    );
  }

  /// Verifies that [apiKey] is a valid read-only key owned by [address].
  ///
  /// Returns `true` if the key is valid, `false` otherwise.
  Future<bool> validateReadonlyApiKey(String address, String apiKey) async {
    final res = await _transport.get(
      PolymarketUrls.clob,
      '/auth/validate-readonly-api-key',
      queryParams: {
        'address': _checksumAddress(address),
        'apiKey': apiKey,
      },
    );
    if (res == null) return false;
    final map = res as Map<String, dynamic>;
    return map['valid'] as bool? ?? false;
  }

  // ---------------------------------------------------------------------------
  // Builder API (Level 2 + Builder HMAC headers)
  // ---------------------------------------------------------------------------

  /// Returns orders attributed to this builder account.
  ///
  /// Requires [builderCredentials] to have been passed to the constructor.
  Future<List<OpenOrder>> getBuilderOrders({String? market}) async {
    _requireBuilderCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    const hmacPath = '/orders';
    final query = <String, String>{};
    if (market != null) query['market'] = market;
    final headers = {
      ..._buildLevel2Headers(method: 'GET', path: hmacPath, walletAddress: address),
      ...generateBuilderHeaders(creds: _builderCredentials!, method: 'GET', path: hmacPath),
    };
    final res = await _transport.get(
      PolymarketUrls.clob,
      hmacPath,
      queryParams: query.isEmpty ? null : query,
      headers: headers,
    ) as List;
    return res.map((e) => OpenOrder.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Returns open orders attributed to this builder account.
  ///
  /// Requires [builderCredentials] to have been passed to the constructor.
  Future<OpenOrdersPage> getBuilderOpenOrders({
    String? market,
    String? assetId,
  }) async {
    _requireBuilderCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    const hmacPath = '/open-orders';
    final query = <String, String>{};
    if (market != null) query['market'] = market;
    if (assetId != null) query['asset_id'] = assetId;
    final headers = {
      ..._buildLevel2Headers(method: 'GET', path: hmacPath, walletAddress: address),
      ...generateBuilderHeaders(creds: _builderCredentials!, method: 'GET', path: hmacPath),
    };
    final res = await _transport.get(
      PolymarketUrls.clob,
      hmacPath,
      queryParams: query.isEmpty ? null : query,
      headers: headers,
    ) as Map<String, dynamic>;
    return OpenOrdersPage.fromJson(res);
  }

  /// Returns trades routed through this builder account.
  ///
  /// Requires [builderCredentials] to have been passed to the constructor.
  Future<TradesPage> getBuilderTrades({String? market, int? limit}) async {
    _requireBuilderCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    const hmacPath = '/builder/trades';
    final query = <String, String>{};
    if (market != null) query['market'] = market;
    if (limit != null) query['limit'] = limit.toString();
    final headers = {
      ..._buildLevel2Headers(method: 'GET', path: hmacPath, walletAddress: address),
      ...generateBuilderHeaders(creds: _builderCredentials!, method: 'GET', path: hmacPath),
    };
    final res = await _transport.get(
      PolymarketUrls.clob,
      hmacPath,
      queryParams: query.isEmpty ? null : query,
      headers: headers,
    ) as Map<String, dynamic>;
    return TradesPage.fromJson(res);
  }

  /// Revoke the builder API key.
  ///
  /// Requires [builderCredentials] to have been passed to the constructor.
  Future<void> revokeBuilderApiKey() async {
    _requireBuilderCredentials();
    final address = (await _wallet!.getAddress()).toLowerCase();
    const path = '/auth/builder-api-key';
    final headers = {
      ..._buildLevel2Headers(method: 'DELETE', path: path, walletAddress: address),
      ...generateBuilderHeaders(creds: _builderCredentials!, method: 'DELETE', path: path),
    };
    await _transport.delete(PolymarketUrls.clob, path, headers: headers);
  }

  /// Returns the Polymarket builders leaderboard.
  ///
  /// [timePeriod] — one of `'DAY'`, `'WEEK'`, `'MONTH'`, `'ALL'` (default: `'DAY'`).
  /// [limit] — number of results, 1–50 (default: 25).
  /// [offset] — pagination offset, 0–1000 (default: 0).
  Future<List<BuilderLeaderboardEntry>> getBuilderLeaderboard({
    String timePeriod = 'DAY',
    int limit = 25,
    int offset = 0,
  }) async {
    final res = await _transport.get(
      PolymarketUrls.clob,
      '/v1/builders/leaderboard',
      queryParams: {
        'timePeriod': timePeriod,
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );
    if (res == null) return [];
    final list = res as List<dynamic>;
    return list
        .map((e) => BuilderLeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _requireWallet() {
    if (_wallet == null) {
      throw StateError(
          'ClobClient: wallet is required for this operation. '
          'Pass a WalletAdapter when constructing ClobClient.');
    }
  }

  void _requireCredentials() {
    _requireWallet();
    if (_credentials == null || _hmac == null) {
      throw StateError(
          'ClobClient: API credentials required for this operation. '
          'Call createOrDeriveApiKey() and then setCredentials().');
    }
  }

  void _requireBuilderCredentials() {
    _requireCredentials();
    if (_builderCredentials == null) {
      throw StateError(
          'ClobClient: builderCredentials required for builder methods. '
          'Pass BuilderCredentials when constructing ClobClient.');
    }
  }

  /// Build Level 1 (EIP-712) auth headers.
  Future<Map<String, String>> _buildLevel1Headers({int nonce = 0}) async {
    _requireWallet();
    final wallet = _wallet!;
    final address = (await wallet.getAddress()).toLowerCase();
    final timestamp =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final typedData = buildClobAuthTypedData(
      address: address,
      timestamp: timestamp,
      nonce: nonce,
    );
    final signature = await wallet.signTypedData(typedData);
    return {
      'POLY_ADDRESS': address,
      'POLY_SIGNATURE': signature,
      'POLY_TIMESTAMP': timestamp,
      'POLY_NONCE': nonce.toString(),
    };
  }

  /// Build Level 2 (HMAC) auth headers.
  Map<String, String> _buildLevel2Headers({
    required String method,
    required String path,
    String body = '',
    String? walletAddress,
  }) {
    if (_hmac == null) {
      throw StateError('ClobClient: credentials not set. Call setCredentials().');
    }
    return _hmac!.generateHeaders(
      walletAddress: walletAddress ?? '',
      method: method,
      path: path,
      body: body,
    );
  }

  /// Convert an Ethereum address to its EIP-55 checksum form.
  ///
  /// Required for query parameters like `owner` and `maker` — the Polymarket
  /// API normalises these to checksummed form before verifying the HMAC, so
  /// our signed path must use the same casing.
  static String _checksumAddress(String address) {
    final addr = address.toLowerCase().replaceFirst('0x', '');
    final digest = KeccakDigest(256);
    final addrBytes = Uint8List.fromList(utf8.encode(addr));
    final hash = Uint8List(32);
    digest.update(addrBytes, 0, addrBytes.length);
    digest.doFinal(hash, 0);

    final checksummed = StringBuffer('0x');
    for (var i = 0; i < addr.length; i++) {
      final c = addr[i];
      if ('0123456789'.contains(c)) {
        checksummed.write(c);
      } else {
        final nibble =
            i.isEven ? (hash[i ~/ 2] >> 4) & 0xF : hash[i ~/ 2] & 0xF;
        checksummed.write(nibble >= 8 ? c.toUpperCase() : c);
      }
    }
    return checksummed.toString();
  }

  // ---------------------------------------------------------------------------
  // Order amount calculation
  // ---------------------------------------------------------------------------

  /// Returns {price, size, amount} decimal places for a given tick size.
  List<int> _getRoundConfig(String tickSize) {
    switch (tickSize) {
      case '0.1':
        return [1, 2, 3];
      case '0.01':
        return [2, 2, 4];
      case '0.001':
        return [3, 2, 5];
      case '0.0001':
        return [4, 2, 6];
      default:
        return [2, 2, 4];
    }
  }

  String _calcMakerAmount({
    required double price,
    required double size,
    required OrderSide side,
    required List<int> roundConfig,
  }) {
    if (side == OrderSide.buy) {
      // BUY: maker spends USDC → makerAmount = price * size
      final amount = price * size;
      return _toMicro(amount, decimals: roundConfig[2]);
    } else {
      // SELL: maker sells conditional tokens → makerAmount = size
      return _toMicro(size, decimals: roundConfig[1]);
    }
  }

  String _calcTakerAmount({
    required double price,
    required double size,
    required OrderSide side,
    required List<int> roundConfig,
  }) {
    if (side == OrderSide.buy) {
      // BUY: taker receives conditional tokens → takerAmount = size
      return _toMicro(size, decimals: roundConfig[1]);
    } else {
      // SELL: taker pays USDC → takerAmount = price * size
      final amount = price * size;
      return _toMicro(amount, decimals: roundConfig[2]);
    }
  }

  /// Convert a decimal amount to the 6-decimal micro-unit string used by CLOB.
  String _toMicro(double value, {int decimals = 2}) {
    final rounded = double.parse(value.toStringAsFixed(decimals));
    final micro = (rounded * 1e6).round();
    return micro.toString();
  }

  /// Generate a random uint256 salt for order de-duplication.
  String _generateSalt() {
    final rng = Random.secure();
    var salt = BigInt.zero;
    for (var i = 0; i < 32; i++) {
      salt = (salt << 8) | BigInt.from(rng.nextInt(256));
    }
    // Keep it within a reasonable range to avoid overflow
    return (salt % BigInt.from(10).pow(15)).toString();
  }
}
