# Comprehensive Testing Guide for MovieHub

## Testing Strategy Overview

### Test Coverage Goals
- **Unit Tests**: 80%+ of business logic
- **Widget Tests**: 60%+ of UI components
- **Integration Tests**: Critical user flows
- **Performance Tests**: Identify bottlenecks
- **Security Tests**: Verify data protection

---

## Unit Tests

### 1. Service Testing

**lib/test/services/favorites_service_test.dart:**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}

void main() {
  group('FavoritesService', () {
    late FavoritesService favoritesService;
    late MockFirebaseAuth mockAuth;
    
    setUp(() {
      mockAuth = MockFirebaseAuth();
      favoritesService = FavoritesService(auth: mockAuth);
      SharedPreferences.setMockInitialValues({});
    });
    
    test('addToFavorites adds movie to favorites', () async {
      final movie = Movie(
        id: 1,
        title: 'Test Movie',
        posterPath: '/path',
        releaseDate: '2024-01-01',
        voteAverage: 8.5,
        overview: 'Test',
      );
      
      await favoritesService.addToFavorites(movie);
      
      final favorites = await favoritesService.getFavorites();
      expect(favorites.length, 1);
      expect(favorites[0].id, 1);
    });
    
    test('removeFromFavorites removes movie', () async {
      // Setup
      final movie = Movie(id: 1, title: 'Test', posterPath: '/path', 
          releaseDate: '2024-01-01', voteAverage: 8.5, overview: 'Test');
      await favoritesService.addToFavorites(movie);
      
      // Execute
      await favoritesService.removeFromFavorites(1);
      
      // Assert
      final favorites = await favoritesService.getFavorites();
      expect(favorites.isEmpty, true);
    });
    
    test('isFavorite returns correct status', () async {
      final movie = Movie(id: 1, title: 'Test', posterPath: '/path',
          releaseDate: '2024-01-01', voteAverage: 8.5, overview: 'Test');
      
      expect(await favoritesService.isFavorite(1), false);
      
      await favoritesService.addToFavorites(movie);
      expect(await favoritesService.isFavorite(1), true);
    });
  });
}
```

**lib/test/services/watch_history_service_test.dart:**
```dart
void main() {
  group('WatchHistoryService', () {
    late WatchHistoryService service;
    
    setUp(() async {
      WidgetsFlutterBinding.ensureInitialized();
      final prefs = await SharedPreferences.getInstance();
      service = WatchHistoryService();
    });
    
    test('addToHistory creates new entry', () async {
      await service.addToHistory(
        movieId: 550,
        title: 'Fight Club',
        posterPath: '/poster.jpg',
      );
      
      final history = await service.getWatchHistory();
      expect(history.length, 1);
      expect(history[0].movieId, 550);
    });
    
    test('getTotalWatchTime calculates correctly', () async {
      await service.addToHistory(
        movieId: 550,
        title: 'Fight Club',
        posterPath: '/poster.jpg',
        watchDuration: 7200, // 2 hours
      );
      
      final totalTime = await service.getTotalWatchTime();
      expect(totalTime, 7200);
    });
    
    test('getLastWatchedMovie returns correct movie', () async {
      await service.addToHistory(
        movieId: 550,
        title: 'Fight Club',
        posterPath: '/poster.jpg',
      );
      
      final lastWatched = await service.getLastWatchedMovie();
      expect(lastWatched?.movieId, 550);
    });
    
    test('deleteFromHistory removes entry', () async {
      await service.addToHistory(
        movieId: 550,
        title: 'Fight Club',
        posterPath: '/poster.jpg',
      );
      
      final history = await service.getWatchHistory();
      final entryId = history[0].id;
      
      await service.deleteFromHistory(entryId);
      
      final updatedHistory = await service.getWatchHistory();
      expect(updatedHistory.isEmpty, true);
    });
    
    test('clearHistory removes all entries', () async {
      await service.addToHistory(movieId: 550, title: 'Fight Club', posterPath: '/poster.jpg');
      await service.addToHistory(movieId: 278, title: 'Shawshank', posterPath: '/poster.jpg');
      
      await service.clearHistory();
      
      final history = await service.getWatchHistory();
      expect(history.isEmpty, true);
    });
  });
}
```

**lib/test/services/cache_service_test.dart:**
```dart
void main() {
  group('CacheService', () {
    late CacheService cacheService;
    
    setUp(() async {
      WidgetsFlutterBinding.ensureInitialized();
      await SharedPreferences.getInstance();
      cacheService = CacheService();
    });
    
    test('getMemCache returns cached value', () async {
      const key = 'test_key';
      const value = 'test_value';
      
      await cacheService.setMemCache(key, value);
      
      final cached = await cacheService.getMemCache<String>(key);
      expect(cached, value);
    });
    
    test('getDiskCache persists data', () async {
      const key = 'persistent_key';
      const value = 'persistent_value';
      
      await cacheService.setDiskCache(key, value);
      
      final cached = await cacheService.getDiskCache<String>(key);
      expect(cached, value);
    });
    
    test('getSmartCache returns memory cache first', () async {
      const key = 'smart_key';
      const memValue = 'mem_value';
      const diskValue = 'disk_value';
      
      await cacheService.setMemCache(key, memValue);
      await cacheService.setDiskCache(key, diskValue);
      
      final cached = await cacheService.getSmartCache<String>(key);
      expect(cached, memValue); // Memory cache prioritized
    });
    
    test('Expired cache entries are not returned', () async {
      const key = 'expiring_key';
      const value = 'expiring_value';
      
      await cacheService.setDiskCache(
        key,
        value,
        ttl: const Duration(seconds: 1),
      );
      
      // Cache is valid
      var cached = await cacheService.getDiskCache<String>(key);
      expect(cached, value);
      
      // Wait for expellation
      await Future.delayed(const Duration(seconds: 2));
      
      cached = await cacheService.getDiskCache<String>(key);
      expect(cached, null);
    });
  });
}
```

---

## Widget Tests

**lib/test/widgets/movie_card_test.dart:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MovieCard', () {
    testWidgets('Displays movie poster and title', (WidgetTester tester) async {
      final movie = Movie(
        id: 1,
        title: 'Test Movie',
        posterPath: '/test.jpg',
        releaseDate: '2024-01-01',
        voteAverage: 8.5,
        overview: 'Test overview',
      );
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MovieCard(movie: movie),
          ),
        ),
      );
      
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Test Movie'), findsOneWidget);
    });
    
    testWidgets('Taps navigate to detail screen', (WidgetTester tester) async {
      final movie = Movie(
        id: 1,
        title: 'Test Movie',
        posterPath: '/test.jpg',
        releaseDate: '2024-01-01',
        voteAverage: 8.5,
        overview: 'Test overview',
      );
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MovieCard(movie: movie, onTap: () {}),
          ),
        ),
      );
      
      await tester.tap(find.byType(GestureDetector));
      await tester.pumpAndSettle();
      
      // Verify navigation occurred
      expect(find.byType(MovieDetailsScreen), findsOneWidget);
    });
  });
}
```

