import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/services/films365_api_service.dart';

void main() {
  test('refreshes a rejected Firebase token once before retrying the request',
      () async {
    var tokenCalls = 0;
    var requests = 0;
    final service = Films365ApiService(
      client: MockClient((request) async {
        requests++;
        if (requests == 1) {
          expect(request.headers['authorization'], 'Bearer old-token');
          return http.Response('{}', 401,
              headers: {'x-moviehub-response-source': 'firebase-auth'});
        }
        expect(request.headers['authorization'], 'Bearer fresh-token');
        return http.Response(
            '{"data":{"downloadUrl":"https://example.com/movie.mp4"}}', 200);
      }),
      apiBaseUrlProvider: () => 'https://backend.example',
      idTokenProvider: () async =>
          ++tokenCalls == 1 ? 'old-token' : 'fresh-token',
    );
    final result = await service.findUuidByTmdbId(tmdbId: 42, type: 'movie');
    expect(result?['downloadUrl'], 'https://example.com/movie.mp4');
    expect(tokenCalls, 2);
    expect(requests, 2);
  });

  test('a removed provider ID falls back to TMDB lookup', () async {
    final requests = <http.Request>[];
    final service = Films365ApiService(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.queryParameters.containsKey('id')) {
          return http.Response('{}', 404);
        }
        return http.Response(
            '{"data":{"id":"replacement-id","downloadUrl":"https://example.com/movie.mp4"}}',
            200);
      }),
      apiBaseUrlProvider: () => 'https://backend.example',
      idTokenProvider: () async => 'token',
    );
    final result = await service.findUuidByTmdbId(
        tmdbId: 42, type: 'movie', providerId: 'removed-id');
    expect(result?['uuid'], 'replacement-id');
    expect(requests, hasLength(2));
    expect(requests.last.url.queryParameters['tmdbId'], '42');
  });

  test('metadata-only TMDB details also check the provider record once',
      () async {
    var requests = 0;
    final service = Films365ApiService(
      client: MockClient((_) async {
        requests++;
        return http.Response(
            '{"data":{"id":"provider-movie","title":"A movie"}}', 200);
      }),
      apiBaseUrlProvider: () => 'https://backend.example',
      idTokenProvider: () async => 'token',
    );
    final result = await service.findUuidByTmdbId(tmdbId: 42, type: 'movie');
    expect(result?['title'], 'A movie');
    expect(result?['downloadUrl'], isNull);
    expect(requests, 2);
  });

  Films365ApiService serviceFor(
          Future<http.Response> Function(http.Request) handle) =>
      Films365ApiService(
        client: MockClient(handle),
        apiBaseUrlProvider: () => 'https://backend.example',
        idTokenProvider: () async => 'token',
      );

  test('title search resolves an exact provider ID before TMDB details',
      () async {
    final requests = <http.Request>[];
    final service = serviceFor((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/search')) {
        return http.Response(
            '{"results":{"movies":[{"id":"wrong-remake","tmdbId":99},'
            '{"id":"right-movie","tmdbId":"42"}],'
            '"tvs":[{"id":"wrong-tv","tmdbId":42,"type":"tv"}]}}',
            200);
      }
      expect(
          request.url.queryParameters, {'type': 'movie', 'id': 'right-movie'});
      return http.Response(
          '{"data":{"downloadUrl":"https://example.com/movie.mp4"}}', 200);
    });
    final metadata = await service.findUuidByTmdbId(
        tmdbId: 42, type: 'movie', title: 'Same title');
    expect(metadata?['uuid'], 'right-movie');
    expect(requests, hasLength(2));
  });

  test('original title is searched when the localized title has no match',
      () async {
    final queries = <String>[];
    final service = serviceFor((request) async {
      if (request.url.path.endsWith('/search')) {
        queries.add(request.body);
        return http.Response(
            queries.length == 1
                ? '{"results":{}}'
                : '{"results":{"movies":[{"id":"original-match","tmdbId":42}]}}',
            200);
      }
      expect(request.url.queryParameters['id'], 'original-match');
      return http.Response(
          '{"data":{"downloadUrl":"https://example.com/movie"}}', 200);
    });
    final metadata = await service.findUuidByTmdbId(
        tmdbId: 42,
        type: 'movie',
        title: 'Localized',
        alternativeTitles: ['Localized', 'Original', '']);
    expect(metadata?['uuid'], 'original-match');
    expect(queries, ['{"query":"Localized"}', '{"query":"Original"}']);
  });

  test('a catalogue outage does not prevent a working direct lookup', () async {
    final service = serviceFor((request) async {
      if (request.url.path.endsWith('/search')) return http.Response('{}', 503);
      return http.Response(
          '{"data":{"downloadUrl":"https://example.com/movie"}}', 200);
    });
    final metadata = await service.findUuidByTmdbId(
        tmdbId: 42, type: 'movie', title: 'A movie');
    expect(metadata?['downloadUrl'], 'https://example.com/movie');
  });

  test('search permission does not imply the details endpoint is denied',
      () async {
    final service = serviceFor((request) async {
      if (request.url.path.endsWith('/search')) {
        return http.Response('{}', 401,
            headers: {'x-moviehub-response-source': 'films365'});
      }
      return http.Response(
          '{"data":{"downloadUrl":"https://example.com/movie"}}', 200);
    });
    final metadata = await service.findUuidByTmdbId(
        tmdbId: 42, type: 'movie', title: 'A movie');
    expect(metadata?['downloadUrl'], 'https://example.com/movie');
  });

  test('catalogue provider ID is preferred when search is unavailable',
      () async {
    final requests = <http.Request>[];
    final service = serviceFor((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/search')) {
        return http.Response('{}', 401,
            headers: {'x-moviehub-response-source': 'films365'});
      }
      if (request.url.path.endsWith('/popular')) {
        return http.Response(
            '{"results":['
            '{"id":"wrong-series","tmdbId":42,"type":"tv"},'
            '{"id":"provider-movie","tmdbId":42,"type":"movie"}],"total_pages":1}',
            200);
      }
      expect(request.url.queryParameters,
          {'type': 'movie', 'id': 'provider-movie'});
      return http.Response(
          '{"data":{"downloadUrl":"https://example.com/movie"}}', 200);
    });
    final metadata = await service.findUuidByTmdbId(
        tmdbId: 42, type: 'movie', title: 'Movie');
    expect(metadata?['uuid'], 'provider-movie');
    expect(requests, hasLength(3));
    expect(
        requests.any(
            (request) => request.url.queryParameters.containsKey('tmdbId')),
        isFalse);
  });

  test('a denied catalogue provider record is not retried through TMDB',
      () async {
    var calls = 0;
    final service = serviceFor((request) async {
      calls++;
      if (request.url.path.endsWith('/search')) {
        return http.Response('{"results":{}}', 200);
      }
      if (request.url.path.endsWith('/popular')) {
        return http.Response(
            '{"results":[{"id":"provider-movie","tmdbId":42,"type":"movie"}]}',
            200);
      }
      return http.Response('{}', 401,
          headers: {'x-moviehub-response-source': 'films365'});
    });
    await expectLater(
        service.findUuidByTmdbId(tmdbId: 42, type: 'movie', title: 'Movie'),
        throwsA(isA<Films365RequestException>()
            .having((error) => error.statusCode, 'status', 401)));
    expect(calls, 3);
  });

  test('partial TMDB details resolve their provider ID to a downloadable file',
      () async {
    final service = serviceFor((request) async {
      if (request.url.queryParameters.containsKey('tmdbId')) {
        return http.Response(
            '{"data":{"id":"provider-id","title":"Movie"}}', 200);
      }
      expect(request.url.queryParameters['id'], 'provider-id');
      return http.Response(
          '{"data":{"downloadUrl":"https://example.com/movie"}}', 200);
    });
    final metadata = await service.findUuidByTmdbId(tmdbId: 42, type: 'movie');
    expect(metadata?['downloadUrl'], 'https://example.com/movie');
  });

  test('empty supplied provider details fall back to TMDB details', () async {
    final service = serviceFor((request) async {
      return http.Response(
          request.url.queryParameters.containsKey('id')
              ? '{"data":{}}'
              : '{"data":{"downloadUrl":"https://example.com/movie"}}',
          200);
    });
    final metadata = await service.findUuidByTmdbId(
        tmdbId: 42, type: 'movie', providerId: 'empty-record');
    expect(metadata?['downloadUrl'], 'https://example.com/movie');
  });

  test(
      'provider denial after exact search match stops without alternate requests',
      () async {
    var calls = 0;
    final service = serviceFor((request) async {
      calls++;
      if (request.url.path.endsWith('/search')) {
        return http.Response(
            '{"results":{"movies":[{"id":"provider-id","tmdbId":42}]}}', 200);
      }
      return http.Response('{}', 401,
          headers: {'x-moviehub-response-source': 'films365'});
    });
    await expectLater(
        service.findUuidByTmdbId(tmdbId: 42, type: 'movie', title: 'Movie'),
        throwsA(isA<Films365RequestException>()
            .having((error) => error.statusCode, 'status', 401)));
    expect(calls, 2);
  });

  test('reports provider denial immediately without scanning the catalogue',
      () async {
    var calls = 0;
    final service = Films365ApiService(
      client: MockClient((request) async {
        calls++;
        if (request.url.path.endsWith('/details')) {
          return http.Response('{}', 401,
              headers: {'x-moviehub-response-source': 'films365'});
        }
        return http.Response('{"results":[],"total_pages":1}', 200);
      }),
      apiBaseUrlProvider: () => 'https://backend.example',
      idTokenProvider: () async => 'token',
    );
    await expectLater(
      service.findUuidByTmdbId(tmdbId: 42, type: 'movie'),
      throwsA(isA<Films365RequestException>()
          .having((error) => error.statusCode, 'status', 401)
          .having((error) => error.source, 'source', 'films365')),
    );
    expect(calls, 1);
  });

  test('keeps matched movie metadata when provider supplies no file', () async {
    final service = Films365ApiService(
      client: MockClient((request) async => http.Response(
          '{"data":{"id":"provider-movie","title":"A movie"}}', 200)),
      apiBaseUrlProvider: () => 'https://backend.example',
      idTokenProvider: () async => 'token',
    );
    final result = await service.findUuidByTmdbId(
        tmdbId: 42, type: 'movie', providerId: 'provider-movie');
    expect(result?['uuid'], 'provider-movie');
    expect(result?['title'], 'A movie');
    expect(result?['downloadUrl'], isNull);
  });

  test('uses a known provider ID without a TMDB lookup', () async {
    final service = Films365ApiService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/mobile/details');
        expect(request.url.queryParameters,
            {'type': 'movie', 'id': 'provider-movie'});
        return http.Response(
            '{"data":{"downloadUrl":"https://example.com/movie.mp4"}}', 200);
      }),
      apiBaseUrlProvider: () => 'https://backend.example',
      idTokenProvider: () async => 'token',
    );
    final result = await service.findUuidByTmdbId(
        tmdbId: 42, type: 'movie', providerId: 'provider-movie');
    expect(result?['downloadUrl'], 'https://example.com/movie.mp4');
  });

  test('resolves a provider ID after a missing TMDB lookup', () async {
    final service = Films365ApiService(
      client: MockClient((request) async {
        if (request.url.queryParameters.containsKey('tmdbId')) {
          return http.Response('{}', 404,
              headers: {'x-moviehub-response-source': 'films365'});
        }
        if (request.url.path.endsWith('/trending')) {
          return http.Response(
              '{"results":[{"id":"provider-movie","tmdbId":42,"type":"movie"}],"total_pages":1}',
              200);
        }
        expect(request.url.queryParameters['id'], 'provider-movie');
        return http.Response(
            '{"data":{"downloadUrl":"https://example.com/movie.mp4"}}', 200);
      }),
      apiBaseUrlProvider: () => 'https://backend.example',
      idTokenProvider: () async => 'token',
    );
    final result = await service.findUuidByTmdbId(tmdbId: 42, type: 'movie');
    expect(result?['uuid'], 'provider-movie');
    expect(result?['downloadUrl'], 'https://example.com/movie.mp4');
  });

  test('uses a direct download without requiring a second UUID lookup',
      () async {
    var calls = 0;
    final service = Films365ApiService(
      client: MockClient((request) async {
        calls++;
        return http.Response(
          '{"data":{"downloadUrl":" https://example.com/movie.mp4 "}}',
          200,
        );
      }),
      apiBaseUrlProvider: () => 'https://backend.example',
      idTokenProvider: () async => 'token',
    );
    final result = await service.findUuidByTmdbId(tmdbId: 42, type: 'movie');
    expect(result?['downloadUrl'], 'https://example.com/movie.mp4');
    expect(calls, 1);
  });

  for (final status in [401, 403, 503]) {
    test('does not scan the catalogue after HTTP $status', () async {
      var calls = 0;
      final service = Films365ApiService(
        client: MockClient((request) async {
          calls++;
          return http.Response('private server details', status);
        }),
        apiBaseUrlProvider: () => 'https://backend.example',
        idTokenProvider: () async => 'token',
      );
      await expectLater(
        service.findUuidByTmdbId(tmdbId: 42, type: 'movie'),
        throwsA(isA<Films365RequestException>()
            .having((error) => error.statusCode, 'status', status)),
      );
      expect(calls, 1);
    });
  }

  test('a later attempt fetches a fresh link after a missing download',
      () async {
    var detailsCalls = 0;
    final service = Films365ApiService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/details')) {
          detailsCalls++;
          return http.Response(
            detailsCalls == 1
                ? '{}'
                : '{"data":{"downloadUrl":"https://example.com/fresh.mp4"}}',
            200,
          );
        }
        return http.Response('{"results":[],"total_pages":1}', 200);
      }),
      apiBaseUrlProvider: () => 'https://backend.example',
      idTokenProvider: () async => 'token',
    );

    expect(await service.findUuidByTmdbId(tmdbId: 42, type: 'movie'), isNull);
    final retry = await service.findUuidByTmdbId(tmdbId: 42, type: 'movie');
    expect(retry?['downloadUrl'], 'https://example.com/fresh.mp4');
    expect(detailsCalls, 2);
  });
}
