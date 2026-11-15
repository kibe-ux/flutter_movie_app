# API Documentation & Architecture Guide

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Flutter UI Layer                      │
│  (Screens, Widgets, Navigation, State Management)            │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                    Services Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │AuthService   │  │MovieService  │  │AnalyticsService│    │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤       │
│  │  Firebase    │  │   TMDB API   │  │   Firebase   │       │
│  │  Auth        │  │   Search     │  │   Analytics  │       │
│  │              │  │   Details    │  │              │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │FavoritesServ │  │WatchHistorySv│  │CacheService  │       │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤       │
│  │ LocalStorage │  │ LocalStorage │  │MemoryCache   │       │
│  │ Firebase     │  │ Firebase     │  │ DiskCache    │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                  Data Layer                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │SharedPreferences│ │  Firebase   │  │  HTTP/REST   │       │
│  │              │  │  Firestore   │  │              │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

---

## Service APIs

### 1. AuthService

**Purpose:** Handles user authentication using Firebase

**Key Methods:**

```dart
class AuthService extends ChangeNotifier {
  // Authentication Methods
  Future<void> signUp(String email, String password)
  Future<void> signIn(String email, String password)
  Future<void> signOut()
  Future<void> resetPassword(String email)
  Future<void> updateProfile({String? displayName, String? photoUrl})
  
  // User State
  User? get currentUser
  bool get isLoggedIn
  String? get userEmail
  String? get displayName
  String? get photoURL
  DateTime? get createdAt
  bool get isEmailVerified
  
  // Validation
  bool validateEmail(String email)
  bool validatePassword(String password)
}
```

**Example Usage:**
```dart
// Sign up
try {
  await authService.signUp('user@example.com', 'Password123!');
} on FirebaseAuthException catch (e) {
  if (e.code == 'email-already-in-use') {
    print('Email already registered');
  }
}

// Listen to auth state changes
authService.addListener(() {
  if (authService.isLoggedIn) {
    print('User logged in: ${authService.userEmail}');
  }
});
```

---

### 2. MovieService

**Purpose:** Fetches movie data from TMDB API

**Key Methods:**

```dart
class MovieService {
  // Search Methods
  Future<List<Movie>> searchMovies(String query, {int page = 1})
  Future<List<Movie>> getMoviesByGenre(int genreId, {int year})
  Future<List<Movie>> getTrendingMovies({int page = 1})
  Future<List<Movie>> getTopRatedMovies({int page = 1})
  Future<List<Movie>> getUpcomingMovies({int page = 1})
  Future<List<Movie>> getPopularMovies({int page = 1})
  
  // Details Methods
  Future<MovieDetails> getMovieDetails(int movieId)
  Future<List<Video>> getMovieVideos(int movieId)
  Future<List<Review>> getMovieReviews(int movieId)
  Future<List<Movie>> getSimilarMovies(int movieId)
  
  // Genre Methods
  Future<List<Genre>> getGenres()
  
  // Caching
  Future<List<Movie>> getCachedMovies(String cacheKey)
}
```

**Data Models:**

```dart
class Movie {
  final int id;
  final String title;
  final String posterPath;
  final String releaseDate;
  final double voteAverage;
  final String overview;
  final List<int>? genreIds;
  
  Movie({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.releaseDate,
    required this.voteAverage,
    required this.overview,
    this.genreIds,
  });
}

class MovieDetails extends Movie {
  final int runtime;
  final List<String> productionCompanies;
  final double? budget;
  final double? revenue;
  
  MovieDetails({
    required super.id,
    required super.title,
    required super.posterPath,
    required super.releaseDate,
    required super.voteAverage,
    required super.overview,
    required this.runtime,
    required this.productionCompanies,
    this.budget,
    this.revenue,
  });
}

class Video {
  final String id;
  final String name;
  final String platform; // 'YouTube', 'Vimeo', etc.
  final String key; // Video ID
  
  String get url => 'https://www.youtube.com/watch?v=$key';
}
```

**Example Usage:**
```dart
// Search movies
final movies = await movieService.searchMovies('Inception');

// Get trending
final trending = await movieService.getTrendingMovies();

// Get details
final details = await movieService.getMovieDetails(27205);
print('Runtime: ${details.runtime} minutes');
print('Revenue: \$${details.revenue}');

// Get videos
final videos = await movieService.getMovieVideos(27205);
for (var video in videos) {
  print('${video.name}: ${video.url}');
}
```

---

