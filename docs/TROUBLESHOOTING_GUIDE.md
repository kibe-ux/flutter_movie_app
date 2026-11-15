# Troubleshooting & Maintenance Guide

## Troubleshooting Common Issues

### Build Issues

#### 1. Gradle Build Failed

**Error:** `Gradle build failed` or Gradle sync errors

**Solutions:**
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter pub upgrade

# Run gradle diagnostics
./gradlew --version
./gradlew build --info

# Clear Gradle cache (if needed)
rm -rf ~/.gradle
flutter clean

# Specific to Android 14+
# Add in android/build.gradle
ext.kotlin_version = '1.8.10'
```

#### 2. Android Resource Compilation Fails

**Error:** `AAPT compilation error`

**Solution:**
```gradle
// android/app/build.gradle
android {
  compileSdkVersion 34
  
  defaultConfig {
    minSdkVersion 21
    targetSdkVersion 34
  }
}
```

#### 3. CocoaPods Lock File Issues

**Error:** `CocoaPods could not find compatible versions`

**Solution:**
```bash
cd ios
rm -rf Pods
rm -rf Podfile.lock
pod install
cd ..
flutter pub get
```

---

### Network Issues

#### 1. TMDB API Not Responding

**Error:** `TimeoutException` or `SocketException`

**Diagnosis:**
```dart
Future<void> diagnosticNetworkCheck() async {
  try {
    // Test connectivity
    final result = await InternetAddress.lookup('google.com');
    print('Internet: ${result.isNotEmpty}');
    
    // Test TMDB
    final response = await http.get(
      Uri.parse('https://api.themoviedb.org/3/configuration?api_key=$apiKey'),
    ).timeout(const Duration(seconds: 5));
    
    print('TMDB Status: ${response.statusCode}');
  } on SocketException {
    print('No internet connection');
  } on TimeoutException {
    print('Request timed out');
  }
}
```

**Solutions:**
1. Check API key validity
2. Verify internet connectivity
3. Check TMDB API status
4. Increase timeout duration
5. Implement exponential backoff retry

```dart
// Implementation
Future<T> withRetry<T>(
  Future<T> Function() request, {
  int maxRetries = 3,
}) async {
  for (int i = 0; i < maxRetries; i++) {
    try {
      return await request();
    } catch (e) {
      if (i == maxRetries - 1) rethrow;
      await Future.delayed(Duration(seconds: 2 ^ i));
    }
  }
  throw Exception('Retry limit exceeded');
}
```

#### 2. Very Slow API Responses

**Diagnosis:**
```dart
Future<void> profileNetworkSpeed() async {
  final stopwatch = Stopwatch()..start();
  
  try {
    await http.get(Uri.parse('https://api.themoviedb.org/3/movie/trending'));
  } finally {
    stopwatch.stop();
    print('Response time: ${stopwatch.elapsedMilliseconds}ms');
  }
}
```

**Solutions:**
- Implement caching
- Use pagination
- Compress images
- Use CDN for static assets

---

### Authentication Issues

#### 1. Firebase Auth Not Initializing

**Error:** `Firebase.initializeApp()` hangs or fails

**Solution:**
```dart
Future<void> initializeFirebase() async {
  try {
    print('Firebase initializing...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
  } on FirebaseException catch (e) {
    print('Firebase init error: ${e.code} - ${e.message}');
    // Fallback mode without Firebase
  }
}
```

#### 2. User Session Not Persisting

**Issue:** User logged out after app restart

**Solution:**
```dart
// Test auth persistence
class AuthService extends ChangeNotifier {
  AuthService() {
    _initializeAuth();
  }
  
  Future<void> _initializeAuth() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('User restored: ${user.email}');
        _currentUser = user;
      }
    } catch (e) {
      print('Auth restoration error: $e');
    }
    notifyListeners();
  }
}
```

#### 3. Password Reset Email Not Received

**Diagnosis:**
```dart
Future<void> debugPasswordReset(String email) async {
  try {
    // Check if Firebase project is configured
    final projectId = await FirebaseAnalytics.instance.appInstanceId;
    print('Firebase Project: $projectId');
    
    // Verify email domain
    final providers = await FirebaseAuth.instance
        .fetchSignInMethodsForEmail(email);
    print('Sign-in methods: $providers');
    
    // Send reset email
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  } on FirebaseAuthException catch (e) {
    print('Error: ${e.code} - ${e.message}');
  }
}
```

---

### Performance Issues

#### 1. App Crashes with OutOfMemory

**Debugging:**
```dart
// Monitor memory usage
import 'dart:developer' as developer;

