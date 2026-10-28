import 'package:flutter/foundation.dart';

void logHttpDiagnostic({
  required String endpoint,
  required int status,
  required Map<String, String> headers,
  String fallbackSource = 'unknown',
}) {
  if (!kDebugMode) return;
  const sources = {'firebase-auth', 'node-backend', 'films365'};
  final reportedSource = headers['x-moviehub-response-source'];
  final source =
      sources.contains(reportedSource) ? reportedSource! : fallbackSource;
  final requestId = headers['x-moviehub-request-id'];
  final backendInstance = headers['x-moviehub-backend-instance'];
  final uuid = RegExp(r'^[0-9a-fA-F-]{36}$');
  final trace = [
    if (requestId != null && uuid.hasMatch(requestId)) 'requestId=$requestId',
    if (backendInstance != null && uuid.hasMatch(backendInstance))
      'backendInstance=$backendInstance',
  ].join(' ');
  debugPrint('endpoint=$endpoint status=$status source=$source'
      '${trace.isEmpty ? '' : ' $trace'}');
}
