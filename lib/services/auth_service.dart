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

  Future<UserCredential?> signInWithGoogle() async {
    throw UnimplementedError('Google Sign-In temporarily disabled');
  }

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

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Password reset error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      notifyListeners();
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

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

  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-current-user',
          message: 'No authenticated user found.',
        );
      }
      await user.delete();
      _currentUser = _auth.currentUser;
      notifyListeners();
    } catch (e) {
      debugPrint('Account deletion error: $e');
      rethrow;
    }
  }

  String? get displayName => currentUser?.displayName;

  String? get email => currentUser?.email;

  String? get photoURL => currentUser?.photoURL;

  bool get isEmailVerified => currentUser?.emailVerified ?? false;

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
