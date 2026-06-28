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

  group('GammaClient public REST parity', () {
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

    test('getSportsMetadata calls /sports and parses metadata', () async {
      final client = clientFor((request) async {
        expect(request.url.path, equals('/sports'));
        return http.Response(
          jsonEncode([
            {
              'id': 10,
              'sport': 'nfl',
              'image': 'https://example.com/nfl.png',
              'resolution': 'https://nfl.com/',
              'ordering': 'away',
              'tags': '1,450,100639',
              'series': '10187',
              'createdAt': '2025-11-05T19:27:45.399303Z',
            },
          ]),
          200,
        );
      });

      final sports = await client.getSportsMetadata();

      expect(sports, hasLength(1));
      expect(sports.single.id, equals(10));
      expect(sports.single.sport, equals('nfl'));
      expect(sports.single.tagIds, equals([1, 450, 100639]));
      expect(sports.single.series, equals('10187'));
      client.close();
    });

    test('getSportsMarketTypes calls /sports/market-types', () async {
      final client = clientFor((request) async {
        expect(request.url.path, equals('/sports/market-types'));
        return http.Response(
          jsonEncode({
            r'$schema':
                'https://gamma-api.polymarket.com/schemas/SportsMarketTypesResponse.json',
            'marketTypes': ['moneyline', 'spreads', 'totals'],
          }),
          200,
        );
      });

      final marketTypes = await client.getSportsMarketTypes();

      expect(marketTypes, equals(['moneyline', 'spreads', 'totals']));
      client.close();
    });

    test('getTeams serializes filters and parses team fields', () async {
      final client = clientFor((request) async {
        expect(request.url.path, equals('/teams'));
        expect(request.url.queryParameters['limit'], equals('2'));
        expect(request.url.queryParameters['offset'], equals('4'));
        expect(request.url.queryParameters['order'], equals('name'));
        expect(request.url.queryParameters['ascending'], equals('true'));
        expect(request.url.queryParameters['league'], equals('nfl,nba'));
        expect(request.url.queryParameters['name'], equals('Giants,Knicks'));
        expect(request.url.queryParameters['abbreviation'], equals('nyg,nyk'));
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'name': 'New York Giants',
              'league': 'nfl',
              'record': '0-0',
              'logo': 'https://example.com/nyg.png',
              'abbreviation': 'nyg',
              'alias': 'giants',
              'providerId': '12345',
              'color': '#003C7F',
              'createdAt': '2025-01-01T00:00:00Z',
              'updatedAt': '2025-01-02T00:00:00Z',
            },
          ]),
          200,
        );
      });

      final teams = await client.getTeams(
        limit: 2,
        offset: 4,
        order: 'name',
        ascending: true,
        leagues: ['nfl', 'nba'],
        names: ['Giants', 'Knicks'],
        abbreviations: ['nyg', 'nyk'],
      );

      expect(teams, hasLength(1));
      expect(teams.single.id, equals(1));
      expect(teams.single.name, equals('New York Giants'));
      expect(teams.single.league, equals('nfl'));
      expect(teams.single.providerId, equals(12345));
      expect(teams.single.color, equals('#003C7F'));
      client.close();
    });

    test('getTag calls /tags/{id} and parses optional fields', () async {
      final client = clientFor((request) async {
        expect(request.url.path, equals('/tags/1'));
        expect(request.url.queryParameters['include_template'], equals('true'));
        return http.Response(
          jsonEncode({
            'id': '1',
            'label': 'Sports',
            'slug': 'sports',
            'forceShow': false,
            'forceHide': true,
            'requiresTranslation': false,
            'publishedAt': '2023-10-24 22:37:50.296+00',
            'createdBy': '15',
            'updatedBy': 16,
            'createdAt': '2023-10-24T22:37:50.31Z',
            'updatedAt': '2026-04-17T20:47:16.461062Z',
            'activeEventsCount': '20',
          }),
          200,
        );
      });

      final tag = await client.getTag(1, includeTemplate: true);

      expect(tag.id, equals(1));
      expect(tag.label, equals('Sports'));
      expect(tag.forceHide, isTrue);
      expect(tag.createdBy, equals(15));
      expect(tag.updatedBy, equals(16));
      expect(tag.activeEventsCount, equals(20));
      client.close();
    });

    test('getTagBySlug calls /tags/slug/{slug}', () async {
      final client = clientFor((request) async {
        expect(request.url.path, equals('/tags/slug/sports'));
        expect(
          request.url.queryParameters['include_template'],
          equals('false'),
        );
        return http.Response(
          jsonEncode({'id': '1', 'label': 'Sports', 'slug': 'sports'}),
          200,
        );
      });

      final tag = await client.getTagBySlug('sports', includeTemplate: false);

      expect(tag.id, equals(1));
      expect(tag.slug, equals('sports'));
      client.close();
    });

    test('getRelatedTagsById parses relationship rows', () async {
      final client = clientFor((request) async {
        expect(request.url.path, equals('/tags/1/related-tags'));
        expect(request.url.queryParameters['omit_empty'], equals('true'));
        expect(request.url.queryParameters['status'], equals('all'));
        return http.Response(
          jsonEncode([
            {'id': '34736', 'tagID': 1, 'relatedTagID': '450', 'rank': 1},
          ]),
          200,
        );
      });

      final related = await client.getRelatedTagsById(
        1,
        omitEmpty: true,
        status: 'all',
      );

      expect(related, hasLength(1));
      expect(related.single.id, equals('34736'));
      expect(related.single.tagId, equals(1));
      expect(related.single.relatedTagId, equals(450));
      expect(related.single.rank, equals(1));
      client.close();
    });

    test('getRelatedTagsBySlug calls slug relationship endpoint', () async {
      final client = clientFor((request) async {
        expect(request.url.path, equals('/tags/slug/sports/related-tags'));
        expect(request.url.queryParameters['omit_empty'], equals('false'));
        expect(request.url.queryParameters['status'], equals('active'));
        return http.Response(
          jsonEncode([
            {'id': '34736', 'tagID': 1, 'relatedTagID': 450, 'rank': 1},
          ]),
          200,
        );
      });

      final related = await client.getRelatedTagsBySlug(
        'sports',
        omitEmpty: false,
        status: 'active',
      );

      expect(related.single.relatedTagId, equals(450));
      client.close();
    });

    test('getTagsRelatedToTagById parses related tag objects', () async {
      final client = clientFor((request) async {
        expect(request.url.path, equals('/tags/1/related-tags/tags'));
        expect(request.url.queryParameters['omit_empty'], equals('true'));
        expect(request.url.queryParameters['status'], equals('closed'));
        return http.Response(
          jsonEncode([
            {
              'id': '450',
              'label': 'NFL',
              'slug': 'nfl',
              'activeEventsCount': 48,
            },
          ]),
          200,
        );
      });

      final tags = await client.getTagsRelatedToTagById(
        1,
        omitEmpty: true,
        status: 'closed',
      );

      expect(tags, hasLength(1));
      expect(tags.single.id, equals(450));
      expect(tags.single.activeEventsCount, equals(48));
      client.close();
    });

    test(
      'getTagsRelatedToTagBySlug calls related tag object endpoint',
      () async {
        final client = clientFor((request) async {
          expect(
            request.url.path,
            equals('/tags/slug/sports/related-tags/tags'),
          );
          expect(request.url.queryParameters['omit_empty'], equals('true'));
          expect(request.url.queryParameters['status'], equals('all'));
          return http.Response(
            jsonEncode([
              {'id': '450', 'label': 'NFL', 'slug': 'nfl'},
            ]),
            200,
          );
        });

        final tags = await client.getTagsRelatedToTagBySlug(
          'sports',
          omitEmpty: true,
          status: 'all',
        );

        expect(tags.single.slug, equals('nfl'));
        client.close();
      },
    );
  });
}