**lib/test/widgets/search_bar_test.dart:**
```dart
void main() {
  group('SearchBar', () {
    testWidgets('Search field accepts input', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchBarWidget(
              onSearch: (query) {},
            ),
          ),
        ),
      );
      
      await tester.enterText(find.byType(TextField), 'Inception');
      
      expect(find.text('Inception'), findsOneWidget);
    });
    
    testWidgets('Debounces search input', (WidgetTester tester) async {
      int searchCount = 0;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchBarWidget(
              onSearch: (query) => searchCount++,
            ),
          ),
        ),
      );
      
      // Type multiple characters
      await tester.enterText(find.byType(TextField), 'I');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'In');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Inc');
      await tester.pumpAndSettle();
      
      // Should debounce to single search
      expect(searchCount, lessThanOrEqualTo(2));
    });
  });
}
```

---

## Integration Tests

**test/integration_test/app_flow_test.dart:**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('App Flow Integration Tests', () {
    testWidgets('Complete movie search and favorite flow', 
        (WidgetTester tester) async {
      // Launch app
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      
      // Navigate to search
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      
      // Search for movie
      await tester.enterText(find.byType(TextField), 'Inception');
      await tester.pumpAndSettle(const Duration(seconds: 2));
      
      // Tap first result
      await tester.tap(find.byType(MovieCard).first);
      await tester.pumpAndSettle();
      
      // Verify detail screen
      expect(find.byType(MovieDetailsScreen), findsOneWidget);
      
      // Add to favorites
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();
      
      // Verify favorite added
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });
    
    testWidgets('Authentication flow', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      
      // Navigate to profile
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();
      
      // Tap sign up
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      
      // Fill form
      await tester.enterText(
        find.byType(TextField).at(0),
        'test@example.com',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'Password123!',
      );
      
      // Submit
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      
      // Verify logged in
      expect(find.text('Welcome back!'), findsOneWidget);
    });
  });
}
```

---

## Performance Tests

**lib/test/performance/performance_test.dart:**
```dart
void main() {
  group('Performance Tests', () {
    testWidgets('Movie list scroll performance', 
        (WidgetTester tester) async {
      // Create app with large movie list
      await tester.pumpWidget(const MyApp());
      
      // Measure scroll performance
      final stopwatch = Stopwatch()..start();
      
      await tester.drag(
        find.byType(ListView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      
      stopwatch.stop();
      
      // Should complete in < 500ms
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });
    
    Future<void> testBuildPerformance(WidgetTester tester) async {
      stopwatch.reset();
      stopwatch.start();
      
      await tester.pumpWidget(const MyApp());
      
      stopwatch.stop();
      
      // Initial build should be < 2 seconds
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    }
  });
}
```

---

## Manual Testing Checklist

### Authentication Testing
- [ ] Sign up with valid email
- [ ] Sign up with invalid email format
- [ ] Sign up with weak password
- [ ] Sign in with correct credentials
- [ ] Sign in with wrong password
- [ ] Password reset flow
- [ ] Email verification
- [ ] Session timeout (30 min)
- [ ] Sign out functionality

### Search Testing
- [ ] Search with valid query
- [ ] Search with empty query
- [ ] Search with special characters
- [ ] Filter by genre
- [ ] Filter by release year
- [ ] Sort results
- [ ] View search history
- [ ] Clear search history
- [ ] Search on slow network

### Playback Testing
- [ ] Play TMDB movie
- [ ] Play web video
- [ ] Play local video
- [ ] Pause and resume
- [ ] Seek to position
- [ ] Full screen mode
- [ ] Subtitles (if available)
- [ ] Audio track selection
- [ ] Resume from history
- [ ] Network interruption handling

### Favorites Testing
- [ ] Add to favorites
- [ ] Remove from favorites
- [ ] View favorites list
- [ ] Favorites persist after app restart
- [ ] User-specific favorites isolation
- [ ] Favorites sync across devices (if cloud sync)

### Ads Testing
- [ ] Banner ads display on home
- [ ] Interstitial ads show after playback
- [ ] Ads don't crash app
- [ ] Ad clicks work
- [ ] No ads in offline mode

### Performance Testing
- [ ] Cold start time < 5 seconds
- [ ] App doesn't lag on scroll
- [ ] Images load without janking
- [ ] Search responds in < 3 seconds
- [ ] Memory usage < 500MB
- [ ] Battery drain acceptable
- [ ] Low-end device (Android 8) works
- [ ] High-end device (Android 13+) smooth

### Network Testing
- [ ] No network: offline mode works
- [ ] Slow network (3G): graceful degradation
- [ ] Network reconnection: resumes
- [ ] Large file download: doesn't crash
- [ ] VPN compatibility

### Security Testing
- [ ] Sensitive data not logged
- [ ] No credentials in memory
- [ ] HTTPS for all requests
- [ ] Password validation works
- [ ] Session expires correctly

### Device Testing
- [ ] Portrait orientation works
- [ ] Landscape orientation works
- [ ] Tablets (10-inch)
- [ ] Large phones (6.5-inch+)
- [ ] Small phones (5-inch)
- [ ] Android 8 and above
- [ ] iOS 12 and above

---

## Running Tests

### Run All Tests
```bash
# Unit tests
flutter test

# With coverage
flutter test --coverage

# Generate coverage report
genhtml coverage/lcov.info -o coverage/html
```

### Run Specific Tests
```bash
# Single test file
flutter test test/services/favorites_service_test.dart

# Matching pattern
flutter test --name "FavoritesService"

# Exclude tests
flutter test --exclude-tags "flaky"
```

### Integration Tests
```bash
# Run on device
flutter test integration_test/app_flow_test.dart

# Run on Android
flutter drive --target=test_driver/app.dart --driver=test_driver/app_test.dart
```

---

## CI/CD Integration

### GitHub Actions Workflow

**.github/workflows/test.yml:**
```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: 3.3.0
      
      - name: Get dependencies
        run: flutter pub get
      
      - name: Run tests
        run: flutter test --coverage
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
      
      - name: Analyze
        run: flutter analyze
      
      - name: Build APK
        run: flutter build apk --release --split-per-abi
```

---

## Test Reporting

### Code Coverage Goals
- Overall: 80%
- Services: 90%
- Widgets: 70%
- Screens: 60%

### Metrics to Track
- Test execution time
- Code coverage percentage
- Flaky test rate
- Crash-free user sessions