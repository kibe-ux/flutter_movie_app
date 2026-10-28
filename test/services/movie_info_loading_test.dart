import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/services/films365_api_service.dart';

void main() {
  Films365ApiService serviceFor(http.Client client,
          {DateTime Function()? now, Future<String?> Function()? token}) =>
      Films365ApiService(
          client: client,
          apiBaseUrlProvider: () => 'https://backend.example',
          idTokenProvider: token ?? () async => 'test-token',
          now: now);

  test('display info uses one direct lookup without catalogue discovery',
      () async {
    final requests = <http.Request>[];
    final service = serviceFor(MockClient((r) async {
      requests.add(r);
      return http.Response('{"data":{"synopsis":"A film","casts":[]}}', 200);
    }));
    final info = await service.findUuidByTmdbId(
        tmdbId: 42, type: 'movie', title: 'A film', metadataOnly: true);
    expect(info?['synopsis'], 'A film');
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/api/mobile/details');
    expect(
        requests.single.url.queryParameters, {'type': 'movie', 'tmdbId': '42'});
  });

  test('concurrent and repeat info lookups share one request', () async {
    var requests = 0;
    final response = Completer<http.Response>();
    final service = serviceFor(MockClient((_) {
      requests++;
      return response.future;
    }));
    final a =
        service.findUuidByTmdbId(tmdbId: 42, type: 'movie', metadataOnly: true);
    final b =
        service.findUuidByTmdbId(tmdbId: 42, type: 'movie', metadataOnly: true);
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    response.complete(http.Response('{"data":{"synopsis":"A film"}}', 200));
    await Future.wait([a, b]);
    final repeated = await service.findUuidByTmdbId(
        tmdbId: 42, type: 'movie', metadataOnly: true);
    expect(repeated?['synopsis'], 'A film');
    expect(requests, 1);
  });

  test('expired info and explicit refresh fetch again', () async {
    var now = DateTime(2026, 10, 28);
    var requests = 0;
    final service = serviceFor(MockClient((_) async {
      requests++;
      return http.Response('{"data":{"synopsis":"A film"}}', 200);
    }), now: () => now);
    await service.findUuidByTmdbId(
        tmdbId: 42, type: 'movie', metadataOnly: true);
    now = now.add(const Duration(minutes: 3));
    await service.findUuidByTmdbId(
        tmdbId: 42, type: 'movie', metadataOnly: true);
    await service.findUuidByTmdbId(
        tmdbId: 42, type: 'movie', metadataOnly: true, refresh: true);
    expect(requests, 3);
  });

  test('info is not reused after the Firebase token changes', () async {
    var token = 'first-token';
    var requests = 0;
    final service = serviceFor(MockClient((_) async {
      requests++;
      return http.Response('{"data":{"synopsis":"A film"}}', 200);
    }), token: () async => token);
    await service.findUuidByTmdbId(
        tmdbId: 42, type: 'movie', metadataOnly: true);
    token = 'second-token';
    await service.findUuidByTmdbId(
        tmdbId: 42, type: 'movie', metadataOnly: true);
    expect(requests, 2);
  });

  test('missing info does not scan lists and can be retried', () async {
    var requests = 0;
    final service = serviceFor(MockClient((_) async {
      requests++;
      return requests == 1
          ? http.Response('{}', 404)
          : http.Response('{"data":{"synopsis":"Available now"}}', 200);
    }));
    expect(
        await service.findUuidByTmdbId(
            tmdbId: 42, type: 'movie', metadataOnly: true),
        isNull);
    expect(requests, 1);
    final info = await service.findUuidByTmdbId(
        tmdbId: 42, type: 'movie', metadataOnly: true);
    expect(info?['synopsis'], 'Available now');
    expect(requests, 2);
  });

  test('authorization errors never trigger another metadata route', () async {
    var requests = 0;
    final service = serviceFor(MockClient((_) async {
      requests++;
      return http.Response('{"error":"Denied"}', 403);
    }));
    await expectLater(
        service.findUuidByTmdbId(
            tmdbId: 42, type: 'movie', title: 'A film', metadataOnly: true),
        throwsA(isA<Films365RequestException>()));
    expect(requests, 1);
  });

  test('download resolution bypasses display cache and fetches fresh details',
      () async {
    final requests = <http.Request>[];
    final service = serviceFor(MockClient((r) async {
      requests.add(r);
      return r.url.queryParameters.containsKey('tmdbId')
          ? http.Response(
              '{"data":{"id":"provider-42","synopsis":"A film"}}', 200)
          : http.Response(
              '{"data":{"downloadUrl":"https://files.example/movie.mp4"}}',
              200);
    }));
    await service.findUuidByTmdbId(
        tmdbId: 42, type: 'movie', metadataOnly: true);
    final download = await service.findUuidByTmdbId(tmdbId: 42, type: 'movie');
    expect(requests, hasLength(2));
    expect(requests.last.url.queryParameters['id'], 'provider-42');
    expect(download?['downloadUrl'], 'https://files.example/movie.mp4');
  });
}
