# Security Best Practices for MovieHub

## Authentication Security

### 1. Password Security

**Current Implementation:**
- Firebase Authentication handles password hashing
- Email/password authentication

**Best Practices:**
```dart
// Password strength validation
bool _isStrongPassword(String password) {
  return password.length >= 8 &&
      password.contains(RegExp(r'[0-9]')) &&
      password.contains(RegExp(r'[a-z]')) &&
      password.contains(RegExp(r'[A-Z]')) &&
      password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
}

// Password reset security
Future<void> resetPassword(String email) async {
  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(
      email: email,
      actionCodeSettings: ActionCodeSettings(
        url: 'https://moviehub.com/complete-password-reset',
        handleCodeInApp: true,
        dynamicLinkDomain: 'moviehub.page.link',
      ),
    );
  } catch (e) {
    logger.error('Password reset failed: $e');
  }
}
```

### 2. Session Management

**Session Timeout:**
```dart
class SessionManager {
  static const Duration sessionTimeout = Duration(minutes: 30);
  Timer? _idleTimer;
  
  void startSession() {
    _idleTimer?.cancel();
    _idleTimer = Timer(sessionTimeout, _onSessionExpired);
  }
  
  void _onSessionExpired() {
    FirebaseAuth.instance.signOut();
    // Navigate to login
  }
}
```

### 3. Two-Factor Authentication (Optional Enhancement)

```dart
Future<void> enableTwoFactorAuth() async {
  // Firebase Phone Authentication
  final phoneCredential = await FirebaseAuth.instance.verifyPhoneNumber(
    phoneNumber: '+1234567890',
    codeSent: (String verificationId, int? resendToken) {
      // Handle code sent
    },
  );
}
```

## Data Security

### 1. Sensitive Data Protection

**Never Store Locally:**
```dart
// ❌ NEVER do this
SharedPreferences prefs = await SharedPreferences.getInstance();
prefs.setString('password', password); // INSECURE!
prefs.setString('auth_token', token); // INSECURE!

// ✅ DO this instead
// Firebase Auth handles tokens securely
final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
// idToken is automatically secured
```

**Encrypted Storage for Sensitive Data:**
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const secureStorage = FlutterSecureStorage();

// Store sensitive data
await secureStorage.write(
  key: 'user_api_key',
  value: apiKey,
  aOptions: _getAndroidOptions(),
  iOptions: _getIOSOptions(),
);

// Retrieve securely
final apiKey = await secureStorage.read(key: 'user_api_key');
```

### 2. HTTPS/TLS Enforcement

**Certificate Pinning:**
```dart
import 'package:flutter_http_certpin/flutter_http_certpin.dart';

final certificatePin = CertificatePinning.check(
  serverURL: 'https://api.themoviedb.org',
  headerHttp: headers,
  timeout: 60,
);
```

### 3. Data Sanitization

**Input Validation:**
```dart
// Validate search input
bool _isValidSearchQuery(String query) {
  if (query.isEmpty || query.length > 255) return false;
  
  // Prevent SQL injection patterns
  final injectionPatterns = [
    RegExp(r"('|\"|(--)|;|\/\*|\*\/|xp_|sp_)")
  ];
  
  return !injectionPatterns.any((pattern) => pattern.hasMatch(query));
}

// URL encoding
String sanitizeUrl(String url) {
  return Uri.encodeFull(url);
}
```

## API Security

### 1. API Key Management

**Config File Structure:**
```dart
// lib/config/api_config.dart
class ApiConfig {
  static const String tmdbApiKey = String.fromEnvironment('TMDB_API_KEY');
  static const String firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
}
```

**Environment Variables:**
```bash
# .env.example
TMDB_API_KEY=your_api_key_here
FIREBASE_PROJECT_ID=your_project_id
GOOGLE_MOBILE_ADS_APP_ID=your_ads_app_id

# Never commit actual .env file
# Add to .gitignore: .env, .env.local
```

### 2. Request Signing

```dart
import 'package:crypto/crypto.dart';

String generateSignature(String apiKey, String timestamp) {
  final signature = hmac256.convert(utf8.encode('$apiKey$timestamp'));
  return signature.toString();
}

Future<Response> secureApiCall(String endpoint) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  final signature = generateSignature(ApiConfig.tmdbApiKey, timestamp);
  
  final headers = {
    'X-Timestamp': timestamp,
    'X-Signature': signature,
  };
  
  return http.get(Uri.parse(endpoint), headers: headers);
}
```

### 3. Rate Limiting

```dart
class ApiRateLimiter {
  static const Duration _window = Duration(minutes: 1);
  static const int _maxRequests = 40;
  
  final Queue<DateTime> _requestTimes = Queue();
  
