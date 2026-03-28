import 'package:flutter/material.dart';

import 'downloaded_movies_screen.dart';
import 'movie_list_screen.dart';
import 'profile_screen.dart';

class MovieDownloadShellScreen extends StatefulWidget {
  const MovieDownloadShellScreen({super.key});

  @override
  State<MovieDownloadShellScreen> createState() => _MovieDownloadShellScreenState();
}

class _MovieDownloadShellScreenState extends State<MovieDownloadShellScreen> {
  int _index = 0;

  static const List<Widget> _tabs = [
    MovieListScreen(),
    DownloadedMoviesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.movie), label: 'Movies'),
          NavigationDestination(icon: Icon(Icons.download), label: 'Downloaded'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
