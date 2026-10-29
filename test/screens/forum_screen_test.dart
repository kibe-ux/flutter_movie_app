// SDK snapshot test doubles do not access a real Firebase project.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:moviehub_app/screens/forum_screen.dart';
import 'package:moviehub_app/screens/login_screen.dart';
import 'package:moviehub_app/services/auth_service.dart';
import 'package:moviehub_app/services/forum_service.dart';

typedef Json = Map<String, dynamic>;

class _User extends Fake implements User {
  @override
  String get uid => 'viewer';
}

class _Credential extends Fake implements UserCredential {}

class _Auth extends ChangeNotifier implements AuthService {
  bool signedIn = true;
  @override
  User? get currentUser => signedIn ? _User() : null;
  @override
  String? get displayName => 'Viewer';
  @override
  String? get email => 'viewer@example.com';
  @override
  String? get photoURL => null;
  @override
  Future<UserCredential> signInWithEmail(String email, String password) async {
    signedIn = true;
    notifyListeners();
    return _Credential();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Doc extends Fake implements QueryDocumentSnapshot<Json> {
  @override
  String get id => 'post';
  @override
  Json data() => {
        'title': 'Shared discussion',
        'content': 'A worldwide movie community',
        'author': 'Another viewer',
        'uid': 'another',
        'category': 'Discussion',
        'likes': 0,
        'likedBy': <String>[],
        'commentCount': 0,
      };
}

class _Snapshot extends Fake implements QuerySnapshot<Json> {
  _Snapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Json>> docs;
}

class _Forum extends Fake implements ForumService {
  int postCalls = 0;
  int replyCalls = 0;
  int loads = 0;
  bool failFeed = false;
  final pendingPost = Completer<void>();
  @override
  Stream<QuerySnapshot<Json>> posts(String category) {
    loads++;
    if (failFeed) {
      return Stream.error(FirebaseException(
          plugin: 'cloud_firestore', code: 'permission-denied'));
    }
    return Stream.value(_Snapshot([_Doc()]));
  }

  @override
  Stream<QuerySnapshot<Json>> comments(String postId) =>
      Stream.value(_Snapshot([]));
  @override
  Future<void> createPost(
      {required String uid,
      required String author,
      String? photoURL,
      required String title,
      required String content,
      required String category}) {
    postCalls++;
    return pendingPost.future;
  }

  @override
  Future<void> addComment(
      {required String postId,
      required String uid,
      required String author,
      String? photoURL,
      required String content}) async {
    replyCalls++;
    throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
  }
}

Future<void> _show(WidgetTester tester, _Forum forum, _Auth auth) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(auth.dispose);
  await tester.pumpWidget(ChangeNotifierProvider<AuthService>.value(
    value: auth,
    child: MaterialApp(home: ForumScreen(service: forum)),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('signed-out viewers cannot post with a shared anonymous identity',
      (tester) async {
    final forum = _Forum();
    await _show(tester, forum, _Auth()..signedIn = false);
    expect(find.text('Shared discussion'), findsOneWidget);
    await tester.tap(find.byTooltip('New Post'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Post Discussion'), findsNothing);
    expect(forum.postCalls, 0);
    await tester.tap(find.text('Continue as guest'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('Shared discussion'), findsOneWidget);
    expect(forum.postCalls, 0);
  });

  testWidgets('signing in resumes the requested new discussion',
      (tester) async {
    final forum = _Forum();
    await _show(tester, forum, _Auth()..signedIn = false);
    await tester.tap(find.byTooltip('New Post'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
        find.byType(TextFormField).first, 'viewer@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.ensureVisible(find.text('Sign In'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('New Discussion'), findsOneWidget);
    expect(forum.postCalls, 0);
  });

  testWidgets('failed posts keep draft and repeated taps only submit once',
      (tester) async {
    final forum = _Forum();
    await _show(tester, forum, _Auth());
    await tester.tap(find.byTooltip('New Post'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
        find.widgetWithText(TextField, 'What do you want to discuss?'),
        'My title');
    await tester.enterText(
        find.widgetWithText(TextField, 'Share your thoughts in detail...'),
        'My draft');
    await tester.pump();
    await tester.ensureVisible(find.text('Post Discussion'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Post Discussion'));
    await tester.pump();
    expect(find.text('Posting...'), findsOneWidget);
    await tester.tap(find.text('Posting...'));
    expect(forum.postCalls, 1);
    forum.pendingPost.completeError(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));
    await tester.pump();
    expect(find.text('My draft'), findsOneWidget);
    expect(find.text('My title'), findsOneWidget);
    expect(find.text('Post Discussion'), findsOneWidget);
  });

  testWidgets('failed reply keeps the typed text', (tester) async {
    final forum = _Forum();
    await _show(tester, forum, _Auth());
    await tester.tap(find.text('Shared discussion'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.enterText(
        find.widgetWithText(TextField, 'Write a reply...'), 'Keep this reply');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(forum.replyCalls, 1);
    expect(find.text('Keep this reply'), findsOneWidget);
  });

  testWidgets('feed errors are friendly and retry creates a fresh subscription',
      (tester) async {
    final forum = _Forum()..failFeed = true;
    await _show(tester, forum, _Auth());
    expect(find.textContaining('Please contact support.'), findsOneWidget);
    expect(find.textContaining('cloud_firestore/'), findsNothing);
    forum.failFeed = false;
    await tester.tap(find.text('Retry discussions'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(forum.loads, 2);
    expect(find.text('Shared discussion'), findsOneWidget);
  });
}
