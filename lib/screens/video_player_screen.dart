import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    this.videoUrl,
    this.localFilePath,
  }) : assert(videoUrl != null || localFilePath != null);

  final String? videoUrl;
  final String? localFilePath;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  String? _errorMessage;
  bool _isBuffering = false;
  double _playbackSpeed = 1.0;
  bool _showControls = true;
  bool _isFullscreen = false;
  int _initializationAttempt = 0;
  Timer? _controlsHideTimer;
  Duration? _lastReportedPosition;
  bool? _lastReportedPlaying;

  bool get _isPlaying => _controller?.value.isPlaying ?? false;
  Duration get _position => _controller?.value.position ?? Duration.zero;
  Duration get _duration => _controller?.value.duration ?? Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final attempt = ++_initializationAttempt;
    VideoPlayerController? controller;
    try {
      if (widget.localFilePath != null) {
        controller = VideoPlayerController.file(File(widget.localFilePath!));
      } else {
        final videoUrl = widget.videoUrl?.trim();
        if (videoUrl == null || videoUrl.isEmpty) {
          throw ArgumentError.value(videoUrl, 'videoUrl', 'Must not be empty.');
        }
        final uri = Uri.parse(videoUrl);
        if (!uri.hasScheme) {
          throw FormatException('Video URL must be absolute.', videoUrl);
        }
        controller = VideoPlayerController.networkUrl(uri);
      }

      await controller.initialize();
      await controller.setLooping(false);
      await controller.setPlaybackSpeed(_playbackSpeed);

      if (!mounted || attempt != _initializationAttempt) {
        await controller.dispose();
        return;
      }

      controller.addListener(_onControllerUpdate);

      setState(() {
        _controller = controller;
        _errorMessage = null;
        _isBuffering = controller!.value.isBuffering;
        _lastReportedPosition = controller.value.position;
        _lastReportedPlaying = controller.value.isPlaying;
      });
    } catch (error) {
      var message = 'Failed to load video: $error';
      try {
        await controller?.dispose();
      } catch (disposeError) {
        message = '$message\nFailed to release video player: $disposeError';
      }
      if (!mounted || attempt != _initializationAttempt) return;
      setState(() {
        _errorMessage = message;
      });
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    final controller = _controller;
    if (controller == null) return;

    final value = controller.value;
    if (value.errorDescription != null) {
      _showPlaybackError(value.errorDescription!);
      return;
    }

    if (_isBuffering != value.isBuffering ||
        _lastReportedPosition != value.position ||
        _lastReportedPlaying != value.isPlaying) {
      setState(() {
        _isBuffering = value.isBuffering;
        _lastReportedPosition = value.position;
        _lastReportedPlaying = value.isPlaying;
      });
    }

    if (_showControls && _isPlaying && !_isBuffering) {
      _scheduleControlsHide();
    } else {
      _cancelControlsHide();
    }
  }

  void _scheduleControlsHide() {
    if (_controlsHideTimer != null) return;

    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      _controlsHideTimer = null;
      if (mounted && _isPlaying && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  void _cancelControlsHide() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = null;
  }

  void _showPlaybackError(Object error) {
    if (!mounted) return;
    _cancelControlsHide();
    final message = 'Playback failed: $error';
    if (_errorMessage == message) return;
    setState(() {
      _errorMessage = message;
      _isBuffering = false;
    });
  }

  Future<void> _runPlayerAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      _showPlaybackError(error);
    }
  }

  @override
  void dispose() {
    _initializationAttempt++;
    _cancelControlsHide();
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onControllerUpdate);
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        await controller.play();
      }
      if (mounted) setState(() {});
    } catch (error) {
      _showPlaybackError(error);
    }
  }

  void _setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    setState(() {});
    final controller = _controller;
    if (controller != null) {
      unawaited(_runPlayerAction(() => controller.setPlaybackSpeed(speed)));
    }
  }

  Future<void> _seekTo(Duration position) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final duration = controller.value.duration;
    final boundedPosition = position < Duration.zero
        ? Duration.zero
        : position > duration
            ? duration
            : position;
    await _runPlayerAction(() => controller.seekTo(boundedPosition));
  }

  Future<void> _skipForward() async {
    final newPosition = _position + const Duration(seconds: 10);
    await _seekTo(newPosition);
  }

  Future<void> _skipBackward() async {
    final newPosition = _position - const Duration(seconds: 10);
    await _seekTo(newPosition);
  }

  Future<void> _retryVideo() async {
    _initializationAttempt++;
    _cancelControlsHide();
    final previousController = _controller;
    previousController?.removeListener(_onControllerUpdate);
    setState(() {
      _controller = null;
      _errorMessage = null;
      _isBuffering = false;
      _lastReportedPosition = null;
      _lastReportedPlaying = null;
    });

    try {
      await previousController?.dispose();
    } catch (error) {
        if (mounted) {
        setState(() => _errorMessage = 'Failed to restart video: $error');
      }
      return;
    }
    if (mounted) await _initializeVideo();
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    // In a real app, you'd handle orientation changes here
  }

  void _onTapScreen() {
    setState(() => _showControls = !_showControls);
    if (_showControls && _isPlaying) {
      _scheduleControlsHide();
    } else {
      _cancelControlsHide();
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isFullscreen
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              title: Text(_title),
            ),
      body: GestureDetector(
        onTap: _onTapScreen,
        child: Center(
          child: _errorMessage != null
              ? _buildErrorWidget()
              : _controller != null && _controller!.value.isInitialized
                  ? _buildVideoPlayer()
                  : const CircularProgressIndicator(color: Color(0xFF00D4FF)),
        ),
      ),
    );
  }

  String get _title {
    if (widget.localFilePath != null) {
      return p.basenameWithoutExtension(widget.localFilePath!);
    }
    return 'Video Player';
  }

  Widget _buildErrorWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text(
          _errorMessage ?? 'Error loading video',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _retryVideo,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00D4FF),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPlayer() {
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),

        // Buffering indicator
        if (_isBuffering)
          const CircularProgressIndicator(color: Color(0xFF00D4FF)),

        // Controls overlay
        if (_showControls) ...[
          // Top controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(_isFullscreen
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen),
                    color: Colors.white,
                    onPressed: _toggleFullscreen,
                  ),
                  const Spacer(),
                  PopupMenuButton<double>(
                    icon: const Icon(Icons.speed, color: Colors.white),
                    tooltip: 'Playback Speed',
                    onSelected: _setPlaybackSpeed,
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 0.5, child: Text('0.5x')),
                      const PopupMenuItem(value: 0.75, child: Text('0.75x')),
                      const PopupMenuItem(
                          value: 1.0, child: Text('1x (Normal)')),
                      const PopupMenuItem(value: 1.25, child: Text('1.25x')),
                      const PopupMenuItem(value: 1.5, child: Text('1.5x')),
                      const PopupMenuItem(value: 2.0, child: Text('2x')),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Center play/pause button
          Positioned(
            child: IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause_circle : Icons.play_circle,
                size: 72,
                color: Colors.white70,
              ),
              onPressed: _togglePlay,
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress bar
                  VideoProgressIndicator(
                    _controller!,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Color(0xFF00D4FF),
                      bufferedColor: Colors.white30,
                      backgroundColor: Colors.white12,
                    ),
                  ),

                  // Time and controls row
                  Row(
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Text(' / ',
                          style: TextStyle(color: Colors.white70)),
                      Text(
                        _formatDuration(_duration),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.replay_10, color: Colors.white),
                        onPressed: _skipBackward,
                      ),
                      IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                        ),
                        onPressed: _togglePlay,
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_10, color: Colors.white),
                        onPressed: _skipForward,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
