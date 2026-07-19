/// Polymarket WebSocket client — CLOB orderbook/trades + RTDS price streams.
library;

import 'dart:async';

import '../models/clob_types.dart';
import '../models/websocket_types.dart';
import '../transport/websocket_transport.dart';
import '../utils/constants.dart';

/// WebSocket client for Polymarket real-time data.
///
/// Manages two separate connections:
/// - **CLOB** (`wss://ws-subscriptions-clob.polymarket.com/ws/market`):
///   orderbook and trade events.
/// - **RTDS** (`wss://ws-live-data.polymarket.com/ws`):
///   crypto price feeds and comment streams.
///
/// Usage:
/// ```dart
/// final ws = WebSocketClient();
/// await ws.connectClob();
///
/// final sub = ws.subscribeOrderbook('21742633...').listen((update) {
///   print(update.bids.first.price);
/// });
///
/// // later...
/// await sub.cancel();
/// await ws.dispose();
/// ```
class WebSocketClient {
  WebSocketTransport? _clobTransport;
  WebSocketTransport? _rtdsTransport;

  // Subscription tracking to support clean unsubscription
  final Map<String, StreamController<OrderbookUpdate>> _orderbookControllers =
      {};
  final Map<String, StreamController<WsTrade>> _tradeControllers = {};
  final Map<String, StreamController<RtdsPriceUpdate>> _priceControllers = {};
  final Map<String, StreamController<RtdsComment>> _commentControllers = {};

  StreamSubscription<Map<String, dynamic>>? _clobSub;
  StreamSubscription<Map<String, dynamic>>? _rtdsSub;

  // Authenticated user channel
  WebSocketTransport? _userTransport;
  StreamSubscription<Map<String, dynamic>>? _userSub;
  ApiCredentials? _userCredentials;
  StreamController<UserChannelOrder>? _userOrderController;
  StreamController<UserChannelTrade>? _userTradeController;

  // ---------------------------------------------------------------------------
  // CLOB WebSocket
  // ---------------------------------------------------------------------------

  /// Connect to the CLOB WebSocket.
  Future<void> connectClob() async {
    _clobTransport ??= WebSocketTransport(
      url: PolymarketUrls.clobWs,
      pingInterval: const Duration(seconds: 10),
    );
    await _clobTransport!.connect();
    _clobSub ??= _clobTransport!.messages.listen(_onClobMessage);
  }

  /// Subscribe to orderbook updates for a token.
  ///
  /// Connects to CLOB if not already connected.
  /// Returns a broadcast stream of [OrderbookUpdate] events.
  Stream<OrderbookUpdate> subscribeOrderbook(String tokenId) {
    if (_clobTransport == null || !_clobTransport!.isConnected) {
      connectClob();
    }

    if (!_orderbookControllers.containsKey(tokenId)) {
      _orderbookControllers[tokenId] =
          StreamController<OrderbookUpdate>.broadcast(
        onCancel: () => _unsubscribeClob('book', tokenId),
      );
    }

    // CLOB WS protocol: {"assets_ids": [<token_id>], "type": "market"}
    // Both book and trade events come through the same subscription.
    _clobTransport!.send({
      'assets_ids': [tokenId],
      'type': 'market',
    });

    return _orderbookControllers[tokenId]!.stream;
  }

  /// Subscribe to trade events for a token.
  Stream<WsTrade> subscribeTrades(String tokenId) {
    if (_clobTransport == null || !_clobTransport!.isConnected) {
      connectClob();
    }

    if (!_tradeControllers.containsKey(tokenId)) {
      _tradeControllers[tokenId] = StreamController<WsTrade>.broadcast(
        onCancel: () => _unsubscribeClob('trade', tokenId),
      );
    }

    // CLOB WS protocol: same subscription as orderbook — all events per market
    _clobTransport!.send({
      'assets_ids': [tokenId],
      'type': 'market',
    });

    return _tradeControllers[tokenId]!.stream;
  }

