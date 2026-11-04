import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'account_deletion_service.dart';
import '../utils/my_list.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final AccountDeletionService _accountDeletion;
  late final StreamSubscription<User?> _authSubscription;
  User? _currentUser;
  bool _isLoading = true;

  AuthService(
      {FirebaseAuth? auth,
      GoogleSignIn? googleSignIn,
      AccountDeletionService? accountDeletion})
      : _auth = auth ?? FirebaseAuth.instance,
        _accountDeletion = accountDeletion ?? AccountDeletionService(),
        _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: ['email']) {
    _authSubscription = _auth.authStateChanges().listen((user) {
      _currentUser = user;
      _isLoading = false;
      notifyListeners();
    });
  }

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Exchange the Google account's tokens for a Firebase session.
  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      return _auth.signInWithPopup(GoogleAuthProvider());
    }
    final account = await _googleSignIn.signIn();
    if (account == null) return null;
    final tokens = await account.authentication;
    if (tokens.idToken == null || tokens.idToken!.isEmpty) {
      throw FirebaseAuthException(code: 'missing-google-id-token');
    }
    return _auth.signInWithCredential(GoogleAuthProvider.credential(
      accessToken: tokens.accessToken,
      idToken: tokens.idToken,
    ));
  }

  @override
  void dispose() {
    unawaited(_authSubscription.cancel());
    super.dispose();
  }

  // Sign in with Email and Password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return userCredential;
    } catch (e) {
      debugPrint('Email sign-in error: $e');
      rethrow;
    }
  }

  // Create account with Email and Password
  Future<UserCredential> createAccountWithEmail(
      String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return userCredential;
    } catch (e) {
      debugPrint('Account creation error: $e');
      rethrow;
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Password reset error: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      try {
        if (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS)) {
          await _googleSignIn.signOut();
        }
      } finally {
        await _auth.signOut();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  // Update user profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-current-user',
          message: 'No authenticated user found.',
        );
      }

      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }
      await user.reload();
      _currentUser = _auth.currentUser;
      notifyListeners();
    } catch (e) {
      debugPrint('Profile update error: $e');
      rethrow;
    }
  }

  // Refresh current user data from Firebase
  Future<void> reloadCurrentUser() async {
    try {
      await _auth.currentUser?.reload();
      _currentUser = _auth.currentUser;
      notifyListeners();
    } catch (e) {
      debugPrint('User reload error: $e');
      rethrow;
    }
  }

  Future<void> reauthenticateForDeletion({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');
    final providers = user.providerData.map((provider) => provider.providerId);
    if (password != null && providers.contains('password')) {
      await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password));
    } else if (providers.contains('google.com')) {
      if (kIsWeb) {
        await user.reauthenticateWithPopup(GoogleAuthProvider());
      } else {
        final account = await _googleSignIn.signIn();
        if (account == null) throw FirebaseAuthException(code: 'cancelled');
        final tokens = await account.authentication;
        if (tokens.idToken == null || tokens.idToken!.isEmpty) {
          throw FirebaseAuthException(code: 'missing-google-id-token');
        }
        await user.reauthenticateWithCredential(GoogleAuthProvider.credential(
            idToken: tokens.idToken, accessToken: tokens.accessToken));
      }
    } else {
      throw FirebaseAuthException(
          code: 'requires-recent-login',
          message: 'Verify your account with your current password.');
    }
  }

  // Cleanup is server-owned; never delete only the Firebase login.
  Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-current-user',
          message: 'No authenticated user found.',
        );
      }
      final completed = await _accountDeletion.request(user);
      await MyList().clearForDeletedUser(user.uid);
      final prefs = await SharedPreferences.getInstance();
      for (final key in ['favorite_movies', 'watch_history']) {
        await prefs.remove('${key}_${user.uid}');
      }
      if (_auth.currentUser?.uid == user.uid) await signOut();
      _currentUser = _auth.currentUser;
      notifyListeners();
      return completed;
    } catch (e) {
      debugPrint('Account deletion error: $e');
      rethrow;
    }
  }

  // Get user display name
  String? get displayName => currentUser?.displayName;

  // Get user email
  String? get email => currentUser?.email;

  // Get user photo URL
  String? get photoURL => currentUser?.photoURL;

  // Check if email is verified
  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-current-user',
          message: 'No authenticated user found.',
        );
      }
      await user.sendEmailVerification();
    } catch (e) {
      debugPrint('Email verification error: $e');
      rethrow;
    }
  }
}