Future<void> checkMemory() async {
  final info = await developer.Service.getVM();
  print('Memory usage: ${info.toString()}');
}

// Or use package:vm_service
```

**Solutions:**
1. Reduce image cache size
2. Dispose resources properly
3. Implement memory-efficient data structures
4. Use image compression

```dart
// Reduce image cache
void reduceImageCache() {
  imageCache.maximumSize = 100; // entries
  imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50MB
}

// Proper cleanup
@override
void dispose() {
  _controller?.dispose();
  _subscription?.cancel();
  _scrollController?.dispose();
  super.dispose();
}
```

#### 2. Slow Scrolling/Janky UI

**Profiling:**
```bash
# Run in profile mode
flutter run --profile

# Open DevTools
dart devtools

# Check frame times
# Should be < 16.6ms for 60 FPS
# Should be < 8.3ms for 120 FPS
```

**Solution checklist:**
- [ ] Use ListView.builder instead of ListView
- [ ] Implement image caching
- [ ] Optimize build methods
- [ ] Remove heavy computations from build
- [ ] Use const constructors

```dart
// Good: Builder pattern
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => LazyItem(items[index]),
)

// Avoid: Large list in memory
ListView(
  children: items.map((item) => Item(item)).toList(),
)
```

#### 3. Large APK/IPA Size

**Analysis:**
```bash
# Analyze APK size
flutter build apk --release
flutter build appbundle --release

# Check built size
ls -lh build/app/outputs/apk/release/app-release.apk

# This is usually 50-100MB for a typical app
```

**Optimization:**
```gradle
// android/app/build.gradle
buildTypes {
  release {
    minifyEnabled true
    useProguard true
    shrinkResources true
    
    proguardFiles getDefaultProguardFile('proguard-android.txt'), 
                  'proguard-rules.pro'
  }
}
```

---

### Data/Cache Issues

#### 1. Corrupted SharedPreferences

**Symptoms:** App crashes when accessing stored data

**Recovery:**
```dart
Future<void> clearCorruptedCache() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    print('Cache cleared');
  } catch (e) {
    print('Error clearing prefs: $e');
    // Force clear via file system
  }
}
```

#### 2. Cache Hitting Size Limits

**Monitor cache:**
```dart
Future<void> checkCacheSize() async {
  final prefs = await SharedPreferences.getInstance();
  
  int totalSize = 0;
  for (var key in prefs.getKeys()) {
    final value = prefs.get(key);
    totalSize += value.toString().length;
  }
  
  print('Total cache size: ${totalSize / 1024}KB');
  
  if (totalSize > 10 * 1024 * 1024) { // > 10MB
    print('Cache size warning!');
    // Implement cleanup
  }
}
```

#### 3. Data Not Syncing Across Devices

**Issue:** Favorites/history not syncing

**Solution:** Implement cloud sync if needed

```dart
// Firestore sync example
Future<void> syncFavoritesToCloud() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  
  final favorites = await favoritesService.getFavorites();
  
  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('favorites')
      .doc('all')
      .set({
        'movies': favorites.map((m) => m.id).toList(),
        'lastSynced': FieldValue.serverTimestamp(),
      });
}
```

---

## Debugging Techniques

### 1. Enhanced Logging

```dart
class Logger {
  static final _instance = Logger._internal();
  static bool _isProduction = false;
  
  factory Logger() => _instance;
  Logger._internal();
  
  void log(String message, {dynamic error, StackTrace? stackTrace}) {
    final timestamp = DateTime.now();
    final log = '[$timestamp] $message';
    
    if (_isProduction) {
      // Send to Firebase Crashlytics
      FirebaseCrashlytics.instance.log(log);
    } else {
      // Local logging
      print(log);
      if (error != null) print('Error: $error');
      if (stackTrace != null) print(stackTrace);
    }
  }
}
```

### 2. Network Request Interception

```dart
class NetworkInterceptor extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    print('→ ${request.method} ${request.url}');
    
    return super.send(request).then((response) {
      print('← ${response.statusCode}');
      return response;
    });
  }
}
```

### 3. State Inspection

```dart
// Use Provider DevTools Extension
void enableProviderDebug() {
  // Add to pubspec.yaml:
  // dev_dependencies:
  //   provider: any
  //   riverpod_context: any
  
  // Then use Provider inspector in DevTools
}

