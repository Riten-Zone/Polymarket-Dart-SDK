/// Offline tests for QuoterGatewayClient — the RFQ gateway WebSocket. Injects
/// a fake WebSocketChannel so auth handshake, inbound routing, and outbound
/// message construction can be verified with no network.
library;

import 'dart:async';
import 'dart:convert';

import 'package:polymarket_dart/polymarket_dart.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const _creds = ApiCredentials(
  apiKey: 'test-api-key',
  secret: 'c2VjcmV0LXNlY3JldA==',
  passphrase: 'test-pass',
);

const _identity = QuoterIdentity(
  signerAddress: '0xSigner',
  makerAddress: '0xMaker',
  signatureType: 0,
);

/// Records everything written to the sink; drives inbound frames.
class _FakeSink implements WebSocketSink {
  final List<String> sent = [];
  bool closed = false;

  @override
  void add(dynamic data) => sent.add(data as String);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChannel implements WebSocketChannel {
  final StreamController<dynamic> _incoming = StreamController<dynamic>();
  final _FakeSink _sink = _FakeSink();

  void emit(Map<String, dynamic> message) => _incoming.add(jsonEncode(message));

  List<String> get sent => _sink.sent;

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

QuoterGatewayClient _clientWith(_FakeChannel channel) => QuoterGatewayClient(
      credentials: _creds,
      identity: _identity,
      connect: (_) => channel,
    );

void main() {
  test('connect sends the auth handshake and completes on auth response',
      () async {
    final channel = _FakeChannel();
    final client = _clientWith(channel);

    final authFuture = client.connect();
    // Let the auth message flush, then reply.
    await Future<void>.delayed(Duration.zero);

    expect(channel.sent, hasLength(1));
    final authMsg = jsonDecode(channel.sent.first) as Map<String, dynamic>;
    expect(authMsg['type'], equals('auth'));
    expect(authMsg['auth']['apiKey'], equals('test-api-key'));
    expect(authMsg['identity']['maker_address'], equals('0xMaker'));
    expect(authMsg['identity']['signature_type'], equals(0));

    channel.emit({
      'type': 'auth',
      'success': true,
      'address': '0xMaker',
      'role': 'maker',
    });

    final result = await authFuture;
    expect(result.success, isTrue);
    expect(result.role, equals('maker'));
    await client.dispose();
  });

  test('inbound RFQ_REQUEST routes to the rfqRequests stream', () async {
    final channel = _FakeChannel();
    final client = _clientWith(channel);

    final authFuture = client.connect();
    await Future<void>.delayed(Duration.zero);
    channel.emit({'type': 'auth', 'success': true});
    await authFuture;

    final received = client.rfqRequests.first;
    channel.emit({
      'type': 'RFQ_REQUEST',
      'rfq_id': 'rfq-9',
      'leg_position_ids': ['0xa'],
      'direction': 'SELL',
      'requested_size': {'unit': 'notional', 'value_e6': '100'},
    });

    final event = await received;
    expect(event.rfqId, equals('rfq-9'));
    expect(event.direction, equals('SELL'));
    expect(event.sizeUnit, equals('notional'));
    await client.dispose();
  });

  test('submitQuote and sendConfirmation emit correctly-shaped frames',
      () async {
    final channel = _FakeChannel();
    final client = _clientWith(channel);

    final authFuture = client.connect();
    await Future<void>.delayed(Duration.zero);
    channel.emit({'type': 'auth', 'success': true});
    await authFuture;

    client.submitQuote(
      rfqId: 'rfq-9',
      priceE6: '550000',
      sizeE6: '100',
      signedOrder: const SignedRfqOrder(
        salt: '1',
        maker: '0xMaker',
        signer: '0xSigner',
        tokenId: '0xtoken',
        makerAmount: '1',
        takerAmount: '2',
        side: 0,
        signatureType: 0,
        timestamp: '1700',
        signature: '0xsig',
      ),
    );

    client.sendConfirmation(
      rfqId: 'rfq-9',
      quoteId: 'q-1',
      decision: LastLookDecision.decline,
    );

    // Frame 0 is auth; 1 = quote; 2 = confirmation.
    final quote = jsonDecode(channel.sent[1]) as Map<String, dynamic>;
    expect(quote['type'], equals('RFQ_QUOTE'));
    expect(quote['rfq_id'], equals('rfq-9'));
    expect(quote['signed_order']['tokenId'], equals('0xtoken'));

    final confirm = jsonDecode(channel.sent[2]) as Map<String, dynamic>;
    expect(confirm['type'], equals('RFQ_CONFIRMATION_RESPONSE'));
    expect(confirm['decision'], equals('DECLINE'));

    await client.dispose();
  });

  test('cancelQuote falls back to identity addresses', () async {
    final channel = _FakeChannel();
    final client = _clientWith(channel);

    final authFuture = client.connect();
    await Future<void>.delayed(Duration.zero);
    channel.emit({'type': 'auth', 'success': true});
    await authFuture;

    client.cancelQuote(rfqId: 'rfq-9', quoteId: 'q-1');

    final cancel = jsonDecode(channel.sent[1]) as Map<String, dynamic>;
    expect(cancel['type'], equals('RFQ_QUOTE_CANCEL'));
    expect(cancel['signer_address'], equals('0xSigner'));
    expect(cancel['maker_address'], equals('0xMaker'));

    await client.dispose();
  });
}
