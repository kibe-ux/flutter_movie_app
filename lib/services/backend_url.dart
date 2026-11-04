import 'package:flutter/foundation.dart';

/// Validate before attaching Firebase credentials to a backend request.
String validateBackendUrl(String value, {bool allowLocalHttp = kDebugMode}) {
  final base = value.trim().replaceFirst(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(base);
  const localHosts = {
    'localhost',
    '127.0.0.1',
    '::1',
    '10.0.2.2',
    '10.0.3.2',
    '192.168.137.1',
  };
  if (uri == null ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      !(uri.scheme == 'https' ||
          (allowLocalHttp &&
              uri.scheme == 'http' &&
              localHosts.contains(uri.host)))) {
    throw StateError('A secure movie service address is required.');
  }
  return base;
}
