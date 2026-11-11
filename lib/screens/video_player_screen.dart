import '../utils/cinema_palette.dart';
import '../widgets/cinema_app_bar_surface.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';
import 'package:file_selector/file_selector.dart';
import '../services/wambesha_api_service.dart';
import '../services/local_subtitle_service.dart';
import '../services/subtitle_import_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    this.videoUrl,
    this.localFilePath,
    this.videoUrlProvider,
    this.title,
    this.onGoToDownload,
  }) : assert(videoUrl != null ||
            localFilePath != null ||
            videoUrlProvider != null);

  final String? videoUrl;
  final String? localFilePath;
  final Future<String> Function(bool refresh)? videoUrlProvider;
  final String? title;
  final VoidCallback? onGoToDownload;

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
  List<File> _subtitleTracks = [];
  String? _selectedSubtitle;
  int _subtitleAttempt = 0;
  bool _importingSubtitle = false;
  String? _importedSubtitlePath;
  final _subtitleImports = SubtitleImportService();

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
        final videoUrl = widget.videoUrlProvider != null
            ? (await widget.videoUrlProvider!(attempt > 1)).trim()
            : widget.videoUrl?.trim();
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

      if (widget.localFilePath != null) {
        _subtitleTracks =
            await LocalSubtitleService.discover(widget.localFilePath!);
        try {
          final imported =
              await _subtitleImports.savedFor(widget.localFilePath!);
          _importedSubtitlePath = imported?.path;
          if (imported != null) _subtitleTracks.insert(0, imported);
        } catch (_) {/* Storage failure must not prevent video playback. */}
        _selectedSubtitle = null;
        for (final track in _subtitleTracks) {
          try {
            await controller
                .setClosedCaptionFile(LocalSubtitleService.load(track));
            _selectedSubtitle = track.path;
            break;
          } catch (_) {/* Try the next local track; video remains playable. */}
        }
      }

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
      var message = widget.videoUrlProvider == null
          ? 'Failed to load video: $error'
          : error is WambeshaSourceUnavailable
              ? error.message
              : error is WambeshaRequestException
                  ? error.message
                  : 'Failed to load video. Please retry to request a fresh playback link.';
      try {
        await controller?.dispose();
      } catch (disposeError) {
        if (widget.videoUrlProvider == null) {
          message = '$message\nFailed to release video player: $disposeError';
        }
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
    final message = widget.videoUrlProvider == null
        ? 'Playback failed: $error'
        : 'Playback failed. Please retry to request a fresh playback link.';
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
    _subtitleAttempt++;
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
    _subtitleAttempt++;
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

  Future<void> _selectSubtitle(String path) async {
    if (path == ':import') {
      await _importSubtitle();
      return;
    }
    final controller = _controller;
    if (controller == null) return;
    final attempt = ++_subtitleAttempt;
    try {
      final captions =
          path.isEmpty ? null : await LocalSubtitleService.load(File(path));
      if (!mounted ||
          attempt != _subtitleAttempt ||
          controller != _controller) {
        return;
      }
      await controller.setClosedCaptionFile(
          captions == null ? null : Future.value(captions));
      if (mounted && attempt == _subtitleAttempt) {
        setState(() => _selectedSubtitle = path.isEmpty ? null : path);
      }
    } catch (_) {
      if (mounted && attempt == _subtitleAttempt) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not load this subtitle file.')));
      }
    }
  }

  Future<void> _importSubtitle() async {
    final videoPath = widget.localFilePath;
    if (_importingSubtitle || videoPath == null) return;
    _importingSubtitle = true;
    _cancelControlsHide();
    try {
      final selected = await openFile(acceptedTypeGroups: [
        const XTypeGroup(
            label: 'Subtitles',
            extensions: ['vtt', 'srt'],
            uniformTypeIdentifiers: ['public.text']),
      ]);
      if (selected == null || !mounted) return;
      final file = await _subtitleImports.importFile(videoPath, selected);
      if (!mounted) return;
      setState(() {
        _subtitleTracks
            .removeWhere((track) => track.path == _importedSubtitlePath);
        _importedSubtitlePath = file.path;
        _subtitleTracks.insert(0, file);
      });
      await _selectSubtitle(file.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not import subtitles. Choose a valid UTF-8 VTT or SRT file under 2 MB.')));
      }
    } finally {
      _importingSubtitle = false;
      if (mounted && _showControls && _isPlaying) _scheduleControlsHide();
    }
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
              elevation: 0,
              scrolledUnderElevation: 0,
              foregroundColor: CinemaPalette.ivory,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: const CinemaAppBarSurface(),
              backgroundColor: CinemaPalette.background,
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
    if (widget.title != null && widget.title!.trim().isNotEmpty) {
      return widget.title!.trim();
    }
    if (widget.localFilePath != null) {
      return p.basenameWithoutExtension(widget.localFilePath!);
    }
    return 'Video Player';
  }

  Widget _buildErrorWidget() {
    final isStreamingUnavailable = _errorMessage != null &&
        (_errorMessage!.contains('Online streaming is not available') ||
            _errorMessage!.contains('download for offline viewing') ||
            _errorMessage!.contains('tap Download') ||
            _errorMessage!.contains('No confirmed playback source'));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isStreamingUnavailable
                ? Icons.offline_pin_outlined
                : Icons.error_outline,
            size: 64,
            color: isStreamingUnavailable ? CinemaPalette.gold : Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Error loading video',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          if (isStreamingUnavailable && widget.onGoToDownload != null) ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onGoToDownload?.call();
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('Save Offline Instead'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CinemaPalette.gold,
                foregroundColor: CinemaPalette.background,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _retryVideo,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Stream'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
              ),
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: _retryVideo,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF),
              ),
            ),
          ],
        ],
      ),
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
        Positioned(
          left: 16,
          right: 16,
          bottom: _showControls ? 120 : 24,
          child: IgnorePointer(
              child: ClosedCaption(text: _controller!.value.caption.text)),
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
                  if (widget.localFilePath != null)
                    PopupMenuButton<String>(
                      tooltip: 'Subtitles',
                      initialValue: _selectedSubtitle ?? '',
                      icon: Icon(Icons.subtitles_outlined,
                          color: _selectedSubtitle == null
                              ? Colors.white70
                              : CinemaPalette.gold),
                      onSelected: _selectSubtitle,
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: '', child: Text('Off')),
                        const PopupMenuItem(
                            value: ':import',
                            child: Text('Choose subtitle file…')),
                        for (final track in _subtitleTracks)
                          PopupMenuItem(
                              value: track.path,
                              child: Text(track.path == _importedSubtitlePath
                                  ? 'Imported subtitles'
                                  : p.basenameWithoutExtension(track.path))),
                      ],
                    ),
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
