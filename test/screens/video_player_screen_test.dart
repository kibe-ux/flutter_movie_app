// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/screens/video_player_screen.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    as platform;

void main() {
  late platform.VideoPlayerPlatform originalPlatform;
  late FakeVideoPlayerPlatform fakePlatform;

  setUp(() {
    originalPlatform = platform.VideoPlayerPlatform.instance;
    fakePlatform = FakeVideoPlayerPlatform();
    platform.VideoPlayerPlatform.instance = fakePlatform;
  });

  tearDown(() async {
    platform.VideoPlayerPlatform.instance = originalPlatform;
    await fakePlatform.disposeAll();
  });

  testWidgets('loads and supports playback and bounded skip controls',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VideoPlayerScreen(videoUrl: 'https://example.test/video.mp4'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(VideoPlayer), findsOneWidget);

    final playCallsBeforeTap = fakePlatform.playCalls;
    await tester.tap(find.byIcon(Icons.play_circle));
    await tester.pump();
    expect(fakePlatform.playCalls, playCallsBeforeTap + 1);
    expect(find.byIcon(Icons.pause_circle), findsOneWidget);

    final pauseCallsBeforeTap = fakePlatform.pauseCalls;
    await tester.tap(find.byIcon(Icons.pause_circle));
    await tester.pump();
    expect(fakePlatform.pauseCalls, pauseCallsBeforeTap + 1);

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byIcon(Icons.forward_10));
      await tester.pump();
    }
    expect(fakePlatform.seekCalls.last, const Duration(seconds: 30));

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byIcon(Icons.replay_10));
      await tester.pump();
    }
    expect(fakePlatform.seekCalls.last, Duration.zero);
  });

  testWidgets('shows initialization errors and retries', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VideoPlayerScreen(videoUrl: ''),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load video:'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Failed to load video:'), findsOneWidget);
  });

  testWidgets('surfaces a playback error received after initialization',
      (tester) async {
    fakePlatform.playFailuresRemaining = 1;
    await tester.pumpWidget(
      const MaterialApp(
        home: VideoPlayerScreen(videoUrl: 'https://example.test/video.mp4'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(VideoPlayer), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_circle));
    await tester.pump();

    expect(find.textContaining('Playback failed:'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

class FakeVideoPlayerPlatform extends platform.VideoPlayerPlatform {
  int _nextPlayerId = 0;
  final Map<int, StreamController<platform.VideoEvent>> _events = {};
  final List<Duration> seekCalls = [];
  int playFailuresRemaining = 0;
  int playCalls = 0;
  int pauseCalls = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(platform.DataSource dataSource) async {
    final playerId = _nextPlayerId++;
    _events[playerId] = StreamController<platform.VideoEvent>();
    return playerId;
  }

  @override
  Stream<platform.VideoEvent> videoEventsFor(int playerId) {
    final events = _events[playerId]!;
    events.onListen = () {
      scheduleMicrotask(() {
        if (events.isClosed) return;
        events.add(
          platform.VideoEvent(
            eventType: platform.VideoEventType.initialized,
            duration: const Duration(seconds: 30),
            size: const Size(640, 360),
          ),
        );
      });
    };
    return events.stream;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> play(int playerId) async {
    playCalls++;
    if (playFailuresRemaining > 0) {
      playFailuresRemaining--;
      throw PlatformException(
        code: 'test-playback-error',
        message: 'test playback failed',
      );
    }
    _events[playerId]!.add(
      platform.VideoEvent(
        eventType: platform.VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async {
    pauseCalls++;
    _events[playerId]!.add(
      platform.VideoEvent(
        eventType: platform.VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    seekCalls.add(position);
  }

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> dispose(int playerId) async {
    final events = _events.remove(playerId);
    if (events != null && !events.isClosed) await events.close();
  }

  @override
  // ignore: deprecated_member_use
  Widget buildView(int playerId) => const SizedBox.shrink();

  @override
  Widget buildViewWithOptions(platform.VideoViewOptions options) =>
      const SizedBox.shrink();

  Future<void> disposeAll() async {
    for (final events in _events.values.toList()) {
      if (!events.isClosed) await events.close();
    }
    _events.clear();
  }
}