  bool canMakeRequest() {
    final now = DateTime.now();
    
    // Remove old requests outside window
    while (_requestTimes.isNotEmpty &&
        now.difference(_requestTimes.first).inSeconds > _window.inSeconds) {
      _requestTimes.removeFirst();
    }
    
    if (_requestTimes.length >= _maxRequests) {
      return false;
    }
    
    _requestTimes.add(now);
    return true;
  }
}
```

## Network Security

### 1. Certificate Pinning

```dart
// pubspec.yaml
dependencies:
  http: ^1.1.0
  
class PinnedHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final certificatePath = 'assets/certificates/tmdb_cert.pem';
    // Implement certificate validation
    return super.send(request);
  }
}
```

### 2. Proxy Detection

```dart
Future<bool> isProxyDetected() async {
  try {
    final result = await InternetAddress.lookup('google.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } on SocketException catch (_) {
    return true; // Might be using proxy
  }
}
```

## Local Storage Security

### 1. Encrypted SharedPreferences

```dart
import 'package:encrypted_shared_preferences/encrypted_shared_preferences.dart';

final encryptedPrefs = EncryptedSharedPreferences();

// Store encrypted
await encryptedPrefs.setString('user_preferences', jsonEncode(preferences));

// Retrieve decrypted
final preferences = jsonDecode(
  await encryptedPrefs.getString('user_preferences') ?? '{}'
);
```

### 2. Database Security

```dart
// If using local database, always encrypt
// For Firebase, enable security rules

// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    match /favorites/{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Code Security

### 1. Dependency Vulnerability Scanning

```bash
# Check for known vulnerabilities
flutter pub outdated
flutter pub upgrade

# Audit dependencies
dart pub global activate pana
pana analyze
```

### 2. Code Obfuscation

**android/app/build.gradle:**
```gradle
buildTypes {
  release {
    minifyEnabled true
    useProguard true
    
    proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
  }
}
```

### 3. String Obfuscation

```dart
// Avoid hardcoded strings
const String apiUrl = 'api.example.com'; // ❌ Visible in decompiled code

// Better approach
String _getApiUrl() {
  return _decodeString('encoded_url_bytes');
}

String _decodeString(String encoded) {
  // Decryption logic
  return decoded;
}
```

## Logging Security

```dart
// Initialize secure logging
class SecureLogger {
  static void log(String message, {LogLevel level = LogLevel.info}) {
    // Never log sensitive data
    if (_containsSensitiveData(message)) {
      log('[REDACTED]', _level: level);
      return;
    }
    
    // Log to Firebase Crashlytics (encrypted in transit)
    FirebaseCrashlytics.instance.log(message);
  }
  
  static bool _containsSensitiveData(String message) {
    final sensitivePatterns = [
      RegExp(r'\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b'), // Credit card
      RegExp(r'\b[A-Z0-9]{20,}\b'), // API key pattern
      RegExp(r'password\s*[=:]\s*(.+)', caseSensitive: false),
    ];
    
    return sensitivePatterns.any((pattern) => pattern.hasMatch(message));
  }
}
```

## Web Security (if web version exists)

### Content Security Policy

```html
<!-- web/index.html -->
<meta http-equiv="Content-Security-Policy" content="
  default-src 'self';
  script-src 'self' 'unsafe-inline' https://www.gstatic.com/;
  style-src 'self' 'unsafe-inline';
  img-src 'self' https: data:;
  font-src 'self' https:;
  connect-src 'self' https://api.themoviedb.org https://firebase.googleapis.com;
">
```

## Privacy Compliance

### 1. GDPR Compliance

```dart
// User data export
Future<String> exportUserData() async {
  final user = FirebaseAuth.instance.currentUser!;
  
  return jsonEncode({
    'profile': {
      'email': user.email,
      'displayName': user.displayName,
      'photoUrl': user.photoURL,
    },
    'favorites': await _getFavorites(),
    'watchHistory': await _getWatchHistory(),
  });
}

// User data deletion
Future<void> deleteAllUserData() async {
  final user = FirebaseAuth.instance.currentUser!;
  
  // Delete from Firestore
  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .delete();
  
  // Delete from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  
  // Delete user account
  await user.delete();
}
```

### 2. Privacy Policy

Include in app:
- Data collection practices
- Third-party services (Firebase, TMDB, Google Ads)
- User rights and data deletion
- Content ratings justification

## Security Checklist

Production Deployment:
- [ ] All sensitive data uses secure storage
- [ ] API keys in environment variables, not in code
- [ ] HTTPS enforced for all network requests
- [ ] Input validation on all user input
- [ ] SQL injection protection (if using database)
- [ ] XSS protection (if web version exists)
- [ ] CSRF tokens for sensitive operations
- [ ] Dependency vulnerabilities fixed
- [ ] Code obfuscation enabled for release
- [ ] Logging doesn't expose sensitive data
- [ ] Authentication session timeout implemented
- [ ] Password strength validation
- [ ] Firebase security rules configured
- [ ] Crashlytics configured (but no sensitive data)
- [ ] Privacy policy included
- [ ] GDPR/Privacy law compliance verified
- [ ] Penetration testing completed
- [ ] Security audit passed