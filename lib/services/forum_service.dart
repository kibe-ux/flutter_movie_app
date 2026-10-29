import 'package:cloud_firestore/cloud_firestore.dart';

class ForumService {
  ForumService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('forum_posts');

  Stream<QuerySnapshot<Map<String, dynamic>>> posts(String category) {
    Query<Map<String, dynamic>> query = _posts;
    if (category != 'All') {
      query = query.where('category', isEqualTo: category);
    }
    return query.orderBy('timestamp', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> comments(String postId) => _posts
      .doc(postId)
      .collection('comments')
      .orderBy('timestamp')
      .snapshots();

  Future<void> createPost({
    required String uid,
    required String author,
    String? photoURL,
    required String title,
    required String content,
    required String category,
  }) async {
    _requireUser(uid);
    if (title.trim().isEmpty ||
        title.trim().length > 100 ||
        content.trim().isEmpty ||
        content.trim().length > 1000) {
      throw ArgumentError(
          'Enter a title and content within the allowed lengths.');
    }
    await _posts.add({
      'uid': uid,
      'author': author,
      'photoURL': photoURL,
      'title': title.trim(),
      'content': content.trim(),
      'category': category,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': 0,
      'likedBy': <String>[],
      'commentCount': 0,
    });
  }

  Future<void> toggleLike(String postId, String uid) async {
    _requireUser(uid);
    final ref = _posts.doc(postId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw StateError('This discussion was removed.');
      final likedBy = List<String>.from(snapshot.data()?['likedBy'] ?? []);
      if (likedBy.contains(uid)) {
        likedBy.removeWhere((id) => id == uid);
      } else {
        likedBy.add(uid);
      }
      transaction.update(ref, {'likedBy': likedBy, 'likes': likedBy.length});
    });
  }

  Future<void> addComment({
    required String postId,
    required String uid,
    required String author,
    String? photoURL,
    required String content,
  }) async {
    _requireUser(uid);
    if (content.trim().isEmpty || content.trim().length > 1000) {
      throw ArgumentError('Enter a reply of up to 1,000 characters.');
    }
    final post = _posts.doc(postId);
    final batch = _firestore.batch();
    batch.set(post.collection('comments').doc(), {
      'uid': uid,
      'author': author,
      'photoURL': photoURL,
      'content': content.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });
    batch.update(post, {'commentCount': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> deletePost(String postId, String uid) async {
    _requireUser(uid);
    final ref = _posts.doc(postId);
    final exists = await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return false;
      if (snapshot.data()?['uid'] != uid) {
        throw StateError('You can only remove your own discussions.');
      }
      return true;
    });
    if (!exists) return;

    while (true) {
      final replies = await ref.collection('comments').limit(200).get();
      if (replies.docs.isEmpty) break;
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        if (snapshot.data()?['uid'] != uid) {
          throw StateError('You can only remove your own discussions.');
        }
        for (final reply in replies.docs) {
          transaction.delete(reply.reference);
        }
      });
    }
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;
      if (snapshot.data()?['uid'] != uid) {
        throw StateError('You can only remove your own discussions.');
      }
      transaction.delete(ref);
    });
  }

  static void _requireUser(String uid) {
    if (uid.isEmpty || uid == 'anon') {
      throw StateError('Sign in to join the discussion.');
    }
  }
}
