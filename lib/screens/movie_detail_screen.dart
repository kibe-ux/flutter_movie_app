import 'dart:async';

import 'package:flutter/material.dart';

import '../models/download_task.dart';
import '../models/movie.dart';
import '../services/movie_download_service.dart';
import 'downloaded_movies_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movieId});

  final String movieId;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  final MovieDownloadService _service = MovieDownloadService();

  Movie? _movie;
  String? _selectedQuality;
  bool _isLoading = true;
  String? _error;
  StreamSubscription<Map<String, DownloadTask>>? _downloadSub;
  Map<String, DownloadTask> _tasks = const {};

  @override
  void initState() {
    super.initState();
    _loadMovie();
    _downloadSub = _service.downloadTasksStream.listen((tasks) {
      if (!mounted) return;
      setState(() => _tasks = tasks);
    });
  }

  Future<void> _loadMovie() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final movie = await _service.fetchMovieDetails(widget.movieId);
      final qualities = movie.qualities.keys.toList()..sort();
      if (!mounted) return;
      setState(() {
        _movie = movie;
        _selectedQuality = qualities.isNotEmpty ? qualities.first : null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  DownloadTask? get _task {
    final movie = _movie;
    final quality = _selectedQuality;
    if (movie == null || quality == null) return null;
    final taskId = '${movie.id}::$quality'.toLowerCase();
    return _tasks[taskId];
  }

  Future<void> _onDownloadPressed() async {
    final movie = _movie;
    final quality = _selectedQuality;
    if (movie == null || quality == null) return;

    try {
      await _service.startDownload(movie: movie, quality: quality);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download started')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _movie == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Movie Details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64),
                const SizedBox(height: 12),
                Text(_error ?? 'Failed to load movie'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadMovie,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final movie = _movie!;
    final selectedQuality = _selectedQuality;
    final qualityInfo = selectedQuality != null ? movie.qualities[selectedQuality] : null;
    final task = _task;

    return Scaffold(
      appBar: AppBar(
        title: Text(movie.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_done_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DownloadedMoviesScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _poster(movie),
          const SizedBox(height: 16),
          Text(
            '${movie.title} (${movie.year})',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text('Quality'),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: selectedQuality,
            onChanged: (value) => setState(() => _selectedQuality = value),
            child: Column(
              children: movie.qualities.entries.map(
                (entry) => RadioListTile<String>(
                  value: entry.key,
                  title: Text(entry.key),
                  subtitle: Text(entry.value.formattedSize),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ).toList(),
            ),
          ),
          const SizedBox(height: 8),
          if (qualityInfo != null)
            Text(
              'File size: ${qualityInfo.formattedSize}',
              style: const TextStyle(color: Colors.white70),
            ),
          if (task != null) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: task.status == DownloadTaskStatus.completed ? 1 : task.progress),
            const SizedBox(height: 6),
            Text(_taskLabel(task)),
            if (task.errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(task.errorMessage!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: selectedQuality == null ? null : _onDownloadPressed,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: task == null ? null : () => _service.pauseDownload(task.id),
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: task == null ? null : () => _service.resumeDownload(task.id),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: task == null ? null : () => _service.cancelDownload(task.id),
            icon: const Icon(Icons.close),
            label: const Text('Cancel Download'),
          ),
        ],
      ),
    );
  }

  Widget _poster(Movie movie) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: movie.poster != null && movie.poster!.isNotEmpty
            ? Image.network(
                movie.poster!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackPoster(movie),
              )
            : _fallbackPoster(movie),
      ),
    );
  }

  Widget _fallbackPoster(Movie movie) {
    return Container(
      color: const Color(0xFF232323),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Text(
        movie.title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _taskLabel(DownloadTask task) {
    switch (task.status) {
      case DownloadTaskStatus.downloading:
        return 'Downloading ${(task.progress * 100).toStringAsFixed(0)}%';
      case DownloadTaskStatus.paused:
        return 'Paused';
      case DownloadTaskStatus.completed:
        return 'Completed';
      case DownloadTaskStatus.failed:
        return 'Failed';
      case DownloadTaskStatus.canceled:
        return 'Canceled';
      case DownloadTaskStatus.idle:
        return 'Idle';
    }
  }
}