### 3. FavoritesService

**Purpose:** Manages user's favorite movies

**Key Methods:**

```dart
class FavoritesService {
  // Favorite Operations
  Future<void> addToFavorites(Movie movie)
  Future<void> removeFromFavorites(int movieId)
  Future<void> clearFavorites()
  
  // Favorite Queries
  Future<List<Movie>> getFavorites()
  Future<bool> isFavorite(int movieId)
  Future<int> getFavoritesCount()
  
  // Watching
  Stream<List<Movie>> get favoritesStream
}
```

**Data Storage:**
```dart
// SharedPreferences Key: "${userId}_favorites"
// Format: JSON array of Movie objects
[
  {
    "id": 27205,
    "title": "Inception",
    "posterPath": "/path/to/poster.jpg",
    // ... other fields
  }
]
```

**Example Usage:**
```dart
// Add favorite
await favoritesService.addToFavorites(movie);

// Check if favorite
bool isFav = await favoritesService.isFavorite(27205);

// Get all favorites
final favorites = await favoritesService.getFavorites();
print('You have ${favorites.length} favorites');

// Listen to changes
favoritesService.favoritesStream.listen((favorites) {
  print('Favorites updated: ${favorites.length}');
});
```

---

### 4. WatchHistoryService

**Purpose:** Tracks user's watch history

**Key Methods:**

```dart
class WatchHistoryService {
  // History Operations
  Future<void> addToHistory({
    required int movieId,
    required String title,
    required String posterPath,
    int? watchDuration, // seconds
  })
  Future<void> deleteFromHistory(String entryId)
  Future<void> clearHistory()
  
  // History Queries
  Future<List<WatchHistoryEntry>> getWatchHistory({int limit = 100})
  Future<WatchHistoryEntry?> getLastWatchedMovie()
  Future<int> getTotalWatchTime() // in seconds
  Future<int> getMoviesWatchedCount()
  
  // Time-based Queries
  Future<List<WatchHistoryEntry>> getTodayHistory()
  Future<List<WatchHistoryEntry>> getWeekHistory()
  Future<List<WatchHistoryEntry>> getMonthHistory()
}

class WatchHistoryEntry {
  final String id;
  final int movieId;
  final String title;
  final String posterPath;
  final DateTime watchedAt;
  final int? watchDuration;
  
  String getRelativeTime() => _getDaysDifference();
}
```

**Example Usage:**
```dart
// Add to watch history
await watchHistoryService.addToHistory(
  movieId: 27205,
  title: 'Inception',
  posterPath: '/path/to/poster.jpg',
  watchDuration: 8880, // 2:28:00
);

// Get watch statistics
final totalTime = await watchHistoryService.getTotalWatchTime();
final moviesWatched = await watchHistoryService.getMoviesWatchedCount();
print('Total watch time: ${totalTime ~/ 3600} hours');
print('Movies watched: $moviesWatched');

// Get today's watch history
final today = await watchHistoryService.getTodayHistory();
```

---

### 5. RecommendationsService

**Purpose:** Generates personalized movie recommendations

**Key Methods:**

```dart
class RecommendationsService {
  // Recommendation Methods
  Future<List<Movie>> getPersonalizedRecommendations({int limit = 20})
  Future<List<Movie>> getTrendingMovies({int limit = 10})
  Future<List<Movie>> getTopRatedMovies({int limit = 10})
  Future<List<Movie>> getUpcomingMovies({int limit = 10})
  
  // Algorithm Details
  // 1. Analyzes favorite genres
  // 2. Considers movies in watch history
  // 3. Fetches similar movies from TMDB
  // 4. Filters out already-watched movies
  // 5. Falls back to trending if insufficient data
}
```

**Algorithm Flow:**
```
User Favorites → Extract Genres → Find Similar Movies
                                        ↓
                    Remove Already Watched
                                        ↓
            User Watch History → Similar Analysis
                                        ↓
                    Aggregate & Rank Results
                                        ↓
            No Data? → Return Trending Movies
```

**Example Usage:**
```dart
// Get personalized recommendations
final recommendations = await recommendationsService
    .getPersonalizedRecommendations(limit: 20);

// Get trending alternatives
final trending = await recommendationsService.getTrendingMovies();

// Mix with top-rated
final topRated = await recommendationsService.getTopRatedMovies();
```

---

### 6. CacheService

**Purpose:** Manages multi-layer caching

**Key Methods:**

