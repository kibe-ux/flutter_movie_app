import 'package:cloud_firestore/cloud_firestore.dart';

/// All users share the same collection; no device, user or country feed partition.
class ForumService {
  ForumService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const reportReasons = [
    'Harassment or hate',
    'Sexual or harmful content',
    'Spam or scam',
    'Copyright or illegal content',
    'Other',
  ];

  Future<bool> acceptedGuidelines(String uid) async =>
      (await _firestore.collection('forum_members').doc(uid).get())
          .data()?['termsVersion'] ==
      1;

  Future<void> acceptGuidelines(String uid) {
    _requireUser(uid);
    return _firestore.collection('forum_members').doc(uid).set({
      'termsVersion': 1,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> blockedUsers(String uid) =>
      _firestore
          .collection('forum_members')
          .doc(uid)
          .collection('blocked')
          .snapshots();

  Future<void> blockUser(String uid, String targetUid, String author) {
    _requireUser(uid);
    if (targetUid.isEmpty || uid == targetUid) {
      throw ArgumentError('Choose another user.');
    }
    final label = author.trim();
    return _firestore
        .collection('forum_members')
        .doc(uid)
        .collection('blocked')
        .doc(targetUid)
        .set({
      'uid': targetUid,
      'author': label.isEmpty
          ? 'Member'
          : String.fromCharCodes(label.runes.take(100)),
      'timestamp': FieldValue.serverTimestamp()
    });
  }

  Future<void> unblockUser(String uid, String targetUid) => _firestore
      .collection('forum_members')
      .doc(uid)
      .collection('blocked')
      .doc(targetUid)
      .delete();

  Future<void> report(
      {required String uid,
      required String targetUid,
      required String targetType,
      required String postId,
      String? commentId,
      required String reason,
      String details = ''}) {
    _requireUser(uid);
    if (!reportReasons.contains(reason) ||
        details.trim().length > 1000 ||
        !['post', 'comment', 'user'].contains(targetType)) {
      throw ArgumentError(
          'Choose a report reason and keep details within 1,000 characters.');
    }
    return _firestore
        .collection('forum_reports')
        .doc('$uid:$targetType:$postId:${commentId ?? 'post'}')
        .set({
      'reporterUid': uid,
      'targetUid': targetUid,
      'targetType': targetType,
      'postId': postId,
      'commentId': commentId,
      'reason': reason,
      'details': details.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'open',
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> reports() => _firestore
      .collection('forum_reports')
      .where('status', isEqualTo: 'open')
      .snapshots();

  Future<DocumentSnapshot<Map<String, dynamic>>> reportedContent(
          Map<String, dynamic> report) =>
      _target(report).get();

  DocumentReference<Map<String, dynamic>> _target(Map<String, dynamic> report) {
    final post = _posts.doc(report['postId'] as String);
    return report['commentId'] == null
        ? post
        : post.collection('comments').doc(report['commentId'] as String);
  }

  Future<void> reviewReport(String reportId, String moderatorUid,
      {required bool remove}) async {
    final ref = _firestore.collection('forum_reports').doc(reportId);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      final data = snapshot.data();
      if (data == null || data['status'] != 'open') {
        throw StateError('This report has already been reviewed.');
      }
      final target = _target(data);
      final content = remove ? await tx.get(target) : null;
      if (remove && content?.exists != true) {
        throw StateError(
            'The content no longer exists. Dismiss this report instead.');
      }
      if (remove && content!.data()?['removed'] != true) {
        final isPost = data['commentId'] == null;
        tx.update(target, {
          'removed': true,
          'author': 'Member',
          'photoURL': null,
          'content': isPost
              ? 'This discussion was removed for violating community rules.'
              : 'This reply was removed for violating community rules.',
          'moderatedAt': FieldValue.serverTimestamp(),
          if (isPost) 'title': 'Discussion removed',
          if (isPost) 'deleting': true,
        });
      }
      tx.update(ref, {
        'status': remove ? 'removed' : 'dismissed',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': moderatorUid
      });
    });
  }

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
      'lastCommentId': null,
      'deleting': false,
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
    final reply = post.collection('comments').doc();
    final batch = _firestore.batch();
    batch.set(reply, {
      'uid': uid,
      'author': author,
      'photoURL': photoURL,
      'content': content.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });
    batch.update(post, {
      'commentCount': FieldValue.increment(1),
      'lastCommentId': reply.id,
    });
    await batch.commit();
  }

  Future<void> deletePost(String postId, String uid) async {
    _requireUser(uid);
    final ref = _posts.doc(postId);
    // Check ownership before reading replies. Server rules must enforce it too.
    final exists = await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return false;
      if (snapshot.data()?['uid'] != uid) {
        throw StateError('You can only remove your own discussions.');
      }
      if (snapshot.data()?['deleting'] != true) {
        transaction.update(ref, {'deleting': true});
      }
      return true;
    });
    if (!exists) return;

    // Remove replies while the parent still exists so owner-based rules can
    // authorize cleanup. Keep each transaction bounded for large discussions.
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
