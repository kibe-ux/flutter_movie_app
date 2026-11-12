import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/services/validated_download_response.dart';

void main() {
  final uri = Uri.parse('https://delivery.example/movie?signature=private');
  http.StreamedResponse reply(int status, Map<String, String> headers) =>
      http.StreamedResponse(Stream.value([7, 8, 9]), status, headers: headers);

  Future<ValidatedDownloadResponse> open(http.Client client,
          {String? tag = '"old"', int size = 6}) =>
      openValidatedDownload(
          client: client,
          uri: uri,
          offset: 3,
          savedTotalBytes: size,
          savedETag: tag);

  test('matching identity resumes using full size from Content-Range',
      () async {
    final client = MockClient.streaming((request, _) async {
      expect(request.headers['range'], 'bytes=3-');
      expect(request.headers['if-range'], '"old"');
      expect(request.headers['accept-encoding'], 'identity');
      return reply(206, {
        'etag': '"old"',
        'content-range': 'bytes 3-5/6',
        'content-length': '3'
      });
    });
    final result = await open(client);
    expect(result.append, isTrue);
    expect(result.totalBytes, 6);
    expect(result.expectedBodyBytes, 3);
    expect(await result.response.stream.toBytes(), [7, 8, 9]);
    client.close();
  });

  final invalidRanges = <String, Map<String, String>>{
    'changed ETag': {'etag': '"new"'},
    'changed full length': {
      'content-range': 'bytes 3-6/7',
      'content-length': '4'
    },
    'wrong offset': {'content-range': 'bytes 2-4/6'},
    'malformed range': {'content-range': 'bytes */6'},
    'wrong body length': {'content-length': '2'},
    'weak new ETag': {'etag': 'W/"old"'},
    'encoded bytes': {'content-encoding': 'gzip'},
  };
  for (final entry in invalidRanges.entries) {
    test('${entry.key} discards range and restarts on same delivery URL',
        () async {
      var calls = 0;
      final client = MockClient.streaming((request, _) async {
        expect(request.url, uri);
        if (++calls == 1) {
          return reply(206, {
            'etag': '"old"',
            'content-range': 'bytes 3-5/6',
            'content-length': '3',
            ...entry.value
          });
        }
        expect(request.headers.containsKey('range'), isFalse);
        expect(request.headers.containsKey('if-range'), isFalse);
        return reply(200, {'etag': '"new"', 'content-length': '3'});
      });
      final result = await open(client);
      expect(calls, 2);
      expect(result.append, isFalse);
      expect(result.etag, '"new"');
      expect(await result.response.stream.toBytes(), [7, 8, 9]);
      client.close();
    });
  }

  for (final tag in [null, 'W/"old"', 'unquoted']) {
    test('unusable saved validator $tag requests whole file directly',
        () async {
      final client = MockClient.streaming((request, _) async {
        expect(request.headers.containsKey('range'), isFalse);
        return reply(200, {'content-length': '3'});
      });
      final result = await open(client, tag: tag);
      expect(result.append, isFalse);
      await result.response.stream.drain<void>();
      client.close();
    });
  }

  test('200 to a range request restarts without another request', () async {
    var calls = 0;
    final client = MockClient.streaming((request, _) async {
      calls++;
      return reply(200, {'etag': '"new"', 'content-length': '3'});
    });
    final result = await open(client);
    expect(result.append, isFalse);
    expect(calls, 1);
    await result.response.stream.drain<void>();
    client.close();
  });

  test('416 retries once and refuses another partial response', () async {
    var calls = 0;
    final client = MockClient.streaming((request, _) async {
      return reply(++calls == 1 ? 416 : 206, {});
    });
    await expectLater(open(client), throwsFormatException);
    expect(calls, 2);
    client.close();
  });
}