  void _onClobMessage(Map<String, dynamic> msg) {
    // CLOB WS messages use event_type + asset_id (TypeScript SDK format)
    final type = msg['event_type']?.toString() ?? '';
    final market = msg['asset_id']?.toString() ?? '';

    if (type == 'book' || type == 'price_change') {
      final ctrl = _orderbookControllers[market];
      if (ctrl != null && !ctrl.isClosed) {
        ctrl.add(OrderbookUpdate.fromJson(msg));
      }
    } else if (type == 'last_trade_price' || type == 'trade') {
      final ctrl = _tradeControllers[market];
      if (ctrl != null && !ctrl.isClosed) {
        ctrl.add(WsTrade.fromJson(msg));
      }
    }
  }

  void _unsubscribeClob(String channel, String tokenId) {
    _clobTransport?.send({
      'action': 'unsubscribe',
      'market': tokenId,
      'channel': channel,
    });
  }

  /// Disconnect the CLOB WebSocket.
  Future<void> disconnectClob() async {
    await _clobSub?.cancel();
    _clobSub = null;
    await _clobTransport?.disconnect();
    _clobTransport = null;
  }

  // ---------------------------------------------------------------------------
  // RTDS WebSocket
  // ---------------------------------------------------------------------------

  /// Connect to the RTDS WebSocket.
  ///
  /// RTDS requires a PING every 5 seconds — this is handled automatically.
  Future<void> connectRtds() async {
    _rtdsTransport ??= WebSocketTransport(
      url: PolymarketUrls.rtdsWs,
      // RTDS requires PING every 5 seconds (stricter than CLOB's 30s)
      pingInterval: const Duration(seconds: 5),
    );
    await _rtdsTransport!.connect();
    _rtdsSub ??= _rtdsTransport!.messages.listen(_onRtdsMessage);
  }

  /// Subscribe to real-time crypto prices from RTDS.
  ///
  /// [assets] can include: 'BTC', 'ETH', 'SOL', 'XRP'.
  /// Connects to RTDS if not already connected.
  Stream<RtdsPriceUpdate> subscribePrices(List<String> assets) {
    if (_rtdsTransport == null || !_rtdsTransport!.isConnected) {
      connectRtds();
    }

    final key = assets.join(',');
    if (!_priceControllers.containsKey(key)) {
      _priceControllers[key] =
          StreamController<RtdsPriceUpdate>.broadcast(
        onCancel: () => _unsubscribeRtds('prices', assets),
      );
    }

    _rtdsTransport!.send({
      'action': 'subscribe',
      'type': 'prices',
      'assets': assets,
    });

    return _priceControllers[key]!.stream;
  }

  /// Subscribe to comments for a specific market.
  Stream<RtdsComment> subscribeComments(String marketId) {
    if (_rtdsTransport == null || !_rtdsTransport!.isConnected) {
      connectRtds();
    }

    if (!_commentControllers.containsKey(marketId)) {
      _commentControllers[marketId] =
          StreamController<RtdsComment>.broadcast(
        onCancel: () => _unsubscribeRtds('comments', [marketId]),
      );
    }

    _rtdsTransport!.send({
      'action': 'subscribe',
      'type': 'comments',
      'market_id': marketId,
    });

    return _commentControllers[marketId]!.stream;
  }

  void _onRtdsMessage(Map<String, dynamic> msg) {
    final type = msg['type']?.toString() ?? '';

    if (type == 'prices' || type == 'price') {
      final update = RtdsPriceUpdate.fromJson(msg);
      for (final ctrl in _priceControllers.values) {
        if (!ctrl.isClosed) ctrl.add(update);
      }
    } else if (type == 'comment') {
      final comment = RtdsComment.fromJson(msg);
      final ctrl = _commentControllers[comment.marketId];
      if (ctrl != null && !ctrl.isClosed) {
        ctrl.add(comment);
      }
    }
  }

  void _unsubscribeRtds(String type, List<String> targets) {
    _rtdsTransport?.send({
      'action': 'unsubscribe',
      'type': type,
      if (type == 'prices') 'assets': targets,
      if (type == 'comments' && targets.isNotEmpty)
        'market_id': targets.first,
    });
  }

  /// Disconnect the RTDS WebSocket.
  Future<void> disconnectRtds() async {
    await _rtdsSub?.cancel();
    _rtdsSub = null;
    await _rtdsTransport?.disconnect();
    _rtdsTransport = null;
  }

  // ---------------------------------------------------------------------------
  // CLOB user channel (authenticated)
  // ---------------------------------------------------------------------------

