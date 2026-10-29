
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/services/forum_service.dart';

typedef Json = Map<String, dynamic>;

class _Document extends Fake implements DocumentReference<Json> {
  _Document(this.path);
  @override
  final String path;
  @override
  CollectionReference<Json> collection(String name) =>
      _Collection('$path/$name');
}

class _Collection extends Fake implements CollectionReference<Json> {
  _Collection(this.path);
  @override
  final String path;
  Json? added;
  @override
  Query<Json> limit(int limit) => this;
  @override
  Future<QuerySnapshot<Json>> get([GetOptions? options]) async =>
      _QuerySnapshot();
  @override
  DocumentReference<Json> doc([String? path]) =>
      _Document('${this.path}/${path ?? 'new'}');
  @override
  Future<DocumentReference<Json>> add(Json data) async {
    added = data;
    return doc('created');
  }
}

class _Snapshot<T> extends Fake implements DocumentSnapshot<T> {
  _Snapshot(this.value);
  final T? value;
  @override
  bool get exists => value != null;
  @override
  T? data() => value;
}

class _QuerySnapshot extends Fake implements QuerySnapshot<Json> {
  @override
  List<QueryDocumentSnapshot<Json>> get docs => [];
}

class _Transaction extends Fake implements Transaction {
  Json? document = {'uid': 'owner', 'likedBy': <String>[], 'likes': 0};
  Json? updated;
  bool deleted = false;
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
          DocumentReference<T> ref) async =>
      _Snapshot<T>(document as T?);
  @override
  Transaction update(DocumentReference ref, Json data) {
    updated = data;
    document = {...?document, ...data};
    return this;
  }

  @override
  Transaction delete(DocumentReference ref) {
    deleted = true;
    return this;
  }
}

class _Batch extends Fake implements WriteBatch {
  final List<String> paths = [];
  Json? reply;
  Json? updateData;
  int commits = 0;
  Object? failure;
  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    paths.add(document.path);
    reply = data as Json;
  }

  @override
  void update(DocumentReference document, Json data) {
    paths.add(document.path);
    updateData = data;
  }

  @override
  Future<void> commit() async {
    commits++;
    if (failure != null) throw failure!;
  }
}

class _Firestore extends Fake implements FirebaseFirestore {
  final postsCollection = _Collection('forum_posts');
  final transaction = _Transaction();
  final writes = _Batch();
  int transactionCalls = 0;
  @override
  CollectionReference<Json> collection(String path) {
    expect(path, 'forum_posts');
    return postsCollection;
  }

  @override
  Future<T> runTransaction<T>(TransactionHandler<T> handler,
      {Duration timeout = const Duration(seconds: 30), int maxAttempts = 5}) {
    transactionCalls++;
    return handler(transaction);
  }

  @override
  WriteBatch batch() => writes;
}

void main() {
  late _Firestore db;
  late ForumService service;
  setUp(() {
    db = _Firestore();
    service = ForumService(firestore: db);
  });

  test('posts from different users go to the same shared collection', () async {
    for (final uid in ['viewer-one', 'viewer-two']) {
      await service.createPost(
          uid: uid,
          author: uid,
          title: ' Movie night ',
          content: ' A recommendation ',
          category: 'Recommendations');
      expect(db.postsCollection.added?['uid'], uid);
      expect(db.postsCollection.added?['title'], 'Movie night');
      expect(db.postsCollection.added?['content'], 'A recommendation');
      expect(db.postsCollection.added?.containsKey('country'), isFalse);
    }
  });

  test('signed-out placeholder cannot create posts or mutate others data',
      () async {
    await expectLater(
        service.createPost(
            uid: 'anon',
            author: 'Guest',
            title: 'Hi',
            content: 'Hello',
            category: 'Discussion'),
        throwsStateError);
    await expectLater(service.toggleLike('post', ''), throwsStateError);
    await expectLater(
        service.addComment(
            postId: 'post', uid: 'anon', author: 'Guest', content: 'Hi'),
        throwsStateError);
    await expectLater(service.deletePost('post', ''), throwsStateError);
    expect(db.postsCollection.added, isNull);
    expect(db.transactionCalls, 0);
    expect(db.writes.commits, 0);
  });

  test('likes read current membership and counts before each update', () async {
    db.transaction.document = {
      'likedBy': ['other'],
      'likes': 900
    };
    await service.toggleLike('post', 'viewer');
    expect(db.transaction.updated, {
      'likedBy': ['other', 'viewer'],
      'likes': 2
    });
    await service.toggleLike('post', 'viewer');
    expect(db.transaction.updated, {
      'likedBy': ['other'],
      'likes': 1
    });
    expect(db.transactionCalls, 2);
  });

  test('removed posts cannot be liked', () async {
    db.transaction.document = null;
    await expectLater(
        service.toggleLike('missing', 'viewer'), throwsStateError);
    expect(db.transaction.updated, isNull);
  });

  test('reply and count increment are committed together', () async {
    await service.addComment(
        postId: 'post', uid: 'viewer', author: 'Viewer', content: ' Hello ');
    expect(
        db.writes.paths, ['forum_posts/post/comments/new', 'forum_posts/post']);
    expect(db.writes.reply?['content'], 'Hello');
    expect(db.writes.reply?['uid'], 'viewer');
    expect(db.writes.updateData?['commentCount'], isA<FieldValue>());
    expect(db.writes.commits, 1);
  });

  test('failed reply commit propagates so the UI can keep the draft', () async {
    db.writes.failure =
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
    await expectLater(
        service.addComment(
            postId: 'post',
            uid: 'viewer',
            author: 'Viewer',
            content: 'Keep my draft'),
        throwsA(isA<FirebaseException>()));
    expect(db.writes.commits, 1);
  });

  test('only the current owner can request deletion', () async {
    await expectLater(service.deletePost('post', 'other'), throwsStateError);
    expect(db.transaction.deleted, isFalse);
    await service.deletePost('post', 'owner');
    expect(db.transaction.deleted, isTrue);
  });

  test('empty or excessive replies are rejected before writing', () async {
    for (final content in ['', 'x' * 1001]) {
      await expectLater(
          service.addComment(
              postId: 'post',
              uid: 'viewer',
              author: 'Viewer',
              content: content),
          throwsArgumentError);
    }
    expect(db.writes.commits, 0);
  });
}
