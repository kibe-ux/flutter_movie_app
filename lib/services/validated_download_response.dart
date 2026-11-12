import 'package:http/http.dart' as http;

/// Identity belongs to the bytes, not to a signed URL (which can be renewed).
class ValidatedDownloadResponse {
  const ValidatedDownloadResponse(this.response, this.append, this.totalBytes,
      this.etag, this.expectedBodyBytes);
  final http.StreamedResponse response;
  final bool append;
  final int totalBytes;
  final String? etag;
  final int? expectedBodyBytes;
}

String? _strongETag(String? value) {
  if (value == null) return null;
  final tag = value.trim();
  return RegExp(r'^"[\x21\x23-\x7E\x80-\xFF]*"$').hasMatch(tag) ? tag : null;
}

int? _bodyLength(http.StreamedResponse response) =>
    response.contentLength ??
    int.tryParse(response.headers['content-length'] ?? '');

Future<void> _discard(http.StreamedResponse response) =>
    response.stream.listen((_) {}).cancel();

/// A rejected range is discarded before its body can reach the partial file.
/// The fallback uses the SAME delivery URL, not another metered source lookup.
Future<ValidatedDownloadResponse> openValidatedDownload({
  required http.Client client,
  required Uri uri,
  required int offset,
  required int savedTotalBytes,
  required String? savedETag,
}) async {
  Future<http.StreamedResponse> send({bool resume = false}) {
    final request = http.Request('GET', uri);
    request.headers['Accept-Encoding'] = 'identity';
    if (resume) {
      request.headers['Range'] = 'bytes=$offset-';
      request.headers['If-Range'] = savedETag!.trim();
    }
    return client.send(request).timeout(const Duration(seconds: 30));
  }

  final canResume =
      offset > 0 && offset < savedTotalBytes && _strongETag(savedETag) != null;
  var response = await send(resume: canResume);
  if (canResume && response.statusCode == 206) {
    final match = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$')
        .firstMatch(response.headers['content-range'] ?? '');
    final start = int.tryParse(match?.group(1) ?? '');
    final end = int.tryParse(match?.group(2) ?? '');
    final total = int.tryParse(match?.group(3) ?? '');
    final length = _bodyLength(response);
    final encoding = response.headers['content-encoding'];
    if (start == offset &&
        end != null &&
        total != null &&
        total == savedTotalBytes &&
        end >= offset &&
        end < total &&
        length == end - offset + 1 &&
        _strongETag(response.headers['etag']) == _strongETag(savedETag) &&
        (encoding == null || encoding.toLowerCase() == 'identity')) {
      return ValidatedDownloadResponse(
          response, true, total, _strongETag(response.headers['etag']), length);
    }
    await _discard(response);
    response = await send();
  } else if (canResume && response.statusCode == 416) {
    await _discard(response);
    response = await send();
  }

  // A server honoring If-Range may answer 200 directly when the file changed.
  // A fresh GET must never be accepted as an unsolicited partial response.
  if (response.statusCode != 200) {
    await _discard(response);
    throw const FormatException('The file could not be downloaded safely.');
  }
  final encoding = response.headers['content-encoding'];
  if (encoding != null && encoding.toLowerCase() != 'identity') {
    await _discard(response);
    throw const FormatException('Unexpected file encoding.');
  }
  final length = _bodyLength(response);
  return ValidatedDownloadResponse(response, false, length ?? 0,
      _strongETag(response.headers['etag']), length);
}
