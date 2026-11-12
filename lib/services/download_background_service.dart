import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadBackgroundService {
  DownloadBackgroundService({this.enabled = true});
  final bool enabled;
  static const channel = MethodChannel('moviehub/downloads');
  Future<void> Function(String action, int? movieId)? onControl;
  bool _askedPermission = false;
  Future<void> _operations = Future.value();

  Future<void> _serial(Future<void> Function() action) {
    final result = _operations.then((_) => action());
    _operations = result.catchError((Object _) {});
    return result;
  }

  void initialize() {
    if (!enabled || !Platform.isAndroid) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'control') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        await onControl?.call(
            args['action'] as String, args['movieId'] as int?);
      }
    });
  }

  Future<void> start(int movieId, String title) => _serial(() async {
        if (!enabled || !Platform.isAndroid) return;
        if (!_askedPermission) {
          _askedPermission = true;
          await Permission.notification.request();
        }
        await channel
            .invokeMethod<void>('start', {'movieId': movieId, 'title': title});
      });

  Future<void> update(int movieId, String title, double progress) =>
      _serial(() async {
        if (!enabled || !Platform.isAndroid) return;
        await channel.invokeMethod<void>('update', {
          'movieId': movieId,
          'title': title,
          'percent': (progress * 100).round().clamp(0, 100)
        });
      });

  Future<void> stop() => _serial(() async {
        if (!enabled || !Platform.isAndroid) return;
        await channel.invokeMethod<void>('stop');
      });
}