  /// Connect to the authenticated CLOB user channel.
  ///
  /// [credentials] are your Level 2 CLOB API credentials. They are sent in the
  /// subscribe message, so only use the user channel from server environments.
  Future<void> connectUser({required ApiCredentials credentials}) async {
    _userCredentials = credentials;
    _userTransport ??= WebSocketTransport(
      url: PolymarketUrls.clobUserWs,
      pingInterval: const Duration(seconds: 10),
    );
    await _userTransport!.connect();
    _userSub ??= _userTransport!.messages.listen(_onUserMessage);
  }

  /// Subscribe to the user's order updates for the given [markets]
  /// (condition ids). Connects with [connectUser] first if needed.
  ///
  /// Returns a broadcast stream of [UserChannelOrder] events.
  Stream<UserChannelOrder> subscribeUserChannelOrders(List<String> markets) {
    _ensureUserSubscribed(markets);
    _userOrderController ??= StreamController<UserChannelOrder>.broadcast();
    return _userOrderController!.stream;
  }

  /// Subscribe to the user's trade updates for the given [markets]
  /// (condition ids). Connects with [connectUser] first if needed.
  ///
  /// Returns a broadcast stream of [UserChannelTrade] events.
  Stream<UserChannelTrade> subscribeUserChannelTrades(List<String> markets) {
    _ensureUserSubscribed(markets);
    _userTradeController ??= StreamController<UserChannelTrade>.broadcast();
    return _userTradeController!.stream;
  }

  void _ensureUserSubscribed(List<String> markets) {
    final creds = _userCredentials;
    if (creds == null) {
      throw StateError(
        'User channel requires credentials — call connectUser(credentials: ...) first.',
      );
    }
    if (_userTransport == null || !_userTransport!.isConnected) {
      connectUser(credentials: creds);
    }
    // User channel subscribe: {auth, markets: [condition_ids], type: "user"}.
    _userTransport!.send({
      'auth': {
        'apiKey': creds.apiKey,
        'secret': creds.secret,
        'passphrase': creds.passphrase,
      },
      'markets': markets,
      'type': 'user',
    });
  }

  void _onUserMessage(Map<String, dynamic> msg) {
    final type = (msg['event_type'] ?? msg['type'])?.toString() ?? '';
    if (type == 'trade') {
      final ctrl = _userTradeController;
      if (ctrl != null && !ctrl.isClosed) ctrl.add(UserChannelTrade.fromJson(msg));
    } else if (type == 'order' ||
        type == 'PLACEMENT' ||
        type == 'UPDATE' ||
        type == 'CANCELLATION') {
      final ctrl = _userOrderController;
      if (ctrl != null && !ctrl.isClosed) ctrl.add(UserChannelOrder.fromJson(msg));
    }
  }

  /// Disconnect the authenticated user channel.
  Future<void> disconnectUser() async {
    await _userSub?.cancel();
    _userSub = null;
    await _userTransport?.disconnect();
    _userTransport = null;
  }

  /// Whether the user channel is connected.
  bool get isUserConnected => _userTransport?.isConnected ?? false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Whether the CLOB WebSocket is connected.
  bool get isClobConnected => _clobTransport?.isConnected ?? false;

  /// Whether the RTDS WebSocket is connected.
  bool get isRtdsConnected => _rtdsTransport?.isConnected ?? false;

  /// Connection state stream for the CLOB WebSocket.
  Stream<WsConnectionState>? get clobStateChanges =>
      _clobTransport?.stateChanges;

  /// Connection state stream for the RTDS WebSocket.
  Stream<WsConnectionState>? get rtdsStateChanges =>
      _rtdsTransport?.stateChanges;

  /// Dispose all connections and stream controllers.
  Future<void> dispose() async {
    await disconnectClob();
    await disconnectRtds();
    await disconnectUser();
    await _userOrderController?.close();
    await _userTradeController?.close();
    _userOrderController = null;
    _userTradeController = null;

    for (final ctrl in _orderbookControllers.values) {
      await ctrl.close();
    }
    for (final ctrl in _tradeControllers.values) {
      await ctrl.close();
    }
    for (final ctrl in _priceControllers.values) {
      await ctrl.close();
    }
    for (final ctrl in _commentControllers.values) {
      await ctrl.close();
    }

    _orderbookControllers.clear();
    _tradeControllers.clear();
    _priceControllers.clear();
    _commentControllers.clear();
  }
}