```dart
class CacheService {
  // Memory Cache
  Future<T?> getMemCache<T>(String key)
  Future<void> setMemCache<T>(String key, T value)
  Future<void> removeMemCache(String key)
  Future<void> clearMemCache()
  
  // Disk Cache
  Future<T?> getDiskCache<T>(String key)
  Future<void> setDiskCache<T>(
    String key,
    T value, {
    Duration? ttl, // Time to live
  })
  Future<void> removeDiskCache(String key)
  Future<void> clearDiskCache()
  
  // Smart Cache (combines both)
  Future<T?> getSmartCache<T>(String key)
  Future<void> setSmartCache<T>(
    String key,
    T value, {
    Duration? ttl,
  })
  
  // Utility
  Future<bool> isCacheExpired(String key)
  Future<void> invalidateCache(String key)
}
```

**Cache Strategies:**

| Strategy | Use Case | TTL |
|----------|----------|-----|
| Memory | Movie details, genres | Session |
| Disk | Search results, history | 7 days |
| Smart | Popular lists, trending | Dynamic |

**Example Usage:**
```dart
// Cache movie details
await cacheService.setMemCache('movie_27205', movieDetails);

// Retrieve with fallback
var details = await cacheService.getMemCache('movie_27205');
if (details == null) {
  details = await movieService.getMovieDetails(27205);
  await cacheService.setMemCache('movie_27205', details);
}

// Disk cache with TTL (7 days)
await cacheService.setDiskCache(
  'search_inception',
  results,
  ttl: const Duration(days: 7),
);
```

---

### 7. AnalyticsService

**Purpose:** Tracks user events and engagement

**Key Methods:**

```dart
class AnalyticsService {
  // User Events
  Future<void> logUserSignIn(String? uid)
  Future<void> logUserSignUp(String email)
  Future<void> logUserSignOut()
  
  // Movie Events
  Future<void> logMovieView(int movieId, String title)
  Future<void> logMovieDownload(int movieId, String title)
  Future<void> logFavoriteAction(int movieId, bool isFavorite)
  
  // Search Events
  Future<void> logSearch(String query, int resultCount)
  Future<void> logSearchFilter(String filterType, String value)
  
  // Playback Events
  Future<void> logVideoPlayback({
    required int movieId,
    required String source, // 'youtube', 'web', 'local'
    required int position,
    required int duration,
    required double progress,
  })
  
  // App Events
  Future<void> logAppRating(int rating, String? feedback)
  Future<void> logCustomEvent(String name, Map<String, dynamic> parameters)
  
  // User Properties
  Future<void> setUserProperties({
    String? uid,
    String? email,
    String? preferredGenre,
    bool? isPremium,
  })
}
```

**Analytics Events Schema:**

| Event | Parameters | Purpose |
|-------|-----------|---------|
| `user_signin` | `uid`, `method` | User authentication |
| `movie_view` | `movie_id`, `title`, `genre` | Content consumption |
| `search_query` | `query`, `result_count` | Search behavior |
| `video_playback` | `duration`, `position`, `source` | Engagement metrics |
| `add_to_favorites` | `movie_id`, `title` | User preferences |

**Example Usage:**
```dart
// Log movie view
analytics.logMovieView(27205, 'Inception');

// Log playback progress
analytics.logVideoPlayback(
  movieId: 27205,
  source: 'youtube',
  position: 3600,
  duration: 8880,
  progress: 40.5,
);

// Set user properties
analytics.setUserProperties(
  uid: authService.currentUser?.uid,
  email: authService.currentUser?.email,
  preferredGenre: 'Sci-Fi',
  isPremium: true,
);

// Custom event
analytics.logCustomEvent('content_recommended', {
  'algorithm': 'personalized',
  'recommendation_count': 10,
});
```

---

## TMDB API Integration

### Base Configuration

```dart
class TMDBConfig {
  static const String baseUrl = 'https://api.themoviedb.org/3';
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p';
  static const String apiKey = String.fromEnvironment('TMDB_API_KEY');
  
  // Image sizes
  static const String posterSize = '/w500'; // 500x750
  static const String backdropSize = '/w1280'; // 1280x720
  static const String profileSize = '/w185'; // 185x278
}
```

