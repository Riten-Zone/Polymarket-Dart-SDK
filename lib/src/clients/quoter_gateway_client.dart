/// Polymarket Quoter Gateway WebSocket client for market makers.
///
/// Market makers connect to the RFQ gateway, authenticate once, then receive
/// live RFQ requests and (when Last Look is enabled) confirmation requests,
/// responding with signed quotes, cancels, and confirmations over the same
/// socket.
///
/// ```dart
/// final gateway = QuoterGatewayClient(
///   credentials: creds, // CLOB L2 credentials
///   identity: const QuoterIdentity(
///     signerAddress: '0x...',
///     makerAddress: '0x...',
///     signatureType: 0,
///   ),
/// );
///
/// gateway.rfqRequests.listen((req) async {
///   // build + sign an order for req, then:
///   gateway.submitQuote(
///     rfqId: req.rfqId,
///     priceE6: '550000',
///     sizeE6: '50000000',
///     signedOrder: signedOrder,
///   );
/// });
///
/// await gateway.connect();
/// ```
///
/// The gateway sends protocol-level ping frames with payload `rfq` every 30
/// seconds; `web_socket_channel` answers them with matching pong frames
/// automatically, so no application-level heartbeat is needed here.
library;

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/clob_types.dart';
import '../models/combo_types.dart';
import '../utils/constants.dart';

/// The maker identity presented to the gateway during authentication.
class QuoterIdentity {
  final String signerAddress;
  final String makerAddress;

  /// Signature type of the maker wallet (0–3).
  final int signatureType;

  const QuoterIdentity({
    required this.signerAddress,
    required this.makerAddress,
    required this.signatureType,
  });

  Map<String, dynamic> toJson() => {
        'signer_address': signerAddress,
        'maker_address': makerAddress,
        'signature_type': signatureType,
      };
}

/// Result of the gateway authentication handshake.
class QuoterAuthResult {
  final bool success;
  final String? address;
  final String? role;
  final String? error;

  const QuoterAuthResult({
    required this.success,
    this.address,
    this.role,
    this.error,
  });

  factory QuoterAuthResult.fromJson(Map<String, dynamic> json) =>
      QuoterAuthResult(
        success: json['success'] as bool? ?? false,
        address: json['address'] as String?,
        role: json['role'] as String?,
        error: json['error'] as String?,
      );
}

/// WebSocket client for the Polymarket Quoter Gateway (`/ws/rfq`).
class QuoterGatewayClient {
  final String url;
  final ApiCredentials _credentials;
  final QuoterIdentity _identity;
  final Duration authTimeout;

  /// Injected channel factory (for testing). Defaults to a live connection.
  final WebSocketChannel Function(Uri url)? _connect;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Completer<QuoterAuthResult>? _authCompleter;

  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _rfqRequests = StreamController<RfqRequestEvent>.broadcast();
  final _confirmationRequests =
      StreamController<RfqConfirmationRequestEvent>.broadcast();

  QuoterGatewayClient({
    required ApiCredentials credentials,
    required QuoterIdentity identity,
    String? url,
    this.authTimeout = const Duration(seconds: 30),
    WebSocketChannel Function(Uri url)? connect,
  })  : _credentials = credentials,
        _identity = identity,
        url = url ?? PolymarketUrls.quoterGatewayWs,
        _connect = connect;

  /// All parsed JSON messages received from the gateway.
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  /// Inbound RFQ requests (server asks the quoter to price a combo).
  Stream<RfqRequestEvent> get rfqRequests => _rfqRequests.stream;

  /// Inbound Last Look confirmation requests.
  Stream<RfqConfirmationRequestEvent> get confirmationRequests =>
      _confirmationRequests.stream;

  /// Whether the socket is currently open.
  bool get isConnected => _channel != null;

