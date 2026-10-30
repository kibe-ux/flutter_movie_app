import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/forum_service.dart';
import '../utils/cinema_palette.dart';
import 'login_screen.dart';

// --- Firestore collection paths -----------------------------------------------

// --- Palette ------------------------------------------------------------------
const _obsidian = CinemaPalette.background;
const _surface = CinemaPalette.surface;
const _card = CinemaPalette.surface;
const _accent = CinemaPalette.gold;
const _gold = CinemaPalette.gold;
const _crimson = CinemaPalette.red;
const _onSurface = CinemaPalette.ivory;

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key, this.service});
  final ForumService? service;
  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late final ForumService _forum = widget.service ?? ForumService();
  final Set<String> _pendingLikes = {};
  bool _posting = false;
  late AnimationController _emptyStateController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  Timer? _searchDebounce;
  Stream<QuerySnapshot>? _cachedPostsStream;
  String? _cachedStreamCategory;
  QuerySnapshot? _lastFilteredSnapshot;
  String? _lastFilteredQuery;
  List<QueryDocumentSnapshot> _filteredPosts = const [];

  static const _categories = [
    'All',
    'Recommendations',
    'Reviews',
    'Discussion',
    'Questions',
    'Off-topic'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _emptyStateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emptyStateController.dispose();
    _searchDebounce?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final query = value.trim().toLowerCase();
      if (mounted && query != _searchQuery) {
        setState(() => _searchQuery = query);
      }
    });
  }

  List<QueryDocumentSnapshot> _filterPosts(List<QueryDocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;
    final query = _searchQuery;
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final title = (data['title'] ?? '').toString().toLowerCase();
      final content = (data['content'] ?? '').toString().toLowerCase();
      return title.contains(query) || content.contains(query);
    }).toList(growable: false);
  }

  // -- Firestore helpers -----------------------------------------------------
  Stream<QuerySnapshot> get _postsStream {
    if (_cachedPostsStream != null &&
        _cachedStreamCategory == _selectedCategory) {
      return _cachedPostsStream!;
    }
    _cachedStreamCategory = _selectedCategory;
    return _cachedPostsStream = _forum.posts(_selectedCategory);
  }

  Future<String?> _ensureSignedIn() async {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid != null) return uid;
    final signedIn = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const LoginScreen(
        reason:
            'Sign in to post, reply or like discussions. Browsing is always available as a guest.',
      ),
    ));
    if (!mounted || signedIn != true) return null;
    return context.read<AuthService>().currentUser?.uid;
  }

  Future<void> _createPost(
      String title, String content, String category) async {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) throw StateError('Sign in to post.');
    final auth = context.read<AuthService>();
    await _forum.createPost(
      uid: uid,
      author: auth.displayName ?? auth.email?.split('@').first ?? 'Member',
      photoURL: auth.photoURL,
      title: title,
      content: content,
      category: category,
    );
  }

  Future<void> _toggleLike(String postId) async {
    final uid = await _ensureSignedIn();
    if (uid == null || !_pendingLikes.add(postId)) return;
    try {
      await _forum.toggleLike(postId, uid);
    } catch (error) {
      if (mounted) _snack(_forumError(error));
    } finally {
      _pendingLikes.remove(postId);
    }
  }

  Future<void> _deletePost(String postId) async {
    final uid = await _ensureSignedIn();
    if (uid == null) return;
    try {
      await _forum.deletePost(postId, uid);
      if (mounted) _snack('Discussion removed.');
    } catch (error) {
      if (mounted) _snack(_forumError(error));
    }
  }

  String _forumError(Object? error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Forum access is unavailable for this account. Please contact support.',
        'unauthenticated' => 'Please sign in again to use the forum.',
        'unavailable' ||
        'deadline-exceeded' =>
          'Unable to reach the forum. Check your connection and try again.',
        'failed-precondition' =>
          'This forum view is temporarily unavailable. Please try All discussions.',
        'not-found' => 'This discussion is no longer available.',
        _ => 'The forum could not complete your request. Please try again.',
      };
    }
    if (error is StateError) return error.message.toString();
    return 'The forum could not complete your request. Please try again.';
  }

  // -- Create Post Sheet -----------------------------------------------------
  Future<void> _showCreatePostSheet() async {
    if (_posting || await _ensureSignedIn() == null || !mounted) return;
    String selectedCategory = _categories[1];
    _titleController.clear();
    _contentController.clear();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) {
          final canPost = !_posting &&
              _titleController.text.trim().isNotEmpty &&
              _contentController.text.trim().isNotEmpty;
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, scrollController) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_accent, _gold],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.edit_rounded,
                                color: CinemaPalette.background, size: 18),
                          ),
                          const SizedBox(width: 12),
                          const Text('New Discussion',
                              style: TextStyle(
                                  color: _onSurface,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: CinemaPalette.muted),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        children: [
                          _sheetLabel('Category'),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 36,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _categories.length - 1,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, i) {
                                final cat = _categories[i + 1];
                                final selected = selectedCategory == cat;
                                return GestureDetector(
                                  onTap: () =>
                                      setSS(() => selectedCategory = cat),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: selected
                                          ? const LinearGradient(
                                              colors: [_accent, _gold])
                                          : null,
                                      color: selected ? null : _card,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: selected
                                            ? Colors.transparent
                                            : Colors.white12,
                                      ),
                                      boxShadow: selected
                                          ? [
                                              BoxShadow(
                                                color: _accent.withValues(
                                                    alpha: 0.24),
                                                blurRadius: 14,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Text(cat,
                                        style: TextStyle(
                                          color: selected
                                              ? CinemaPalette.background
                                              : CinemaPalette.muted,
                                          fontSize: 13,
                                          fontWeight: selected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        )),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          _sheetLabel('Title'),
                          const SizedBox(height: 8),
                          _themedTextField(
                            controller: _titleController,
                            hint: 'What do you want to discuss?',
                            maxLength: 100,
                            onChanged: (_) => setSS(() {}),
                          ),
                          const SizedBox(height: 20),
                          _sheetLabel('Content'),
                          const SizedBox(height: 8),
                          _themedTextField(
                            controller: _contentController,
                            hint: 'Share your thoughts in detail...',
                            maxLines: 6,
                            maxLength: 1000,
                            onChanged: (_) => setSS(() {}),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: canPost ? null : CinemaPalette.wine,
                                gradient: canPost
                                    ? const LinearGradient(
                                        colors: [_accent, _gold])
                                    : null,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  disabledBackgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: canPost
                                    ? () async {
                                        final title =
                                            _titleController.text.trim();
                                        final content =
                                            _contentController.text.trim();
                                        setSS(() => _posting = true);
                                        try {
                                          await _createPost(
                                              title, content, selectedCategory);
                                          if (ctx.mounted) Navigator.pop(ctx);
                                          if (mounted) {
                                            _snack('Discussion posted!');
                                          }
                                        } catch (error) {
                                          if (mounted) {
                                            _snack(_forumError(error));
                                          }
                                        } finally {
                                          _posting = false;
                                          if (ctx.mounted) setSS(() {});
                                        }
                                      }
                                    : null,
                                child: Text(
                                    _posting ? 'Posting...' : 'Post Discussion',
                                    style: TextStyle(
                                        color: canPost
                                            ? CinemaPalette.background
                                            : CinemaPalette.muted,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // -- Comments Sheet --------------------------------------------------------
  void _openCommentsSheet(Map<String, dynamic> data, String postId) {
    final commentCtrl = TextEditingController();
    bool sending = false;
    bool sheetOpen = true;
    final commentsStream = _forum.comments(postId);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.comment_rounded,
                          color: _accent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(data['title'] ?? '',
                            style: const TextStyle(
                                color: _onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.close, color: CinemaPalette.muted),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: commentsStream,
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return _buildCommentSkeletons();
                      }
                      if (snap.hasError) return _buildError(snap.error);
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  size: 56, color: Colors.white24),
                              SizedBox(height: 12),
                              Text('No comments yet',
                                  style: TextStyle(
                                      color: CinemaPalette.muted,
                                      fontSize: 16)),
                              SizedBox(height: 4),
                              Text('Be the first to reply!',
                                  style: TextStyle(
                                      color: Colors.white24, fontSize: 13)),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: scrollCtrl,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final c = docs[i].data() as Map<String, dynamic>;
                          return _CommentTile(data: c);
                        },
                      );
                    },
                  ),
                ),
                // Comment input bar
                Container(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 8,
                    top: 12,
                    bottom: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: _card,
                    border: Border(top: BorderSide(color: Colors.white12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentCtrl,
                          style:
                              const TextStyle(color: _onSurface, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Write a reply...',
                            hintStyle:
                                const TextStyle(color: CinemaPalette.muted),
                            filled: true,
                            fillColor: _surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          if (sending) return;
                          final text = commentCtrl.text.trim();
                          if (text.isEmpty) return;
                          final uid = await _ensureSignedIn();
                          if (uid == null || !sheetOpen || !mounted) return;
                          if (text.length > 1000) {
                            _snack('Keep replies within 1,000 characters.');
                            return;
                          }
                          final auth = context.read<AuthService>();
                          sending = true;
                          try {
                            await _forum.addComment(
                              postId: postId,
                              uid: uid,
                              author: auth.displayName ??
                                  auth.email?.split('@').first ??
                                  'Member',
                              photoURL: auth.photoURL,
                              content: text,
                            );
                            if (sheetOpen && commentCtrl.text.trim() == text) {
                              commentCtrl.clear();
                            }
                          } catch (error) {
                            if (mounted) _snack(_forumError(error));
                          } finally {
                            sending = false;
                          }
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [_accent, _gold]),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send_rounded,
                              color: CinemaPalette.background, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      sheetOpen = false;
      commentCtrl.dispose();
    });
  }

  // -- Build -----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final currentUid = context.watch<AuthService>().currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: _obsidian,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor: _obsidian,
            expandedHeight: 190,
            floating: true,
            snap: true,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 78),
              title: ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [_accent, _gold],
                ).createShader(b),
                child: const Text('Community',
                    style: TextStyle(
                        color: CinemaPalette.appBarText,
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: CinemaPalette.appBarGradient,
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_rounded,
                    color: _accent, size: 28),
                tooltip: 'New Post',
                onPressed: _showCreatePostSheet,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(68),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: _surface.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: _onSurface, fontSize: 14),
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search discussions...',
                          hintStyle: const TextStyle(
                              color: CinemaPalette.muted, fontSize: 13),
                          prefixIcon: const Icon(Icons.search,
                              color: CinemaPalette.muted, size: 20),
                          suffixIcon: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _searchController,
                            builder: (context, value, child) =>
                                value.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear,
                                            color: CinemaPalette.muted,
                                            size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          _onSearchChanged('');
                                        },
                                      )
                                    : const SizedBox(width: 48),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Category filter chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final selected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: selected
                            ? const LinearGradient(colors: [_accent, _gold])
                            : null,
                        color: selected ? null : _card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? Colors.transparent : Colors.white12,
                        ),
                      ),
                      child: Text(cat,
                          style: TextStyle(
                            color: selected
                                ? CinemaPalette.background
                                : CinemaPalette.muted,
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.normal,
                          )),
                    ),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],
        body: StreamBuilder<QuerySnapshot>(
          stream: _postsStream,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return _buildPostSkeletons();
            }
            if (snap.hasError) {
              return _buildError(snap.error, onRetry: _retryPosts);
            }
            final snapshot = snap.data;
            if (snapshot != null &&
                (!identical(snapshot, _lastFilteredSnapshot) ||
                    _lastFilteredQuery != _searchQuery)) {
              _lastFilteredSnapshot = snapshot;
              _lastFilteredQuery = _searchQuery;
              _filteredPosts = _filterPosts(snapshot.docs);
            }
            final docs = _filteredPosts;
            if (docs.isEmpty) {
              return _buildEmpty();
            }
            return ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final doc = docs[i];
                final data = doc.data() as Map<String, dynamic>;
                return _PostCard(
                  postId: doc.id,
                  data: data,
                  currentUid: currentUid,
                  onLike: () => _toggleLike(doc.id),
                  onComment: () => _openCommentsSheet(data, doc.id),
                  onDelete: data['uid'] == currentUid
                      ? () => _deletePost(doc.id)
                      : null,
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton.extended(
          onPressed: _showCreatePostSheet,
          backgroundColor: Colors.transparent,
          elevation: 0,
          label: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_accent, _gold]),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.add_rounded,
                    color: CinemaPalette.background, size: 20),
                SizedBox(width: 8),
                Text('New Post',
                    style: TextStyle(
                        color: CinemaPalette.background,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -- Helpers ---------------------------------------------------------------
  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _emptyStateController,
              child: ShaderMask(
                shaderCallback: (b) =>
                    const LinearGradient(colors: [_accent, _gold])
                        .createShader(b),
                child: const Icon(Icons.forum_rounded,
                    size: 80, color: Colors.white),
              ),
              builder: (context, child) => Transform.translate(
                offset: Offset(0, -6 * _emptyStateController.value),
                child: child,
              ),
            ),
            const SizedBox(height: 20),
            const Text('No discussions yet',
                style: TextStyle(
                    color: _onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Be the first to start a conversation!',
                style: TextStyle(color: CinemaPalette.muted, fontSize: 14)),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _showCreatePostSheet,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_accent, _gold]),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text('Start a Discussion',
                    style: TextStyle(
                        color: CinemaPalette.background,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ),
            ),
          ],
        ),
      );

  void _retryPosts() => setState(() {
        _cachedPostsStream = null;
        _lastFilteredSnapshot = null;
        _filteredPosts = const [];
      });

  Widget _buildError(Object? error, {VoidCallback? onRetry}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, color: _crimson, size: 56),
              const SizedBox(height: 16),
              const Text('Couldn\'t load posts',
                  style: TextStyle(
                      color: _onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_forumError(error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: CinemaPalette.muted, fontSize: 13)),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, color: _accent),
                  label: const Text('Retry discussions',
                      style: TextStyle(color: _accent)),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _buildPostSkeletons() => Shimmer.fromColors(
        baseColor: CinemaPalette.surface,
        highlightColor: CinemaPalette.wine,
        child: ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, __) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(radius: 18, backgroundColor: _card),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _skeletonLine(width: 120, height: 12),
                          const SizedBox(height: 7),
                          _skeletonLine(width: 72, height: 9),
                        ],
                      ),
                    ),
                    _skeletonLine(width: 76, height: 22),
                  ],
                ),
                const SizedBox(height: 20),
                _skeletonLine(width: 210, height: 18),
                const SizedBox(height: 12),
                _skeletonLine(width: double.infinity, height: 11),
                const SizedBox(height: 8),
                _skeletonLine(width: double.infinity, height: 11),
                const SizedBox(height: 8),
                _skeletonLine(width: 180, height: 11),
                const SizedBox(height: 18),
                _skeletonLine(width: 90, height: 12),
              ],
            ),
          ),
        ),
      );

  Widget _buildCommentSkeletons() => Shimmer.fromColors(
        baseColor: CinemaPalette.surface,
        highlightColor: CinemaPalette.wine,
        child: ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, __) => Container(
            height: 76,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const CircleAvatar(radius: 15, backgroundColor: _card),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _skeletonLine(width: 110, height: 11),
                      const SizedBox(height: 9),
                      _skeletonLine(width: double.infinity, height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _skeletonLine({required double width, required double height}) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      );

  Widget _sheetLabel(String text) => Text(text,
      style: const TextStyle(
          color: CinemaPalette.muted,
          fontSize: 12,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600));

  Widget _themedTextField({
    required TextEditingController controller,
    required String hint,
    int? maxLines,
    int? maxLength,
    ValueChanged<String>? onChanged,
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        onChanged: onChanged,
        style: const TextStyle(color: _onSurface, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: CinemaPalette.muted),
          filled: true,
          fillColor: _card,
          counterStyle: const TextStyle(color: CinemaPalette.muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _accent, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.forum_rounded,
            color: CinemaPalette.background, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg,
                style: const TextStyle(
                    color: CinemaPalette.background,
                    fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: _accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }
}

// --- Post Card -------------------------------------------------------------
class _PostCard extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> data;
  final String currentUid;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback? onDelete;

  const _PostCard({
    required this.postId,
    required this.data,
    required this.currentUid,
    required this.onLike,
    required this.onComment,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final liked = (data['likedBy'] as List? ?? []).contains(currentUid);
    final likes = data['likes'] ?? 0;
    final comments = data['commentCount'] ?? 0;
    final author = (data['author'] ?? 'Anonymous').toString();
    final ts = data['timestamp'] as Timestamp?;
    final time = ts != null ? _fmt(ts.toDate()) : '\u2013';
    final category = (data['category'] ?? 'Discussion').toString();
    final title = (data['title'] ?? '').toString();
    final content = (data['content'] ?? '').toString();

    return GestureDetector(
      onTap: onComment,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        padding: EdgeInsets.all(liked ? 1.2 : 0),
        decoration: BoxDecoration(
          color: liked ? null : _card,
          gradient: liked
              ? const LinearGradient(
                  colors: [_accent, _gold],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(18),
          border: liked
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.07)),
          boxShadow: liked
              ? [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.12),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  _avatar(
                    author,
                    data['photoURL'] ?? data['photoUrl'] ?? data['avatarUrl'],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(author,
                            style: const TextStyle(
                                color: _onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text(time,
                            style: const TextStyle(
                                color: CinemaPalette.muted, fontSize: 11)),
                      ],
                    ),
                  ),
                  // Category chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: _accent.withValues(alpha: 0.25)),
                    ),
                    child: Text(category,
                        style: const TextStyle(
                            color: _accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                  ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: _surface,
                            title: const Text('Delete Post?',
                                style: TextStyle(color: _onSurface)),
                            content: const Text('This cannot be undone.',
                                style: TextStyle(color: CinemaPalette.muted)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel',
                                    style:
                                        TextStyle(color: CinemaPalette.muted)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete',
                                    style: TextStyle(color: _crimson)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) onDelete!();
                      },
                      child: const Icon(Icons.more_vert,
                          color: CinemaPalette.muted, size: 18),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      color: _onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.3)),
              const SizedBox(height: 6),
              _postContent(context, content),
              const SizedBox(height: 14),
              // Footer actions
              Row(
                children: [
                  GestureDetector(
                    onTap: onLike,
                    child: Row(
                      children: [
                        Icon(
                          liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: liked ? _crimson : CinemaPalette.muted,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text('$likes',
                            style: TextStyle(
                                color: liked ? _crimson : CinemaPalette.muted,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: onComment,
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded,
                            color: CinemaPalette.muted, size: 18),
                        const SizedBox(width: 4),
                        Text('$comments',
                            style: const TextStyle(
                                color: CinemaPalette.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _postContent(BuildContext context, String content) => LayoutBuilder(
        builder: (context, constraints) {
          const style = TextStyle(
            color: CinemaPalette.muted,
            fontSize: 13,
            height: 1.5,
          );
          final painter = TextPainter(
            text: TextSpan(text: content, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 3,
          )..layout(maxWidth: constraints.maxWidth);
          final text = Text(
            content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
          if (!painter.didExceedMaxLines) return text;
          return ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0, 0.68, 1],
            ).createShader(bounds),
            child: text,
          );
        },
      );

  static Widget _avatar(String name, Object? photoUrl, {double radius = 18}) {
    final normalizedPhotoUrl = photoUrl is String && photoUrl.trim().isNotEmpty
        ? photoUrl.trim()
        : null;
    final initials = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final initialsWidget = Text(
      initials,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: radius * 0.72,
      ),
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor: _avatarColor(name),
      child: normalizedPhotoUrl == null
          ? initialsWidget
          : ClipOval(
              child: Image.network(
                normalizedPhotoUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => initialsWidget,
              ),
            ),
    );
  }

  static Color _avatarColor(String name) {
    const palette = [
      CinemaPalette.wine,
      Color(0xFF563444),
      Color(0xFF594636),
      Color(0xFF46363F),
      Color(0xFF654B45),
    ];
    return palette[name.codeUnits.fold(0, (a, b) => a + b) % palette.length];
  }

  static String _fmt(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// --- Comment Tile ----------------------------------------------------------
class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CommentTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final author = (data['author'] ?? 'Anonymous').toString();
    final ts = data['timestamp'] as Timestamp?;
    final time = ts != null ? _PostCard._fmt(ts.toDate()) : '\u2013';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostCard._avatar(
            author,
            data['photoURL'] ?? data['photoUrl'] ?? data['avatarUrl'],
            radius: 14,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(author,
                        style: const TextStyle(
                            color: _accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(time,
                        style: const TextStyle(
                            color: CinemaPalette.muted, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text((data['content'] ?? '').toString(),
                    style: const TextStyle(
                        color: CinemaPalette.muted, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
