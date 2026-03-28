import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  bool _isLoading = true;

  AuthService() {
    _auth.authStateChanges().listen((user) {
      _currentUser = user;
      _isLoading = false;
      notifyListeners();
    });
  }

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google - Temporarily disabled due to API issues
  Future<UserCredential?> signInWithGoogle() async {
    throw UnimplementedError('Google Sign-In temporarily disabled');
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
      await _auth.signOut();
      notifyListeners();
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  // Update user profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      await currentUser?.updateDisplayName(displayName);
      await currentUser?.updatePhotoURL(photoURL);
      await currentUser?.reload();
      notifyListeners();
    } catch (e) {
      debugPrint('Profile update error: $e');
      rethrow;
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      await currentUser?.delete();
      notifyListeners();
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
      await currentUser?.sendEmailVerification();
    } catch (e) {
      debugPrint('Email verification error: $e');
      rethrow;
    }
  }
}
