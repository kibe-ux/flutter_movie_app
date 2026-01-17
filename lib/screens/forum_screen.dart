import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});
  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final Color _showmaxBlue = const Color(0xFF00A0DC);
  final Color _showmaxDarkBlue = const Color(0xFF0C2340);
  final Color _showmaxLightBlue = const Color(0xFF1E88E5);
  final Color _showmaxGray = const Color(0xFF2D3748);
  final Color _showmaxWhite = Colors.white;
  List<ForumPost> posts = [];
  bool isLoading = true;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      isLoading = true;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      final prefs = await SharedPreferences.getInstance();
      final postsJson = prefs.getString('forum_posts');
      if (postsJson != null && postsJson.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(postsJson);
        setState(() {
          posts = jsonList.map((json) => ForumPost.fromJson(json)).toList();
        });
      } else {
        _loadSamplePosts();
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
      _loadSamplePosts();
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _loadSamplePosts() {
    setState(() {
      posts = [
        ForumPost(
          id: '1',
          title: 'Best Action Movies 2024?',
          content:
              'What are your top action movie recommendations for this year?',
          author: 'MovieBuff42',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          comments: [
            ForumComment(
              id: '1',
              author: 'ActionFan',
              content:
                  'John Wick 4 was amazing! The action sequences were breathtaking.',
              timestamp: DateTime.now().subtract(const Duration(hours: 1)),
            ),
            ForumComment(
              id: '2',
              author: 'Cinephile',
              content:
                  'Extraction 2 had one of the best 21-minute one-shot scenes ever!',
              timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
            ),
          ],
        ),
        ForumPost(
          id: '2',
          title: 'Hidden Gems on MovieHub',
          content:
              'Share your favorite underrated shows and movies available on our platform!',
          author: 'Discoverer',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          comments: [
            ForumComment(
              id: '1',
              author: 'BingeWatcher',
              content:
                  'The Silent Sea is a fantastic sci-fi mystery with amazing visuals!',
              timestamp: DateTime.now().subtract(const Duration(hours: 12)),
            ),
            ForumComment(
              id: '2',
              author: 'SciFiFan',
              content:
                  'Dark on movie hub is a masterpiece if you haven\'t seen it yet!',
              timestamp: DateTime.now().subtract(const Duration(hours: 8)),
            ),
          ],
        ),
        ForumPost(
          id: '3',
          title: 'Movie Recommendations Similar to Inception?',
          content:
              'Looking for mind-bending movies like Inception. Any suggestions?',
          author: 'DreamExplorer',
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          comments: [
            ForumComment(
              id: '1',
              author: 'MindBender',
              content:
                  'Tenet is from the same director and has similar time-bending concepts.',
              timestamp: DateTime.now().subtract(const Duration(days: 1)),
            ),
            ForumComment(
              id: '2',
              author: 'MovieExpert',
              content:
                  'Try Interstellar, The Prestige, or Paprika (anime). All mind-bending!',
              timestamp: DateTime.now().subtract(const Duration(hours: 10)),
            ),
          ],
        ),
        ForumPost(
          id: '4',
          title: 'What\'s Your Favorite Movie of All Time?',
          content:
              'I know it\'s a tough question, but I\'m curious about everyone\'s top pick!',
          author: 'CuriousViewer',
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
          comments: [
            ForumComment(
              id: '1',
              author: 'ClassicLover',
              content:
                  'The Godfather Part II - perfect storytelling and acting!',
              timestamp: DateTime.now().subtract(const Duration(days: 2)),
            ),
            ForumComment(
              id: '2',
              author: 'ModernFan',
              content:
                  'Parasite - brilliant social commentary with amazing twists.',
              timestamp: DateTime.now().subtract(const Duration(days: 1)),
            ),
          ],
        ),
      ];
    });
  }

  Future<void> _savePosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final postsJson =
          json.encode(posts.map((post) => post.toJson()).toList());
      await prefs.setString('forum_posts', postsJson);
    } catch (e) {
      debugPrint('Error saving posts: $e');
    }
  }

  void _showCreatePostDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _showmaxDarkBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Create New Post',
            style: TextStyle(
                color: _showmaxWhite,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle:
                      TextStyle(color: _showmaxWhite.withValues(alpha: 0.7)),
                  hintText: 'What do you want to discuss?',
                  hintStyle:
                      TextStyle(color: _showmaxWhite.withValues(alpha: 0.5)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _showmaxBlue)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _showmaxBlue, width: 2)),
                  fillColor: _showmaxGray,
                  filled: true,
                ),
                style: TextStyle(color: _showmaxWhite, fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contentController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'Content',
                  labelStyle:
                      TextStyle(color: _showmaxWhite.withValues(alpha: 0.7)),
                  hintText: 'Share your thoughts...',
                  hintStyle:
                      TextStyle(color: _showmaxWhite.withValues(alpha: 0.5)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _showmaxBlue)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _showmaxBlue, width: 2)),
                  fillColor: _showmaxGray,
                  filled: true,
                ),
                style: TextStyle(color: _showmaxWhite, fontSize: 16),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _titleController.clear();
              _contentController.clear();
            },
            child: Text('Cancel',
                style: TextStyle(
                    color: _showmaxWhite.withValues(alpha: 0.7), fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () {
              if (_titleController.text.trim().isEmpty) {
                _showSnackBar('Please enter a title');
                return;
              }
              if (_contentController.text.trim().isEmpty) {
                _showSnackBar('Please enter some content');
                return;
              }
              _createPost(
                  _titleController.text.trim(), _contentController.text.trim());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _showmaxBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Post',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _createPost(String title, String content) {
    final newPost = ForumPost(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      author: 'You',
      timestamp: DateTime.now(),
      comments: [],
    );
    setState(() {
      posts.insert(0, newPost);
    });
    _savePosts();
    _titleController.clear();
    _contentController.clear();
    _showSnackBar('Post created successfully! 🎬');
  }

  void _showCommentsDialog(ForumPost post) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: _showmaxDarkBlue,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(post.title,
                              style: TextStyle(
                                  color: _showmaxWhite,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                        IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close,
                                color: _showmaxWhite.withValues(alpha: 0.7))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: post.comments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.comment_outlined,
                                    size: 60,
                                    color:
                                        _showmaxWhite.withValues(alpha: 0.3)),
                                const SizedBox(height: 16),
                                Text('No comments yet',
                                    style: TextStyle(
                                        color: _showmaxWhite.withValues(
                                            alpha: 0.5),
                                        fontSize: 16)),
                                const SizedBox(height: 8),
                                Text('Be the first to comment!',
                                    style: TextStyle(
                                        color: _showmaxWhite.withValues(
                                            alpha: 0.4),
                                        fontSize: 14)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: post.comments.length,
                            itemBuilder: (context, index) {
                              final comment = post.comments[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _showmaxGray,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor:
                                              _getAvatarColor(comment.author),
                                          child: Text(
                                              comment.author[0].toUpperCase(),
                                              style: TextStyle(
                                                  color: _showmaxWhite,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12)),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: Text(comment.author,
                                                style: TextStyle(
                                                    color: _showmaxBlue,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        Text(_formatTime(comment.timestamp),
                                            style: TextStyle(
                                                color: _showmaxWhite.withValues(
                                                    alpha: 0.5),
                                                fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(comment.content,
                                        style: TextStyle(
                                            color: _showmaxWhite.withValues(
                                                alpha: 0.9),
                                            fontSize: 14)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _showmaxGray,
                      borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              hintStyle: TextStyle(
                                  color: _showmaxWhite.withValues(alpha: 0.5)),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide(color: _showmaxBlue)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide(color: _showmaxBlue)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide(
                                      color: _showmaxBlue, width: 2)),
                              fillColor: _showmaxDarkBlue,
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            style: TextStyle(color: _showmaxWhite),
                            onSubmitted: (value) {
                              if (value.trim().isNotEmpty) {
                                _addComment(post, value.trim(), setState);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                              color: _showmaxBlue,
                              borderRadius: BorderRadius.circular(25)),
                          child: IconButton(
                              onPressed: () {
                                if (_commentController.text.trim().isNotEmpty) {
                                  _addComment(post,
                                      _commentController.text.trim(), setState);
                                }
                              },
                              icon:
                                  const Icon(Icons.send, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _addComment(ForumPost post, String content, StateSetter setState) {
    final newComment = ForumComment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      author: 'You',
      content: content,
      timestamp: DateTime.now(),
    );
    setState(() {
      post.comments.insert(0, newComment);
    });
    _savePosts();
    _commentController.clear();
  }

  Color _getAvatarColor(String name) {
    final colors = [
      _showmaxBlue,
      _showmaxLightBlue,
      Colors.teal,
      Colors.cyan,
      Colors.lightBlue
    ];
    final index = name.codeUnits.fold(0, (a, b) => a + b) % colors.length;
    return colors[index];
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.forum, color: _showmaxWhite),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(color: _showmaxWhite)))
        ]),
        backgroundColor: _showmaxBlue,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _showmaxDarkBlue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Community Forum',
            style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
              onPressed: _showCreatePostDialog,
              icon:
                  Icon(Icons.add_circle_outline, color: _showmaxBlue, size: 28),
              tooltip: 'Create Post'),
          IconButton(
              onPressed: _loadPosts,
              icon: Icon(Icons.refresh, color: _showmaxWhite, size: 24),
              tooltip: 'Refresh'),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: _showmaxBlue))
          : posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.forum_outlined,
                          size: 100,
                          color: _showmaxWhite.withValues(alpha: 0.3)),
                      const SizedBox(height: 24),
                      Text('No discussions yet',
                          style: TextStyle(
                              color: _showmaxWhite.withValues(alpha: 0.5),
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text('Start the conversation!',
                          style: TextStyle(
                              color: _showmaxWhite.withValues(alpha: 0.4),
                              fontSize: 16)),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _showCreatePostDialog,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _showmaxBlue,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 16)),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 20),
                              SizedBox(width: 8),
                              Text('Create First Post',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold))
                            ]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: _showmaxBlue,
                  backgroundColor: _showmaxGray,
                  onRefresh: _loadPosts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return GestureDetector(
                        onTap: () => _showCommentsDialog(post),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                              color: _showmaxGray,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4))
                              ]),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                        radius: 20,
                                        backgroundColor:
                                            _getAvatarColor(post.author),
                                        child: Text(
                                            post.author[0].toUpperCase(),
                                            style: TextStyle(
                                                color: _showmaxWhite,
                                                fontWeight: FontWeight.bold))),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(post.author,
                                              style: TextStyle(
                                                  color: _showmaxBlue,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16)),
                                          Text(_formatTime(post.timestamp),
                                              style: TextStyle(
                                                  color: _showmaxWhite
                                                      .withValues(alpha: 0.5),
                                                  fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    if (post.author == 'You')
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                              color: _showmaxBlue.withValues(
                                                  alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: _showmaxBlue,
                                                  width: 1)),
                                          child: Text('You',
                                              style: TextStyle(
                                                  color: _showmaxBlue,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(post.title,
                                    style: TextStyle(
                                        color: _showmaxWhite,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                Text(post.content,
                                    style: TextStyle(
                                        color: _showmaxWhite.withValues(
                                            alpha: 0.8),
                                        fontSize: 15),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              post.isLiked = !post.isLiked;
                                              if (post.isLiked) {
                                                post.likes++;
                                              } else {
                                                post.likes--;
                                              }
                                            });
                                            _savePosts();
                                          },
                                          icon: Icon(
                                              post.isLiked
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: post.isLiked
                                                  ? _showmaxBlue
                                                  : _showmaxWhite.withValues(
                                                      alpha: 0.5),
                                              size: 22),
                                        ),
                                        Text('${post.likes}',
                                            style: TextStyle(
                                                color: _showmaxWhite.withValues(
                                                    alpha: 0.7))),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    Row(
                                      children: [
                                        Icon(Icons.comment,
                                            color: _showmaxWhite, size: 22),
                                        const SizedBox(width: 8),
                                        Text('${post.comments.length}',
                                            style: TextStyle(
                                                color: _showmaxWhite.withValues(
                                                    alpha: 0.7))),
                                      ],
                                    ),
                                    const Spacer(),
                                    TextButton(
                                        onPressed: () =>
                                            _showCommentsDialog(post),
                                        child: Text('View Comments',
                                            style: TextStyle(
                                                color: _showmaxBlue,
                                                fontWeight: FontWeight.bold))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
          onPressed: _showCreatePostDialog,
          backgroundColor: _showmaxBlue,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.add, size: 28)),
    );
  }
}

class ForumPost {
  final String id;
  final String title;
  final String content;
  final String author;
  final DateTime timestamp;
  List<ForumComment> comments;
  bool isLiked;
  int likes;
  ForumPost({
    required this.id,
    required this.title,
    required this.content,
    required this.author,
    required this.timestamp,
    required this.comments,
    this.isLiked = false,
    this.likes = 0,
  });
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'author': author,
      'timestamp': timestamp.toIso8601String(),
      'comments': comments.map((comment) => comment.toJson()).toList(),
      'isLiked': isLiked,
      'likes': likes,
    };
  }

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    return ForumPost(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      author: json['author'],
      timestamp: DateTime.parse(json['timestamp']),
      comments: (json['comments'] as List)
          .map((commentJson) => ForumComment.fromJson(commentJson))
          .toList(),
      isLiked: json['isLiked'] ?? false,
      likes: json['likes'] ?? 0,
    );
  }
}

class ForumComment {
  final String id;
  final String author;
  final String content;
  final DateTime timestamp;
  ForumComment({
    required this.id,
    required this.author,
    required this.content,
    required this.timestamp,
  });
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author': author,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ForumComment.fromJson(Map<String, dynamic> json) {
    return ForumComment(
      id: json['id'],
      author: json['author'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
