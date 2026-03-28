import 'dart:async';

import 'package:flutter/material.dart';

import '../models/download_task.dart';
import '../models/movie.dart';
import '../services/movie_download_service.dart';
import 'downloaded_movies_screen.dart';
import 'movie_detail_screen.dart';

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  final MovieDownloadService _service = MovieDownloadService();

  List<Movie> _movies = const [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription<Map<String, DownloadTask>>? _downloadSub;
  Map<String, DownloadTask> _tasks = const {};

  @override
  void initState() {
    super.initState();
    _loadMovies();
    _downloadSub = _service.downloadTasksStream.listen((tasks) {
      if (!mounted) return;
      setState(() => _tasks = tasks);
    });
  }

  Future<void> _loadMovies() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final movies = await _service.fetchMovies();
      if (!mounted) return;
      setState(() {
        _movies = movies;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    }
  }

  DownloadTask? _primaryTaskForMovie(Movie movie) {
    final movieTasks = _tasks.values
        .where((task) => task.movieId == movie.id)
        .toList(growable: false);
    if (movieTasks.isEmpty) return null;
    movieTasks.sort((a, b) => b.downloadedBytes.compareTo(a.downloadedBytes));
    return movieTasks.first;
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movie Downloads'),
        actions: [
          IconButton(
            tooltip: 'Downloaded movies',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DownloadedMoviesScreen()),
              );
            },
            icon: const Icon(Icons.download_done_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMovies,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _loadMovies,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (_movies.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 140),
          Center(
            child: Column(
              children: [
                Icon(Icons.movie_filter_outlined, size: 64),
                SizedBox(height: 8),
                Text('No movies found'),
              ],
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.64,
      ),
      itemCount: _movies.length,
      itemBuilder: (context, index) {
        final movie = _movies[index];
        final task = _primaryTaskForMovie(movie);
        return _MovieCard(
          movie: movie,
          task: task,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MovieDetailScreen(movieId: movie.id),
              ),
            );
          },
        );
      },
    );
  }
}

class _MovieCard extends StatelessWidget {
  const _MovieCard({
    required this.movie,
    required this.task,
    required this.onTap,
  });

  final Movie movie;
  final DownloadTask? task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF151515),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: movie.poster != null && movie.poster!.isNotEmpty
                      ? Image.network(
                          movie.poster!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallbackPoster(movie),
                        )
                      : _fallbackPoster(movie),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${movie.year} • ${movie.qualities.length} qualities',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    if (task != null) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: task!.status == DownloadTaskStatus.completed ? 1 : task!.progress,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _statusLabel(task!),
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackPoster(Movie movie) {
    return Container(
      color: const Color(0xFF202020),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          movie.title,
          textAlign: TextAlign.center,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String _statusLabel(DownloadTask task) {
    switch (task.status) {
      case DownloadTaskStatus.downloading:
        return 'Downloading ${(task.progress * 100).toStringAsFixed(0)}%';
      case DownloadTaskStatus.paused:
        return 'Paused';
      case DownloadTaskStatus.completed:
        return 'Downloaded';
      case DownloadTaskStatus.failed:
        return 'Failed';
      case DownloadTaskStatus.canceled:
        return 'Canceled';
      case DownloadTaskStatus.idle:
        return 'Idle';
    }
  }
}
