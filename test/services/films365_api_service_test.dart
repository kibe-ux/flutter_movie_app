import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/services/films365_api_service.dart';
import 'package:moviehub_app/models/films365_models.dart';

void main() {
  const idToken = 'test-firebase-id-token';
  const backendUrl = 'https://backend.example';

  Films365ApiService serviceFor(http.Client client) {
    return Films365ApiService(
      client: client,
      apiBaseUrlProvider: () => backendUrl,
      idTokenProvider: () async => idToken,
    );
  }

  test('trending uses the backend proxy and Firebase bearer token', () async {
    late http.Request request;
    final service = serviceFor(MockClient((incoming) async {
      request = incoming;
      return http.Response('{"results":[]}', HttpStatus.ok);
    }));

    await service.trending();

    expect(request.method, 'GET');
    expect(request.url.path, '/api/mobile/trending');
    expect(request.url.queryParameters, {'type': 'all', 'page': '1'});
    expect(request.headers['authorization'], 'Bearer $idToken');
  });

  test('popular and latest forward type and page', () async {
    final requests = <http.Request>[];
    final service = serviceFor(MockClient((request) async {
      requests.add(request);
      return http.Response('{}', HttpStatus.ok);
    }));

    await service.popular(type: Films365ContentType.tv, page: 3);
    await service.latest(type: Films365ContentType.movie, page: 2);

    expect(requests[0].url.path, '/api/mobile/popular');
    expect(requests[0].url.queryParameters, {'type': 'tv', 'page': '3'});
    expect(requests[1].url.path, '/api/mobile/latest');
    expect(requests[1].url.queryParameters, {'type': 'movie', 'page': '2'});
  });

  test('explore forwards documented filters with encoded query parameters',
      () async {
    late http.Request request;
    final service = serviceFor(MockClient((incoming) async {
      request = incoming;
      return http.Response('{}', HttpStatus.ok);
    }));

    await service.explore(
      type: Films365ContentType.tv,
      page: 2,
      limit: 24,
      genre: 'Sci-Fi',
      minRating: 6.5,
      maxRating: 9,
      minYear: 2000,
      maxYear: 2025,
      sortBy: Films365SortBy.rating,
      order: Films365SortOrder.desc,
    );

    expect(request.url.path, '/api/mobile/explore');
    expect(request.url.queryParameters, {
      'type': 'tv',
      'page': '2',
      'limit': '24',
      'genre': 'Sci-Fi',
      'min_rating': '6.5',
      'max_rating': '9.0',
      'min_year': '2000',
      'max_year': '2025',
      'sort_by': 'rating',
      'order': 'desc',
    });
  });

  test('search sends JSON query and preserves decoded response', () async {
    late http.Request request;
    final service = serviceFor(MockClient((incoming) async {
      request = incoming;
      return http.Response(
        '{"results":{"all":[],"movies":[],"tvs":[]},"totalCount":0}',
        HttpStatus.ok,
      );
    }));

    final response = await service.search(query: 'Dune & spice');

    expect(request.method, 'POST');
    expect(request.url.path, '/api/mobile/search');
    expect(request.headers['content-type'], 'application/json');
    expect(request.body, '{"query":"Dune & spice"}');
    expect(response, isA<Films365SearchEnvelope>());
    final results = response as Films365SearchEnvelope;
    expect(results.all, isEmpty);
    expect(results.movies, isEmpty);
    expect(results.tvs, isEmpty);
    expect(results.totalCount, 0);
  });

  test('details requires exactly one identifier and sends its type', () async {
    late http.Request request;
    final service = serviceFor(MockClient((incoming) async {
      request = incoming;
      return http.Response('{}', HttpStatus.ok);
    }));

    await service.details(type: Films365DetailsType.tv, tmdbId: 42);

    expect(request.url.path, '/api/mobile/details');
    expect(request.url.queryParameters, {'type': 'tv', 'tmdbId': '42'});
    expect(
      () => service.details(type: Films365DetailsType.movie),
      throwsArgumentError,
    );
    expect(
      () => service.details(
        type: Films365DetailsType.movie,
        id: 'film-id',
        tmdbId: 42,
      ),
      throwsArgumentError,
    );
  });

  test('fallback UUID matches are resolved to details with a download URL',
      () async {
    final requests = <http.Request>[];
    final service = serviceFor(MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/mobile/details' &&
          request.url.queryParameters.containsKey('tmdbId')) {
        return http.Response('{}', HttpStatus.notFound);
      }
      if (request.url.path == '/api/mobile/trending') {
        return http.Response(
          '{"results":[{"id":"films365-uuid","tmdbId":42,'
          '"type":"movie"}],"total_pages":1}',
          HttpStatus.ok,
        );
      }
      if (request.url.path == '/api/mobile/details') {
        return http.Response(
          '{"data":{"downloadUrl":"https://downloads.example/movie"}}',
          HttpStatus.ok,
        );
      }
      throw StateError('Unexpected request: ${request.url}');
    }));

    final result = await service.findUuidByTmdbId(
      tmdbId: 42,
      type: 'movie',
    );

    expect(result?['uuid'], 'films365-uuid');
    expect(result?['downloadUrl'], 'https://downloads.example/movie');
    expect(DateTime.tryParse(result?['downloadUrlFetchedAt'] as String),
        isNotNull);
    expect(
      requests.last.url.queryParameters,
      {'type': 'movie', 'id': 'films365-uuid'},
    );
  });

  test('person forwards required type and tmdbId', () async {
    late http.Request request;
    final service = serviceFor(MockClient((incoming) async {
      request = incoming;
      return http.Response('{}', HttpStatus.ok);
    }));

    await service.person(type: 'movie', tmdbId: 42);

    expect(request.url.path, '/api/mobile/person');
    expect(request.url.queryParameters, {'type': 'movie', 'tmdbId': '42'});
  });

  test('torrent link forwards its JSON body to the nested proxy route',
      () async {
    late http.Request request;
    final service = serviceFor(MockClient((incoming) async {
      request = incoming;
      return http.Response('{}', HttpStatus.ok);
    }));

    await service.torrentLink(link: 'https://example.invalid/content');

    expect(request.method, 'POST');
    expect(request.url.path, '/api/mobile/details/torrent-link');
    expect(request.headers['content-type'], 'application/json');
    expect(
      request.body,
      '{"link":"https://example.invalid/content"}',
    );
  });

  test('requires a signed-in user before making a request', () async {
    var madeRequest = false;
    final service = Films365ApiService(
      client: MockClient((_) async {
        madeRequest = true;
        return http.Response('{}', HttpStatus.ok);
      }),
      apiBaseUrlProvider: () => backendUrl,
      idTokenProvider: () async => null,
    );

    await expectLater(service.trending(), throwsA(isA<StateError>()));
    expect(madeRequest, isFalse);
  });

  test('rejects invalid page and empty search query', () {
    final service = serviceFor(
      MockClient((_) async => http.Response('{}', HttpStatus.ok)),
    );

    expect(() => service.trending(page: 0), throwsArgumentError);
    expect(() => service.explore(limit: 0), throwsArgumentError);
    expect(() => service.search(query: '  '), throwsArgumentError);
  });

  test('rejects non-success responses without exposing response bodies',
      () async {
    var requestCount = 0;
    final service = serviceFor(
      MockClient(
        (_) async {
          requestCount++;
          return http.Response('sensitive error', HttpStatus.unauthorized);
        },
      ),
    );

    await expectLater(
      service.trending(),
      throwsA(
        predicate(
          (error) =>
              error.toString().contains('401') &&
              !error.toString().contains('sensitive error'),
        ),
      ),
    );
    expect(requestCount, 1);
  });

  test('returns null for an empty successful response', () async {
    final service = serviceFor(
      MockClient((_) async => http.Response('', HttpStatus.noContent)),
    );

    expect(await service.trending(), isNull);
  });

  test('propagates malformed JSON as a FormatException', () async {
    final service = serviceFor(
      MockClient((_) async => http.Response('{not json', HttpStatus.ok)),
    );

    await expectLater(service.trending(), throwsA(isA<FormatException>()));
  });
}
