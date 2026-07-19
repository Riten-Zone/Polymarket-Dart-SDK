/// Polymarket sports WebSocket client — live scores for all active games.
///
/// The feed is unauthenticated and requires no subscribe message: connect and
/// you immediately receive `sport_result` events for every active game. Filter
/// the [results] stream by `gameId` / `slug` / `leagueAbbreviation` as needed.
///
/// ```dart
/// final sports = SportsWebSocketClient();
/// sports.results
///     .where((r) => r.leagueAbbreviation == 'nfl')
///     .listen((r) => print('${r.slug}: ${r.score} (${r.period})'));
/// await sports.connect();
/// ```
///
/// Heartbeat: the server sends the text frame `ping` every 5 seconds; this
/// client replies `pong` automatically (required within 10s or the server
/// closes the connection).
library;

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/websocket_types.dart';
import '../utils/constants.dart';

/// WebSocket client for the Polymarket sports feed (`sports-api/ws`).
class SportsWebSocketClient {
  final String url;

  /// Injected channel factory (for testing). Defaults to a live connection.
  final WebSocketChannel Function(Uri url)? _connect;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  final _results = StreamController<SportResult>.broadcast();

  SportsWebSocketClient({
    String? url,
    WebSocketChannel Function(Uri url)? connect,
  })  : url = url ?? PolymarketUrls.sportsWs,
        _connect = connect;

  /// Live `sport_result` events for every active game.
  Stream<SportResult> get results => _results.stream;

  /// Whether the socket is currently open.
  bool get isConnected => _channel != null;

  /// Connect and start receiving events. No subscribe message is sent.
  Future<void> connect() async {
    if (_channel != null) {
      throw StateError('SportsWebSocketClient is already connected');
    }
    final channel = _connect != null
        ? _connect(Uri.parse(url))
        : WebSocketChannel.connect(Uri.parse(url));
    _channel = channel;
    await channel.ready;
    _sub = channel.stream.listen(
      _onMessage,
      onError: (_) {},
      onDone: () => _channel = null,
    );
  }

  /// Close the socket and release the stream.
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    await _results.close();
  }

  void _onMessage(dynamic data) {
    if (data is! String) return;

    // Heartbeat: reply to the server's text `ping` with `pong`.
    if (data == 'ping') {
      _channel?.sink.add('pong');
      return;
    }

    Map<String, dynamic> msg;
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) return;
      msg = decoded;
    } catch (_) {
      return; // ignore non-JSON frames
    }

    // Emit sport_result events (tolerate messages that omit an explicit type).
    if (msg['type'] == 'sport_result' || msg.containsKey('gameId')) {
      if (!_results.isClosed) _results.add(SportResult.fromJson(msg));
    }
  }
}