  /// Connect and authenticate. Completes with the gateway's auth result, or
  /// throws [TimeoutException] if no auth response arrives within [authTimeout].
  Future<QuoterAuthResult> connect() async {
    if (_channel != null) {
      throw StateError('QuoterGatewayClient is already connected');
    }
    final channel = _connect != null
        ? _connect(Uri.parse(url))
        : WebSocketChannel.connect(Uri.parse(url));
    _channel = channel;
    await channel.ready;

    _authCompleter = Completer<QuoterAuthResult>();
    _sub = channel.stream.listen(
      _onMessage,
      onError: _onError,
      onDone: _onDone,
    );

    // Send the auth handshake.
    _send({
      'type': 'auth',
      'auth': {
        'apiKey': _credentials.apiKey,
        'secret': _credentials.secret,
        'passphrase': _credentials.passphrase,
      },
      'identity': _identity.toJson(),
    });

    return _authCompleter!.future.timeout(
      authTimeout,
      onTimeout: () => throw TimeoutException(
        'Quoter gateway auth timed out after ${authTimeout.inSeconds}s',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Outbound (quoter → server)
  // ---------------------------------------------------------------------------

  /// Submit a signed quote in response to an [RfqRequestEvent].
  void submitQuote({
    required String rfqId,
    required String priceE6,
    required String sizeE6,
    required SignedRfqOrder signedOrder,
  }) {
    _send({
      'type': 'RFQ_QUOTE',
      'rfq_id': rfqId,
      'price_e6': priceE6,
      'size_e6': sizeE6,
      'signed_order': signedOrder.toJson(),
    });
  }

  /// Cancel a previously submitted quote.
  void cancelQuote({
    required String rfqId,
    required String quoteId,
    String? signerAddress,
    String? makerAddress,
  }) {
    _send({
      'type': 'RFQ_QUOTE_CANCEL',
      'rfq_id': rfqId,
      'quote_id': quoteId,
      'signer_address': signerAddress ?? _identity.signerAddress,
      'maker_address': makerAddress ?? _identity.makerAddress,
    });
  }

  /// Respond to a Last Look [RfqConfirmationRequestEvent].
  void sendConfirmation({
    required String rfqId,
    required String quoteId,
    required LastLookDecision decision,
  }) {
    _send({
      'type': 'RFQ_CONFIRMATION_RESPONSE',
      'rfq_id': rfqId,
      'quote_id': quoteId,
      'decision': decision.toJson(),
    });
  }

  /// Close the socket and release all stream controllers.
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    if (_authCompleter != null && !_authCompleter!.isCompleted) {
      _authCompleter!.completeError(
        StateError('QuoterGatewayClient disposed before authentication'),
      );
    }
    await _messages.close();
    await _rfqRequests.close();
    await _confirmationRequests.close();
  }

  // ---------------------------------------------------------------------------
  // Inbound routing
  // ---------------------------------------------------------------------------

  void _onMessage(dynamic data) {
    if (data is! String) return;
    final Map<String, dynamic> msg;
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) return;
      msg = decoded;
    } catch (_) {
      return; // ignore non-JSON frames
    }

    if (!_messages.isClosed) _messages.add(msg);

    switch (msg['type']) {
      case 'auth':
        final result = QuoterAuthResult.fromJson(msg);
        if (_authCompleter != null && !_authCompleter!.isCompleted) {
          _authCompleter!.complete(result);
        }
        break;
      case 'RFQ_REQUEST':
        if (!_rfqRequests.isClosed) {
          _rfqRequests.add(RfqRequestEvent.fromJson(msg));
        }
        break;
      case 'RFQ_CONFIRMATION_REQUEST':
        if (!_confirmationRequests.isClosed) {
          _confirmationRequests
              .add(RfqConfirmationRequestEvent.fromJson(msg));
        }
        break;
      // ACK_* messages surface on [messages] for callers that track them.
    }
  }

  void _onError(Object error) {
    if (_authCompleter != null && !_authCompleter!.isCompleted) {
      _authCompleter!.completeError(error);
    }
  }

  void _onDone() {
    _channel = null;
  }

  void _send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) {
      throw StateError('QuoterGatewayClient is not connected');
    }
    channel.sink.add(jsonEncode(message));
  }
}