### Endpoints Used

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/search/movie` | GET | Search movies |
| `/movie/{id}` | GET | Get movie details |
| `/movie/{id}/videos` | GET | Get trailers/clips |
| `/movie/{id}/reviews` | GET | Get user reviews |
| `/movie/{id}/similar` | GET | Get similar movies |
| `/genre/movie/list` | GET | Get all genres |
| `/movie/trending` | GET | Trending movies |
| `/movie/top_rated` | GET | Top rated movies |
| `/movie/upcoming` | GET | Upcoming releases |
| `/movie/popular` | GET | Popular movies |

### Request Example

```dart
Future<List<Movie>> searchMovies(String query) async {
  final uri = Uri.parse('${TMDBConfig.baseUrl}/search/movie')
    .replace(queryParameters: {
      'api_key': TMDBConfig.apiKey,
      'query': query,
      'page': '1',
    });
  
  final response = await httpClient.get(uri).timeout(
    const Duration(seconds: 30),
    onTimeout: () => throw TimeoutException('API request timed out'),
  );
  
  if (response.statusCode == 200) {
    final json = jsonDecode(response.body);
    return (json['results'] as List)
        .map((item) => Movie.fromJson(item))
        .toList();
  } else {
    throw Exception('Failed to load movies: ${response.statusCode}');
  }
}
```

---

## Firebase Integration

### Services Used

| Service | Purpose | Collections |
|---------|---------|--------------|
| Authentication | User login/signup | N/A |
| Firestore | Cloud data storage | users, favorites, watch_history |
| Analytics | User event tracking | N/A (Auto-collected) |
| Crashlytics | Crash reporting | N/A (Auto-reported) |
| Storage | Profile images, etc. | users/{uid}/profile_image |

### Firestore Schema

```
users/
  {uid}/
    - email: string
    - displayName: string
    - photoUrl: string
    - createdAt: timestamp
    - preferences: {
        genre: string,
        language: string
      }

favorites/
  {uid}/
    - {movieId}: {
        title: string,
        posterPath: string,
        addedAt: timestamp
      }

watch_history/ (stored locally in SharedPreferences)
  {userId}_history: [
    {
      id: string,
      movieId: int,
      watchedAt: timestamp,
      duration: int
    }
  ]
```

---

## Error Handling

### Common Exceptions

```dart
// Network errors
try {
  await movieService.searchMovies('Inception');
} on SocketException {
  print('Network error - no internet connection');
} on TimeoutException {
  print('Request timed out after 30 seconds');
} on http.ClientException {
  print('HTTP request failed');
}

// Firebase errors
try {
  await authService.signUp(email, password);
} on FirebaseAuthException catch (e) {
  switch (e.code) {
    case 'email-already-in-use':
      print('Email already registered');
      break;
    case 'weak-password':
      print('Password too weak');
      break;
    case 'invalid-email':
      print('Invalid email format');
      break;
    default:
      print('Auth error: ${e.message}');
  }
}

// Generic errors
try {
  await movieService.getMovieDetails(27205);
} catch (e, stackTrace) {
  Logger().error('Failed to load movie', e, stackTrace);
  // Show user-friendly error message
}
```

---

## State Management with Provider

### Multi-Provider Setup

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthService()),
    ChangeNotifierProvider(create: (_) => MovieService()),
    ChangeNotifierProvider(create: (_) => FavoritesService()),
    ChangeNotifierProvider(create: (_) => AnalyticsService()),
    Provider(create: (_) => WatchHistoryService()),
    Provider(create: (_) => RecommendationsService()),
    Provider(create: (_) => CacheService()),
  ],
  child: const MyApp(),
)
```

### Usage in Widgets

```dart
// Access single service
final authService = Provider.of<AuthService>(context);

// Access with watch (rebuilds on change)
Widget build(BuildContext context) {
  final favorites = context.watch<FavoritesService>();
  return Text('Favorites: ${favorites.count}');
}

// Without context
context.read<AuthService>().signOut();
```

---

## Rate Limiting & Quotas

```dart
// TMDB API Limits
- 40 requests / 10 seconds per IP
- 4 requests / second

// Implementation
class ApiRateLimiter {
  final Queue<DateTime> _requestTimes = Queue();
  static const Duration _window = Duration(seconds: 10);
  static const int _maxRequests = 40;
  
  bool canMakeRequest() {
    final now = DateTime.now();
    
    while (_requestTimes.isNotEmpty &&
        now.difference(_requestTimes.first).inSeconds > 10) {
      _requestTimes.removeFirst();
    }
    
    if (_requestTimes.length >= 40) {
      return false; // Rate limit exceeded
    }
    
    _requestTimes.add(now);
    return true;
  }
}
```