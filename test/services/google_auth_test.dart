import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:moviehub_app/services/auth_service.dart';

class _Credential extends Fake implements UserCredential {}

class _Firebase extends Fake implements FirebaseAuth {
  AuthCredential? credential;
  bool signedOut = false;
  @override
  Stream<User?> authStateChanges() => Stream.value(null);
  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    this.credential = credential;
    return _Credential();
  }

  @override
  Future<void> signOut() async => signedOut = true;
}

class _Tokens extends Fake implements GoogleSignInAuthentication {
  _Tokens(this.idToken);
  @override
  final String? idToken;
  @override
  String get accessToken => 'test-access-token';
}

class _Account extends Fake implements GoogleSignInAccount {
  _Account(this.token);
  final String? token;
  @override
  Future<GoogleSignInAuthentication> get authentication async => _Tokens(token);
}

class _Google extends Fake implements GoogleSignIn {
  GoogleSignInAccount? account;
  bool signedOut = false;
  @override
  Future<GoogleSignInAccount?> signIn() async => account;
  @override
  Future<GoogleSignInAccount?> signOut() async {
    signedOut = true;
    return null;
  }
}

void main() {
  test('cancelled Google chooser never submits a Firebase credential',
      () async {
    final firebase = _Firebase();
    final service = AuthService(auth: firebase, googleSignIn: _Google());
    addTearDown(service.dispose);
    expect(await service.signInWithGoogle(), isNull);
    expect(firebase.credential, isNull);
  });

  test('Google identity and access tokens are exchanged with Firebase',
      () async {
    final firebase = _Firebase();
    final google = _Google()..account = _Account('test-id-token');
    final service = AuthService(auth: firebase, googleSignIn: google);
    addTearDown(service.dispose);
    expect(await service.signInWithGoogle(), isA<UserCredential>());
    final credential = firebase.credential! as OAuthCredential;
    expect(credential.providerId, 'google.com');
    expect(credential.idToken, 'test-id-token');
    expect(credential.accessToken, 'test-access-token');
  });

  test('missing identity token never attempts Firebase authentication',
      () async {
    final firebase = _Firebase();
    final google = _Google()..account = _Account(null);
    final service = AuthService(auth: firebase, googleSignIn: google);
    addTearDown(service.dispose);
    await expectLater(
        service.signInWithGoogle(),
        throwsA(isA<FirebaseAuthException>()
            .having((error) => error.code, 'code', 'missing-google-id-token')));
    expect(firebase.credential, isNull);
  });
}
