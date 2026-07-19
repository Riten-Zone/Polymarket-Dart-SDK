/// Offline tests for SportsWebSocketClient — injects a fake WebSocketChannel to
/// verify sport_result parsing and the ping/pong heartbeat with no network.
library;

import 'dart:async';
import 'dart:convert';

import 'package:polymarket_dart/polymarket_dart.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _FakeSink implements WebSocketSink {
  final List<String> sent = [];

  @override
  void add(dynamic data) => sent.add(data as String);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChannel implements WebSocketChannel {
  final StreamController<dynamic> _incoming = StreamController<dynamic>();
  final _FakeSink _sink = _FakeSink();

  void emitRaw(String data) => _incoming.add(data);
  void emit(Map<String, dynamic> m) => _incoming.add(jsonEncode(m));
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

void main() {
  test('parses a sport_result message', () async {
    final channel = _FakeChannel();
    final client = SportsWebSocketClient(connect: (_) => channel);

    final first = client.results.first;
    await client.connect();

    channel.emit({
      'type': 'sport_result',
      'gameId': 19439,
      'leagueAbbreviation': 'nfl',
      'slug': 'nfl-lac-buf-2025-01-26',
      'homeTeam': 'LAC',
      'awayTeam': 'BUF',
      'status': 'InProgress',
      'score': '3-16',
      'period': 'Q4',
      'elapsed': '5:18',
      'live': true,
      'ended': false,
      'turn': 'lac',
    });

    final r = await first;
    expect(r.gameId, equals(19439));
    expect(r.leagueAbbreviation, equals('nfl'));
    expect(r.score, equals('3-16'));
    expect(r.elapsed, equals('5:18'));
    expect(r.live, isTrue);
    expect(r.ended, isFalse);
    expect(r.turn, equals('lac'));
    await client.dispose();
  });

  test('replies pong to a server ping', () async {
    final channel = _FakeChannel();
    final client = SportsWebSocketClient(connect: (_) => channel);
    await client.connect();

    channel.emitRaw('ping');
    await Future<void>.delayed(Duration.zero);

    expect(channel.sent, contains('pong'));
    await client.dispose();
  });

  test('parses a message without an explicit type but with gameId', () async {
    final channel = _FakeChannel();
    final client = SportsWebSocketClient(connect: (_) => channel);

    final first = client.results.first;
    await client.connect();

    channel.emit({
      'gameId': 1,
      'slug': 'nba-lal-bos-2026-01-01',
      'score': '10-8',
      'ended': false,
      'live': true,
    });

    final r = await first;
    expect(r.gameId, equals(1));
    expect(r.slug, contains('nba'));
    await client.dispose();
  });
}
