import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polymarket_dart/polymarket_dart.dart';
import 'package:test/test.dart';

void main() {
  DataClient clientFor(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    return DataClient(transport: HttpTransport(client: MockClient(handler)));
  }

  group('DataClient public REST parity', () {
    test(
      'getLeaderboard calls /v1/leaderboard and parses current fields',
      () async {
        final client = clientFor((request) async {
          expect(request.url.path, equals('/v1/leaderboard'));
          expect(request.url.queryParameters['category'], equals('OVERALL'));
          expect(request.url.queryParameters['timePeriod'], equals('ALL'));
          expect(request.url.queryParameters['orderBy'], equals('PNL'));
          expect(request.url.queryParameters['limit'], equals('1'));
          expect(request.url.queryParameters['offset'], equals('2'));
          return http.Response(
            jsonEncode([
              {
                'rank': '1',
                'proxyWallet': '0x56687bf447db6ffa42ffe2204a05edaa20f55839',
                'userName': 'alice',
                'xUsername': 'alice_x',
                'verifiedBadge': true,
                'vol': 12.5,
                'pnl': 3.25,
                'profileImage': 'https://example.com/alice.png',
              },
            ]),
            200,
          );
        });

        final entries = await client.getLeaderboard(
          category: 'OVERALL',
          timePeriod: 'ALL',
          orderBy: 'PNL',
          limit: 1,
          offset: 2,
        );

        expect(entries, hasLength(1));
        expect(entries.single.rank, equals(1));
        expect(entries.single.proxyWallet, startsWith('0x'));
        expect(entries.single.userName, equals('alice'));
        expect(entries.single.volume, equals(12.5));
        expect(entries.single.pnl, equals(3.25));
        expect(entries.single.verifiedBadge, isTrue);
        client.close();
      },
    );

    test('getClosedPositions serializes filters and parses response', () async {
      final client = clientFor((request) async {
        expect(request.url.path, equals('/closed-positions'));
        expect(request.url.queryParameters['user'], equals('0xuser'));
        expect(
          request.url.queryParameters['market'],
          equals('0xmarket1,0xmarket2'),
        );
        expect(request.url.queryParameters['eventId'], equals('1,2'));
        expect(request.url.queryParameters['sortBy'], equals('REALIZEDPNL'));
        expect(request.url.queryParameters['sortDirection'], equals('DESC'));
        return http.Response(
          jsonEncode([
            {
              'proxyWallet': '0xproxy',
              'asset': '123',
              'conditionId': '0xcondition',
              'avgPrice': '0.45',
              'totalBought': 10,
              'realizedPnl': 2.5,
              'curPrice': 1,
              'timestamp': '1782357157',
              'title': 'Market title',
              'slug': 'market-title',
              'icon': 'https://example.com/icon.png',
              'eventSlug': 'event-slug',
              'outcome': 'Yes',
              'outcomeIndex': 0,
              'oppositeOutcome': 'No',
              'oppositeAsset': '456',
              'endDate': '2026-06-25T00:00:00Z',
            },
          ]),
          200,
        );
      });

      final positions = await client.getClosedPositions(
        '0xuser',
        markets: ['0xmarket1', '0xmarket2'],
        eventIds: [1, 2],
        sortBy: 'REALIZEDPNL',
        sortDirection: 'DESC',
      );

      expect(positions, hasLength(1));
      expect(positions.single.avgPrice, equals(0.45));
      expect(positions.single.totalBought, equals(10));
      expect(positions.single.timestamp, equals(1782357157));
      expect(positions.single.oppositeOutcome, equals('No'));
      client.close();
    });

    test('getTotalValue parses the documented list response', () async {
      final client = clientFor((request) async {
        expect(request.url.path, equals('/value'));
        expect(request.url.queryParameters['user'], equals('0xuser'));
        expect(request.url.queryParameters['market'], equals('0xmarket'));
        return http.Response(
          jsonEncode([
            {'user': '0xuser', 'value': '4.75'},
          ]),
          200,
        );
      });

      final values = await client.getTotalValue(
        '0xuser',
        markets: ['0xmarket'],
      );

      expect(values, hasLength(1));
      expect(values.single.user, equals('0xuser'));
      expect(values.single.value, equals(4.75));
      client.close();
    });

    test('getTotalMarketsTraded parses /traded response', () async {
      final client = clientFor((request) async {
        expect(request.url.path, equals('/traded'));
        expect(request.url.queryParameters['user'], equals('0xuser'));
        return http.Response(
          jsonEncode({'user': '0xuser', 'traded': '7'}),
          200,
        );
      });

      final traded = await client.getTotalMarketsTraded('0xuser');

      expect(traded.user, equals('0xuser'));
      expect(traded.traded, equals(7));
      client.close();
    });

    test(
      'getPositionsForMarket calls /v1/market-positions and parses groups',
      () async {
        final client = clientFor((request) async {
          expect(request.url.path, equals('/v1/market-positions'));
          expect(request.url.queryParameters['market'], equals('0xmarket'));
          expect(request.url.queryParameters['user'], equals('0xproxy'));
          expect(request.url.queryParameters['status'], equals('OPEN'));
          expect(request.url.queryParameters['sortBy'], equals('TOTAL_PNL'));
          expect(request.url.queryParameters['limit'], equals('5'));
          return http.Response(
            jsonEncode([
              {
                'token': 'token-yes',
                'positions': [
                  {
                    'proxyWallet': '0xproxy',
                    'name': 'alice',
                    'profileImage': 'https://example.com/alice.png',
                    'verified': true,
                    'asset': 'token-yes',
                    'conditionId': '0xmarket',
                    'avgPrice': 0.4,
                    'size': '10',
                    'currPrice': 0.6,
                    'currentValue': 6,
                    'cashPnl': 2,
                    'totalBought': 10,
                    'realizedPnl': 1,
                    'totalPnl': 3,
                    'outcome': 'Yes',
                    'outcomeIndex': 0,
                  },
                ],
              },
            ]),
            200,
          );
        });

        final groups = await client.getPositionsForMarket(
          '0xmarket',
          user: '0xproxy',
          status: 'OPEN',
          sortBy: 'TOTAL_PNL',
          limit: 5,
        );

        expect(groups, hasLength(1));
        expect(groups.single.token, equals('token-yes'));
        expect(groups.single.positions.single.name, equals('alice'));
        expect(groups.single.positions.single.currPrice, equals(0.6));
        expect(groups.single.positions.single.totalPnl, equals(3));
        client.close();
      },
    );
  });
}
