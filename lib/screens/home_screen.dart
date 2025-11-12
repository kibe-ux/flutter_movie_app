import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'movie_details_screen.dart';
import 'explore_screen.dart';
import 'search_screen.dart';

const String apiKey = '30e125ca82f6e71828b3a30c47ea67c2';
const String baseUrl = 'https://api.themoviedb.org/3';
const String imageBase = 'https://image.tmdb.org/t/p/w780';
const String backdropBase = 'https://image.tmdb.org/t/p/w1280';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool isLoading = true;

  // Expanded movie categories - 40 categories total!
  List<dynamic> trendingMovies = [];
  List<dynamic> popularMovies = [];
  List<dynamic> nowPlayingMovies = [];
  List<dynamic> topRatedMovies = [];
  List<dynamic> upcomingMovies = [];
  List<dynamic> actionMovies = [];
  List<dynamic> comedyMovies = [];
  List<dynamic> dramaMovies = [];
  List<dynamic> horrorMovies = [];
  List<dynamic> romanceMovies = [];
  List<dynamic> scifiMovies = [];
  List<dynamic> thrillerMovies = [];
  List<dynamic> adventureMovies = [];
  List<dynamic> animationMovies = [];
  List<dynamic> fantasyMovies = [];
  List<dynamic> mysteryMovies = [];
  List<dynamic> crimeMovies = [];
  List<dynamic> documentaryMovies = [];
  List<dynamic> familyMovies = [];
  List<dynamic> historyMovies = [];
  List<dynamic> musicMovies = [];
  List<dynamic> warMovies = [];
  List<dynamic> westernMovies = [];
  List<dynamic> tvMovies = [];
  List<dynamic> bollywoodMovies = [];

  // NEW CATEGORIES
  List<dynamic> superheroMovies = [];
  List<dynamic> martialArtsMovies = [];
  List<dynamic> spyMovies = [];
  List<dynamic> heistMovies = [];
  List<dynamic> disasterMovies = [];
  List<dynamic> sportsMovies = [];
  List<dynamic> politicalMovies = [];
  List<dynamic> courtroomMovies = [];
  List<dynamic> noirMovies = [];
  List<dynamic> slasherMovies = [];
  List<dynamic> paranormalMovies = [];
  List<dynamic> zombieMovies = [];
  List<dynamic> indieMovies = [];
  List<dynamic> cultMovies = [];
  List<dynamic> awardWinningMovies = [];

  final List<Widget> _screens = const [
    SizedBox(),
    ExploreScreen(),
    SearchScreen(),
  ];

  // Netflix-like color scheme
  final Color _netflixRed = const Color(0xFFE50914);
  final Color _netflixBlack = const Color(0xFF141414);
  final Color _netflixDarkGray = const Color(0xFF2D2D2D);
  final Color _netflixWhite = Colors.white;

  // Expanded vibrant color palette for 40 categories
  final List<Color> _categoryColors = [
    const Color(0xFFFF006E), // Magenta Pink
    const Color(0xFF8338EC), // Electric Purple
    const Color(0xFF3A86FF), // Bright Blue
    const Color(0xFFFB5607), // Vibrant Orange
    const Color(0xFFFFBE0B), // Sunshine Yellow
    const Color(0xFF06D6A0), // Emerald Green
    const Color(0xFFEF476F), // Hot Pink
    const Color(0xFF118AB2), // Ocean Blue
    const Color(0xFF7209B7), // Royal Purple
    const Color(0xFFF15BB5), // Bubblegum Pink
    const Color(0xFF00BBF9), // Cyan
    const Color(0xFF00F5D4), // Turquoise
    const Color(0xFFFF0054), // Ruby Red
    const Color(0xFF9B5DE5), // Lavender
    const Color(0xFFFEE440), // Lemon Yellow
    const Color(0xFFFF6B6B), // Coral
    const Color(0xFF4ECDC4), // Teal
    const Color(0xFF1A936F), // Forest Green
    const Color(0xFF114B5F), // Deep Blue
    const Color(0xFFC44536), // Rust Red
    const Color(0xFFE56B70), // Salmon Pink
    const Color(0xFF5F0F40), // Plum
    const Color(0xFF9A031E), // Crimson
    const Color(0xFFFB8B24), // Tangerine
    // NEW COLORS
    const Color(0xFF560BAD), // Deep Purple
    const Color(0xFFB5179E), // Fuchsia
    const Color(0xFFF72585), // Raspberry
    const Color(0xFF480CA8), // Violet
    const Color(0xFF4CC9F0), // Sky Blue
    const Color(0xFF4361EE), // Electric Blue
    const Color(0xFF38B000), // Lime Green
    const Color(0xFF70E000), // Neon Green
    const Color(0xFF9EF01A), // Chartreuse
    const Color(0xFFCCFF33), // Electric Lime
    const Color(0xFF80ED99), // Mint Green
    const Color(0xFF57CC99), // Jade
    const Color(0xFF22577A), // Navy Blue
    const Color(0xFF38A3A5), // Sea Green
    const Color(0xFFF77F00), // Orange Red
    const Color(0xFFD62828), // Fire Red
  ];

  // Category titles with UNIQUE emojis for each category - 40 categories
  final List<String> _categoryTitles = [
    '🔥 Trending Now',
    '🎬 Now in Cinemas',
    '🌟 Most Popular',
    '⭐ Top Rated',
    '🚀 Coming Soon',
    '💥 Action Packed',
    '😂 Comedy Gold',
    '🎭 Powerful Drama',
    '👻 Horror Thrills',
    '💖 Romantic Tales',
    '👽 Sci-Fi Worlds',
    '🔪 Edge Thrillers',
    '🏔️ Epic Adventures',
    '🐰 Animated Magic',
    '🧙‍♂️ Fantasy Realms',
    '🕵️ Mystery Cases',
    '🔫 Crime Stories',
    '📹 Real Documentaries',
    '👨‍👩‍👧‍👦 Family Fun',
    '📜 Historical Epics',
    '🎵 Musical Hits',
    '⚔️ War Stories',
    '🤠 Western Classics',
    '📺 TV Movies',
    '🎭 Bollywood Hits',
    // NEW CATEGORIES with unique emojis
    '🦸 Superhero Saga',
    '🥋 Martial Arts',
    '🕶️ Spy Thrillers',
    '💰 Heist Capers',
    '🌪️ Disaster Flicks',
    '⚽ Sports Drama',
    '🏛️ Political Thrills',
    '⚖️ Courtroom Drama',
    '🎩 Film Noir',
    '🔪 Slasher Horror',
    '👻 Paranormal Tales',
    '🧟 Zombie Apocalypse',
    '🎨 Indie Gems',
    '🤘 Cult Classics',
    '🏆 Award Winners',
  ];

  @override
  void initState() {
    super.initState();
    fetchAllMovies();
  }

  Future<void> fetchAllMovies() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/trending/movie/day?api_key=$apiKey')),
        http.get(Uri.parse('$baseUrl/movie/popular?api_key=$apiKey')),
        http.get(Uri.parse('$baseUrl/movie/now_playing?api_key=$apiKey')),
        http.get(Uri.parse('$baseUrl/movie/top_rated?api_key=$apiKey')),
        http.get(Uri.parse('$baseUrl/movie/upcoming?api_key=$apiKey')),
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=28')),
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=35')),
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=18')),
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=27')),
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=10749')),
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=878')),
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=53')),
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=12')),
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=16')),
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=14')),
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=9648')),
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=80')),
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=99')),
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=10751')),
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=36')),
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=10402')),
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=10752')),
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=37')),
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=10770')),
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_original_language=hi')),
        // NEW CATEGORY API CALLS
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=9715')), // Superhero
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=14440')), // Martial Arts
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=10702')), // Spy
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=10496')), // Heist
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=9747')), // Disaster
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=10770&with_keywords=10849')), // Sports
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=9717')), // Political
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=10534')), // Courtroom
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=10495')), // Film Noir
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=10504')), // Slasher
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=10508')), // Paranormal
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=10510')), // Zombie
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=9749')), // Indie
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&vote_average.gte=7.5&vote_count.gte=1000')), // Cult Classics
        http.get(Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=10511')), // Award Winning
      ]);

      if (mounted) {
        setState(() {
          trendingMovies = _parseMovies(responses[0]);
          popularMovies = _parseMovies(responses[1]);
          nowPlayingMovies = _parseMovies(responses[2]);
          topRatedMovies = _parseMovies(responses[3]);
          upcomingMovies = _parseMovies(responses[4]);
          actionMovies = _parseMovies(responses[5]);
          comedyMovies = _parseMovies(responses[6]);
          dramaMovies = _parseMovies(responses[7]);
          horrorMovies = _parseMovies(responses[8]);
          romanceMovies = _parseMovies(responses[9]);
          scifiMovies = _parseMovies(responses[10]);
          thrillerMovies = _parseMovies(responses[11]);
          adventureMovies = _parseMovies(responses[12]);
          animationMovies = _parseMovies(responses[13]);
          fantasyMovies = _parseMovies(responses[14]);
          mysteryMovies = _parseMovies(responses[15]);
          crimeMovies = _parseMovies(responses[16]);
          documentaryMovies = _parseMovies(responses[17]);
          familyMovies = _parseMovies(responses[18]);
          historyMovies = _parseMovies(responses[19]);
          musicMovies = _parseMovies(responses[20]);
          warMovies = _parseMovies(responses[21]);
          westernMovies = _parseMovies(responses[22]);
          tvMovies = _parseMovies(responses[23]);
          bollywoodMovies = _parseMovies(responses[24]);
          // NEW CATEGORIES
          superheroMovies = _parseMovies(responses[25]);
          martialArtsMovies = _parseMovies(responses[26]);
          spyMovies = _parseMovies(responses[27]);
          heistMovies = _parseMovies(responses[28]);
          disasterMovies = _parseMovies(responses[29]);
          sportsMovies = _parseMovies(responses[30]);
          politicalMovies = _parseMovies(responses[31]);
          courtroomMovies = _parseMovies(responses[32]);
          noirMovies = _parseMovies(responses[33]);
          slasherMovies = _parseMovies(responses[34]);
          paranormalMovies = _parseMovies(responses[35]);
          zombieMovies = _parseMovies(responses[36]);
          indieMovies = _parseMovies(responses[37]);
          cultMovies = _parseMovies(responses[38]);
          awardWinningMovies = _parseMovies(responses[39]);
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching movies: $e');
      setState(() => isLoading = false);
    }
  }

  List<dynamic> _parseMovies(http.Response response) {
    try {
      final data = json.decode(response.body);
      return (data['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      return [];
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onViewAllPressed(String category, List<dynamic> movies) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _netflixDarkGray,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _categoryColors[category.hashCode % _categoryColors.length],
                    Colors.purple
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _getFirstWord(category),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                category,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: movies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.movie_creation_outlined,
                          color: Colors.white54, size: 50),
                      const SizedBox(height: 10),
                      Text('No movies found',
                          style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: movies.length,
                  itemBuilder: (context, index) {
                    final movie = movies[index];
                    return _buildGridMovieCard(
                        movie,
                        _categoryColors[
                            category.hashCode % _categoryColors.length]);
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getFirstWord(String text) {
    final words = text.replaceAll(RegExp(r'[^\w\s]'), '').trim().split(' ');
    return words.isNotEmpty ? words.first : 'Movie';
  }

  Widget _buildGridMovieCard(dynamic movie, Color accentColor) {
    final posterPath = movie['poster_path'];
    final imageUrl = posterPath != null ? '$imageBase$posterPath' : null;

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _navigateToDetails(movie);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: imageUrl ?? '',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => Container(
                  color: _netflixDarkGray,
                  child: const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFE50914))),
                ),
                errorWidget: (context, url, error) => Container(
                  color: _netflixDarkGray,
                  child: Icon(Icons.movie_rounded,
                      color: _netflixWhite.withOpacity(0.3), size: 30),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie['title'] ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star_rounded,
                            color: Colors.yellow[700], size: 12),
                        const SizedBox(width: 4),
                        Text(
                          ((movie['vote_average'] ?? 0.0) as num)
                              .toStringAsFixed(1),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return RefreshIndicator(
      onRefresh: fetchAllMovies,
      backgroundColor: _netflixBlack,
      color: _netflixRed,
      child: isLoading
          ? _buildLoadingScreen()
          : SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.only(bottom: kBottomNavigationBarHeight),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCarousel(),
                      const SizedBox(height: 30),
                      // Build all 40 categories with their unique emojis
                      for (int i = 0; i < _categoryTitles.length; i++)
                        _buildMovieSection(i),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [Colors.red, Colors.orange, Colors.yellow],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(bounds);
            },
            child: const Text(
              'Loading Cinematic Experience...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget currentScreen =
        _selectedIndex == 0 ? _buildHomeContent() : _screens[_selectedIndex];

    return Scaffold(
      backgroundColor: _netflixBlack,
      appBar: AppBar(
        backgroundColor: _netflixBlack,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [Colors.red, Colors.orange, Colors.yellow],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds);
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("CINE",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2)),
              Text("MAX",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2)),
            ],
          ),
        ),
        centerTitle: true,
      ),
      drawer: _buildNavigationDrawer(),
      body: SafeArea(
        child: currentScreen,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildNavigationDrawer() {
    return Drawer(
      backgroundColor: _netflixBlack,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_netflixRed, Colors.purple, Colors.blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.movie_filter_rounded,
                    size: 60,
                    color: _netflixWhite,
                    shadows: [
                      const Shadow(blurRadius: 10, color: Colors.black)
                    ]),
                const SizedBox(height: 15),
                ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      colors: [Colors.white, Colors.yellow, Colors.orange],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(bounds);
                  },
                  child: const Text(
                    "CINEMAX PRO",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Ultimate Movie Experience",
                  style: TextStyle(
                    color: _netflixWhite.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildDrawerItem(
              "🎯 Premium Content", Icons.star_rounded, Colors.amber),
          _buildDrawerItem("📊 My Stats", Icons.analytics_rounded, Colors.blue),
          _buildDrawerItem(
              "🎭 Genres", Icons.theater_comedy_rounded, Colors.green),
          _buildDrawerItem("⭐ Favorites", Icons.favorite_rounded, Colors.red),
          _buildDrawerItem(
              "⏰ Watchlist", Icons.watch_later_rounded, Colors.purple),
          _buildDrawerItem("🎬 Directors", Icons.person_rounded, Colors.orange),
          _buildDrawerItem(
              "🏆 Awards", Icons.emoji_events_rounded, Colors.yellow),
          const Divider(color: Colors.white54),
          _buildDrawerItem("⚙️ Settings", Icons.settings_rounded, Colors.grey),
          _buildDrawerItem(
              "📞 Support", Icons.help_center_rounded, Colors.cyan),
          _buildDrawerItem(
              "🔒 Privacy", Icons.security_rounded, Colors.blueGrey),
          const Divider(color: Colors.white54),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  "CINEMAX  v3.0.0",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "© 2024 Ultimate Movie Experience\n40+ Categories • All rights reserved",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(String title, IconData icon, Color color) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      onTap: () {
        Navigator.pop(context);
        _showSnackBar("$title • Coming Soon!");
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_netflixBlack, Colors.black],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.8),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.transparent,
          selectedItemColor: _netflixRed,
          unselectedItemColor: _netflixWhite.withOpacity(0.6),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Search',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    if (trendingMovies.isEmpty) return const SizedBox(height: 300);

    return CarouselSlider.builder(
      itemCount: trendingMovies.length,
      itemBuilder: (context, index, _) {
        final movie = trendingMovies[index];
        final imageUrl = movie['backdrop_path'] != null
            ? '$backdropBase${movie['backdrop_path']}'
            : null;

        return GestureDetector(
          onTap: () => _navigateToDetails(movie),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: imageUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_netflixDarkGray, Colors.black],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFE50914))),
                    ),
                    errorWidget: (context, url, error) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_netflixDarkGray, Colors.black],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(Icons.movie_rounded,
                          color: _netflixWhite.withOpacity(0.3), size: 60),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          _netflixBlack.withOpacity(0.95),
                          Colors.transparent,
                          Colors.transparent,
                          _netflixBlack.withOpacity(0.4),
                        ],
                        stops: const [0.0, 0.3, 0.7, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_netflixRed, Colors.orange],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded,
                              color: Colors.yellow[700], size: 14),
                          const SizedBox(width: 4),
                          const Text(
                            'TRENDING',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    bottom: 20,
                    right: 20,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.yellow[700],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        color: Colors.black, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      ((movie['vote_average'] ?? 0.0) as num)
                                          .toStringAsFixed(1),
                                      style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getYearFromDate(movie['release_date']),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            movie['title'] ?? 'Unknown Title',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                              shadows: [
                                Shadow(
                                  blurRadius: 10,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            movie['overview'] ?? '',
                            style: TextStyle(
                              color: _netflixWhite.withOpacity(0.9),
                              fontSize: 12,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      options: CarouselOptions(
        height: 320,
        autoPlay: true,
        enlargeCenterPage: true,
        viewportFraction: 0.92,
        aspectRatio: 16 / 9,
        autoPlayInterval: const Duration(seconds: 6),
        autoPlayAnimationDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  Widget _buildMovieSection(int categoryIndex) {
    final title = _categoryTitles[categoryIndex];
    final movies = _getMoviesForCategory(categoryIndex);
    final accentColor = _categoryColors[categoryIndex % _categoryColors.length];

    if (movies.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accentColor.withOpacity(0.15),
                accentColor.withOpacity(0.05),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              // UNIQUE EMOJI for each category
              Text(
                _getEmoji(title),
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getTitleWithoutEmoji(title),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _onViewAllPressed(title, movies),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor, _darkenColor(accentColor, 0.2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: movies.length,
            itemBuilder: (context, index) =>
                _buildMovieCard(movies[index], accentColor),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  List<dynamic> _getMoviesForCategory(int index) {
    switch (index) {
      case 0:
        return trendingMovies;
      case 1:
        return nowPlayingMovies;
      case 2:
        return popularMovies;
      case 3:
        return topRatedMovies;
      case 4:
        return upcomingMovies;
      case 5:
        return actionMovies;
      case 6:
        return comedyMovies;
      case 7:
        return dramaMovies;
      case 8:
        return horrorMovies;
      case 9:
        return romanceMovies;
      case 10:
        return scifiMovies;
      case 11:
        return thrillerMovies;
      case 12:
        return adventureMovies;
      case 13:
        return animationMovies;
      case 14:
        return fantasyMovies;
      case 15:
        return mysteryMovies;
      case 16:
        return crimeMovies;
      case 17:
        return documentaryMovies;
      case 18:
        return familyMovies;
      case 19:
        return historyMovies;
      case 20:
        return musicMovies;
      case 21:
        return warMovies;
      case 22:
        return westernMovies;
      case 23:
        return tvMovies;
      case 24:
        return bollywoodMovies;
      // NEW CATEGORIES
      case 25:
        return superheroMovies;
      case 26:
        return martialArtsMovies;
      case 27:
        return spyMovies;
      case 28:
        return heistMovies;
      case 29:
        return disasterMovies;
      case 30:
        return sportsMovies;
      case 31:
        return politicalMovies;
      case 32:
        return courtroomMovies;
      case 33:
        return noirMovies;
      case 34:
        return slasherMovies;
      case 35:
        return paranormalMovies;
      case 36:
        return zombieMovies;
      case 37:
        return indieMovies;
      case 38:
        return cultMovies;
      case 39:
        return awardWinningMovies;
      default:
        return [];
    }
  }

  String _getEmoji(String title) {
    // Extract the emoji part (everything before the first space)
    final emojiEndIndex = title.indexOf(' ');
    return emojiEndIndex != -1 ? title.substring(0, emojiEndIndex) : title;
  }

  String _getTitleWithoutEmoji(String title) {
    // Remove the emoji part and return the rest
    final emojiEndIndex = title.indexOf(' ');
    return emojiEndIndex != -1 ? title.substring(emojiEndIndex + 1) : title;
  }

  Color _darkenColor(Color color, double factor) {
    assert(factor >= 0 && factor <= 1);
    return Color.fromARGB(
      color.alpha,
      (color.red * (1 - factor)).round(),
      (color.green * (1 - factor)).round(),
      (color.blue * (1 - factor)).round(),
    );
  }

  Widget _buildMovieCard(dynamic movie, Color accentColor) {
    final posterPath = movie['poster_path'];
    final imageUrl = posterPath != null ? '$imageBase$posterPath' : null;
    final rating = ((movie['vote_average'] ?? 0.0) as num).toDouble();

    return GestureDetector(
      onTap: () => _navigateToDetails(movie),
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl ?? '',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_netflixDarkGray, Colors.black],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFFE50914))),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_netflixDarkGray, Colors.black],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(Icons.movie_rounded,
                            color: _netflixWhite.withOpacity(0.3), size: 40),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                color: Colors.yellow[700], size: 12),
                            const SizedBox(width: 2),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: Text(
                movie['title'] ?? 'Unknown Title',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _getYearFromDate(movie['release_date']),
                    style: TextStyle(
                      color: _netflixWhite.withOpacity(0.7),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetails(Map<String, dynamic> movie) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MovieDetailsScreen(movie: movie),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            )),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.movie_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: _netflixRed,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _getYearFromDate(String? date) {
    if (date == null || date.isEmpty) return 'Coming Soon';
    try {
      return DateTime.parse(date).year.toString();
    } catch (e) {
      return 'Coming Soon';
    }
  }
}
