import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polymarket_dart/polymarket_dart.dart';
import 'package:test/test.dart';

void main() {
  GammaClient clientFor(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    return GammaClient(transport: HttpTransport(client: MockClient(handler)));
  }

  group('GammaClient series/comments parity', () {
    test('getSeries calls /series and parses series fields', () async {
      final client = clientFor((request) async {
        expect(request.url.path, equals('/series'));
        expect(request.url.queryParameters['limit'], equals('1'));
        expect(request.url.queryParameters['slug'], equals('nfl,crypto'));
        expect(request.url.queryParameters['categories_ids'], equals('1,2'));
        expect(request.url.queryParameters['closed'], equals('false'));
        expect(request.url.queryParameters['exclude_events'], equals('true'));

        return http.Response(
          jsonEncode([
            {
              'id': '1',
              'ticker': 'nfl',
              'slug': 'nfl',
              'title': 'NFL',
              'subtitle': 'Football',
              'seriesType': 'single',
              'recurrence': 'daily',
              'description': 'NFL games',
              'layout': 'default',
              'active': true,
              'closed': false,
              'archived': false,
              'featured': true,
              'restricted': true,
              'commentsEnabled': false,
              'volume24hr': '12.5',
              'volume': 100,
              'liquidity': 3.25,
              'score': '7',
              'commentCount': '11',
              'startDate': '2026-01-01T00:00:00Z',
              'events': [
                {
                  'id': '42',
                  'title': 'Event title',
                  'description': 'Event description',
                  'slug': 'event-title',
                  'active': true,
                  'closed': false,
                },
              ],
              'tags': [
                {'id': '1', 'label': 'Sports', 'slug': 'sports'},
              ],
            },
          ]),
          200,
        );
      });

      final series = await client.getSeries(
        limit: 1,
        slugs: ['nfl', 'crypto'],
        categoryIds: [1, 2],
        closed: false,
        excludeEvents: true,
      );

      expect(series, hasLength(1));
      expect(series.single.id, equals('1'));
      expect(series.single.title, equals('NFL'));
      expect(series.single.volume24hr, equals(12.5));
      expect(series.single.score, equals(7));
      expect(series.single.events.single.id, equals(42));
      expect(series.single.tags.single.slug, equals('sports'));
      client.close();
    });

    test('getSeriesById calls /series/{id}', () async {
      final client = clientFor((request) async {
        expect(request.url.path, equals('/series/1'));
        return http.Response(
          jsonEncode({
            'id': '1',
            'slug': 'nfl',
            'title': 'NFL',
            'active': true,
            'closed': false,
          }),
          200,
        );
      });

      final series = await client.getSeriesById('1');

      expect(series.id, equals('1'));
      expect(series.slug, equals('nfl'));
      client.close();
    });

    test(
      'getComments serializes scoped filters and parses nested profile',
      () async {
        final client = clientFor((request) async {
          expect(request.url.path, equals('/comments'));
          expect(
            request.url.queryParameters['parent_entity_type'],
            equals('Event'),
          );
          expect(request.url.queryParameters['parent_entity_id'], equals('42'));
          expect(request.url.queryParameters['get_positions'], equals('true'));
          expect(request.url.queryParameters['holders_only'], equals('false'));

          return http.Response(
            jsonEncode([
              {
                'id': 'comment-1',
                'body': 'hello',
                'parentEntityType': 'Event',
                'parentEntityID': 42,
                'parentCommentID': '',
                'userAddress': '0xuser',
                'replyAddress': '0xreply',
                'createdAt': '2026-01-01T00:00:00Z',
                'updatedAt': '2026-01-02T00:00:00Z',
                'profile': {
                  'name': 'Alice',
                  'pseudonym': 'alice',
                  'displayUsernamePublic': true,
                  'bio': 'bio',
                  'isMod': false,
                  'isCreator': true,
                  'proxyWallet': '0xproxy',
                  'baseAddress': '0xbase',
                  'profileImage': 'https://example.com/alice.png',
                  'positions': [
                    {'tokenId': '123', 'positionSize': '4.5'},
                  ],
                },
                'reactions': [
                  {
                    'id': 'reaction-1',
                    'commentID': '1',
                    'reactionType': 'like',
                    'icon': 'thumb',
                    'userAddress': '0xreactor',
                    'createdAt': '2026-01-03T00:00:00Z',
                  },
                ],
                'reportCount': '0',
                'reactionCount': 1,
              },
            ]),
            200,
          );
        });

        final comments = await client.getComments(
          parentEntityType: 'Event',
          parentEntityId: 42,
          getPositions: true,
          holdersOnly: false,
        );

        expect(comments, hasLength(1));
        expect(comments.single.id, equals('comment-1'));
        expect(comments.single.parentEntityId, equals(42));
        expect(comments.single.profile?.name, equals('Alice'));
        expect(
          comments.single.profile?.positions.single.positionSize,
          equals('4.5'),
        );
        expect(comments.single.reactions.single.reactionType, equals('like'));
        client.close();
      },
    );

    test('getCommentsById calls /comments/{id}', () async {
      final client = clientFor((request) async {
        expect(request.url.path, equals('/comments/comment-1'));
        return http.Response(jsonEncode([]), 200);
      });

      final comments = await client.getCommentsById('comment-1');

      expect(comments, isEmpty);
      client.close();
    });

    test(
      'getCommentsByUserAddress calls /comments/user_address/{address}',
      () async {
        final client = clientFor((request) async {
          expect(request.url.path, equals('/comments/user_address/0xuser'));
          return http.Response(jsonEncode([]), 200);
        });

        final comments = await client.getCommentsByUserAddress('0xuser');

        expect(comments, isEmpty);
        client.close();
      },
    );
  });
}