// Manual inspection
print('Auth service: ${context.read<AuthService>()}');
print('Favorites: ${context.read<FavoritesService>().getFavorites()}');
```

---

## Regular Maintenance Tasks

### Daily Maintenance

- [ ] Monitor error logs in Firebase Crashlytics
- [ ] Check user feedback on app store
- [ ] Verify critical features working
- [ ] Monitor API response times

### Weekly Maintenance

- [ ] Review crash reports
- [ ] Check analytics for anomalies
- [ ] Update security patches if needed
- [ ] Run test suite
- [ ] Clear old logs

### Monthly Maintenance

- [ ] Update dependencies: `flutter pub upgrade`
- [ ] Review and fix deprecation warnings
- [ ] Analyze app size trends
- [ ] Check memory leaks with DevTools
- [ ] Review and optimize database queries
- [ ] Check TMDB API quota usage

### Quarterly Maintenance

- [ ] Full security audit
- [ ] Performance profiling
- [ ] Update minimum SDK version if needed
- [ ] Refactor legacy code
- [ ] Update documentation
- [ ] Plan next feature release

---

## Performance Maintenance

### Monitor Key Metrics

```dart
class PerformanceMonitor {
  static final _metrics = <String, dynamic>{};
  
  static void recordMetric(String name, dynamic value) {
    _metrics[name] = value;
    print('Metric: $name = $value');
  }
  
  static Map<String, dynamic> getMetrics() {
    return {..._metrics};
  }
  
  static void resetMetrics() {
    _metrics.clear();
  }
}
```

### Critical Metrics

| Metric | Threshold | Action |
|--------|-----------|--------|
| App Launch Time | > 5s | Optimize startup |
| Frame Time | > 16.6ms | Reduce complexity |
| Memory Usage | > 500MB | Implement cleanup |
| API Response Time | > 5s | Check network |
| Crash Rate | > 0.5% | Debug issues |

---

## Firebase Maintenance

### Monitor Firebase Usage

```dart
// View in Firebase Console
// Analytics → Dashboards
// Crashlytics → Issues
// Performance → Traces
```

### Optimize Firestore

```
- [ ] Check and optimize security rules
- [ ] Monitor read/write quota
- [ ] Archive old data
- [ ] Implement data retention policies
```

### Configure Alerts

```dart
// Set up Crashlytics alerting
// Firebase Console → Crashlytics →
//   → Alerts → Create New Alert
//   → Crash-free users < 99.9%
```

---

## Updating & Versioning

### Version Bumping

**pubspec.yaml:**
```yaml
version: 1.0.0+1  # Major.Minor.Patch+BuildNumber
```

**Increment Strategy:**
- **MAJOR**: Significant feature or breaking change
- **MINOR**: New feature, backward compatible
- **PATCH**: Bug fix
- **BUILD**: Internal build increment

### Semantic Versioning

```
1.0.0
│ │ └─ Patch (bug fixes)
│ └─── Minor (features)
└───── Major (breaking changes)

Release Candidate: 1.0.0-rc.1
Beta: 1.0.0-beta.1
```

### Deployment Checklist

Before each release:
- [ ] Update version number
- [ ] Update CHANGELOG.md
- [ ] Run full test suite
- [ ] Performance profiling
- [ ] Security audit
- [ ] Firebase configuration updated
- [ ] API keys rotated if needed
- [ ] Documentation updated
- [ ] Tag release in Git
- [ ] Generate release notes

---

## Rollback Procedures

### Emergency Rollback

```bash
# Identify issue
flutter build apk --release --verbose

# Revert to previous working version (if using git)
git log --oneline
git revert <commit-hash>

# Rebuild and redeploy
flutter build appbundle --release
```

### Data Migration

If users are on older version:
```dart
class VersionMigration {
  static Future<void> migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final currentVersion = prefs.getInt('app_version') ?? 100;
    
    if (currentVersion < 200) {
      // Migrate from v1.x to v2.x
      await _migrateSchema();
      await prefs.setInt('app_version', 200);
    }
  }
  
  static Future<void> _migrateSchema() async {
    // Implement data migration logic
  }
}
```

---

## Support & Documentation

### In-App Help

```dart
// Implement help screen
class HelpScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        children: [
          const FaqSection(),
          ContactSupportButton(),
          PrivacyPolicyLink(),
          TermsOfServiceLink(),
        ],
      ),
    );
  }
}
```

### External Resources

- Setup: [QUICK_START.md](QUICK_START.md)
- Deployment: [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- Security: [SECURITY_GUIDE.md](SECURITY_GUIDE.md)
- Performance: [PERFORMANCE_GUIDE.md](PERFORMANCE_GUIDE.md)
- Testing: [TESTING_GUIDE.md](TESTING_GUIDE.md)
- API: [API_DOCUMENTATION.md](API_DOCUMENTATION.md)