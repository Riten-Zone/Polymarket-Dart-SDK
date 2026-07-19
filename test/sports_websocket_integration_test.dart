/// Live integration test for SportsWebSocketClient — connects to the real
/// sports feed and asserts we receive live `sport_result` events. Lenient: if
/// no games are active it passes on a successful connection alone.
///
/// Run with:
///   dart test test/sports_websocket_integration_test.dart --tags sports
@Tags(['integration', 'sports'])
library;

import 'dart:async';

import 'package:polymarket_dart/polymarket_dart.dart';
import 'package:test/test.dart';

void main() {
  test('connects and receives live sport_result events', () async {
    final client = SportsWebSocketClient();
    final received = <SportResult>[];
    final sub = client.results.listen(received.add);

    await client.connect();
    expect(client.isConnected, isTrue);

    // Collect for a few seconds.
    await Future<void>.delayed(const Duration(seconds: 6));

    if (received.isEmpty) {
      // No active games right now — connection alone is the pass condition.
      print('sports feed connected; no active games in the sample window');
    } else {
      final r = received.first;
      print('live sport_result → league=${r.leagueAbbreviation} '
          'score="${r.score}" live=${r.live} ended=${r.ended} '
          '(${received.length} events in 6s)');
      expect(r.score, isNotEmpty);
      expect(r.leagueAbbreviation, isNotEmpty);
    }

    await sub.cancel();
    await client.dispose();
  }, timeout: const Timeout(Duration(seconds: 20)));
}
