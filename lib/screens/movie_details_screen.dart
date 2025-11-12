import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

const String apiKey = '30e125ca82f6e71828b3a30c47ea67c2';
const String baseUrl = 'https://api.themoviedb.org/3';
const String imageBase = 'https://image.tmdb.org/t/p/w500';
const String backdropBase = 'https://image.tmdb.org/t/p/w780';
const String profileBase = 'https://image.tmdb.org/t/p/w185';

class MovieDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> movie;

  const MovieDetailsScreen({super.key, required this.movie});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  List<Map<String, dynamic>> cast = [];
  bool isLoadingCast = true;

  @override
  void initState() {
    super.initState();
    fetchCast();
  }

  Future<void> fetchCast() async {
    try {
      final movieId = widget.movie['id'];
      final response = await http.get(
        Uri.parse('$baseUrl/movie/$movieId/credits?api_key=$apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          cast = (data['cast'] as List?)
                  ?.take(12)
                  .map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [];
          isLoadingCast = false;
        });
      } else {
        setState(() {
          isLoadingCast = false;
        });
      }
    } catch (e) {
      print('Error fetching cast: $e');
      setState(() {
        isLoadingCast = false;
      });
    }
  }

  Widget _buildCastSection() {
    if (isLoadingCast) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
        ),
      );
    }

    if (cast.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Text(
            'Cast',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: cast.length,
            itemBuilder: (context, index) => _buildCastMember(cast[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildCastMember(Map<String, dynamic> person) {
    final profilePath = person['profile_path'];
    final imageUrl = profilePath != null ? '$profileBase$profilePath' : null;
    final character = person['character'] ?? 'Unknown';
    final name = person['name'] ?? 'Unknown';

    return Container(
      width: 100,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF00D4FF), Color(0xFF00FF88)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00D4FF).withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: const Color(0xFF1A1A1A),
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF00D4FF))),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFF1A1A1A),
                        child: const Icon(Icons.person_rounded,
                            color: Colors.white38, size: 30),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF1A1A1A),
                      child: const Icon(Icons.person_rounded,
                          color: Colors.white38, size: 30),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            character,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final backdropPath = movie['backdrop_path'];
    final backdropUrl =
        backdropPath != null ? '$backdropBase$backdropPath' : null;
    final posterPath = movie['poster_path'];
    final posterUrl = posterPath != null ? '$imageBase$posterPath' : null;
    final rating = ((movie['vote_average'] ?? 0.0) as num).toDouble();
    final year = _getYearFromDate(movie['release_date']);
    final duration = movie['runtime'] != null ? '${movie['runtime']} min' : '';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  backdropUrl != null
                      ? CachedNetworkImage(
                          imageUrl: backdropUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) => Container(
                            color: const Color(0xFF1A1A1A),
                            child: const Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFF00D4FF))),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFF1A1A1A),
                            child: const Icon(Icons.movie_rounded,
                                color: Colors.white38, size: 50),
                          ),
                        )
                      : Container(color: const Color(0xFF1A1A1A)),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          const Color(0xFF0A0A0A).withOpacity(0.95),
                          Colors.transparent,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: posterUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: posterUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: const Color(0xFF1A1A1A),
                                    child: const Center(
                                        child: CircularProgressIndicator(
                                            color: Color(0xFF00D4FF))),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    color: const Color(0xFF1A1A1A),
                                    child: const Icon(Icons.movie_rounded,
                                        color: Colors.white38, size: 40),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFF1A1A1A),
                                  child: const Icon(Icons.movie_rounded,
                                      color: Colors.white38, size: 40),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              movie['title'] ?? 'Unknown Title',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Colors.amber, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 16),
                                const Icon(Icons.calendar_today_rounded,
                                    color: Colors.white70, size: 18),
                                const SizedBox(width: 6),
                                Text(year,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 16)),
                              ],
                            ),
                            if (duration.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded,
                                      color: Colors.white70, size: 18),
                                  const SizedBox(width: 6),
                                  Text(duration,
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 16)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (movie['overview'] != null &&
                      movie['overview'].isNotEmpty) ...[
                    const Text(
                      'Overview',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      movie['overview'],
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _buildCastSection(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getYearFromDate(String? date) {
    if (date == null || date.isEmpty) return '';
    try {
      return DateTime.parse(date).year.toString();
    } catch (e) {
      return '';
    }
  }
}
