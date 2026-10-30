import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/cinema_palette.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/safe_network_image.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key, this.movie});

  final Map<String, dynamic>? movie;

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  static const _accent = CinemaPalette.gold;
  static const _posterBorder = CinemaPalette.gold;
  bool _isSharing = false;

  Map<String, dynamic>? get _movie => widget.movie;
  String get _movieTitle => _movie?['title']?.toString() ?? 'this movie';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinemaPalette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: CinemaPalette.ivory,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: CinemaPalette.appBarGradient,
          ),
        ),
        elevation: 0,
        title: Text(
            _movie == null ? 'Share Movie Hub Downloader' : 'Share movie',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            if (_movie != null) ...[
              _buildMoviePreview(),
              const SizedBox(height: 20),
            ] else ...[
              _buildInviteHero(),
              const SizedBox(height: 20),
            ],
            _buildPrimaryAction(),
            const SizedBox(height: 28),
            const Text('Quick actions',
                style: TextStyle(
                    color: CinemaPalette.ivory,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _buildQuickActions(),
            const SizedBox(height: 28),
            _buildTip(),
          ],
        ),
      ),
    );
  }

  Widget _buildMoviePreview() {
    final posterPath = _movie?['poster_path']?.toString();
    final rating = _movie?['vote_average'];
    final imageUrl = posterPath == null
        ? null
        : 'https://image.tmdb.org/t/p/w500$posterPath';

    return Container(
      height: 264,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: CinemaPalette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _posterBorder.withValues(alpha: 0.35)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          SafeNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholderIconSize: 64,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Color(0xE60B0A0D)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NOW SHARING',
                    style: TextStyle(
                        color: CinemaPalette.gold,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
                const SizedBox(height: 5),
                Text(_movieTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: CinemaPalette.ivory,
                        fontSize: 25,
                        fontWeight: FontWeight.w800)),
                if (rating != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.star_rounded,
                        color: CinemaPalette.gold, size: 18),
                    const SizedBox(width: 5),
                    Text('$rating / 10',
                        style: const TextStyle(color: CinemaPalette.muted)),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteHero() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            CinemaPalette.wine,
            CinemaPalette.surface,
            CinemaPalette.background
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.group_add_outlined, size: 38, color: CinemaPalette.gold),
          SizedBox(height: 22),
          Text('Better with friends',
              style: TextStyle(
                  color: CinemaPalette.ivory,
                  fontSize: 28,
                  fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          Text(
              'Invite someone to discover their next movie night on Movie Hub Downloader.',
              style: TextStyle(color: CinemaPalette.muted, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildPrimaryAction() {
    return FilledButton.icon(
      onPressed: _isSharing ? null : _sharePrimary,
      icon: _isSharing
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                  color: CinemaPalette.background, strokeWidth: 2),
            )
          : const Icon(Icons.ios_share_rounded),
      label: Text(_isSharing
          ? 'Opening share options...'
          : _movie == null
              ? 'Invite to Movie Hub Downloader'
              : 'Share $_movieTitle'),
      style: FilledButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: CinemaPalette.background,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            icon: Icons.copy_rounded,
            title: 'Copy message',
            subtitle: 'Share later',
            onTap: _isSharing ? null : _copyShareMessage,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            icon: Icons.send_rounded,
            title: 'Send message',
            subtitle: 'Choose an app',
            onTap: _isSharing ? null : _sharePrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: CinemaPalette.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: CinemaPalette.ivory.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: _accent),
              const SizedBox(height: 18),
              Text(title,
                  style: const TextStyle(
                      color: CinemaPalette.ivory, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: const TextStyle(
                      color: CinemaPalette.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.22)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: CinemaPalette.gold),
          SizedBox(width: 12),
          Expanded(
            child: Text(
                'The system share sheet lets you choose any installed messaging or social app.',
                style: TextStyle(color: CinemaPalette.muted, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Future<void> _sharePrimary() async {
    final title = _movieTitle;
    final message = _shareMessage;

    setState(() => _isSharing = true);
    try {
      await Share.share(message,
          subject: _movie == null
              ? 'Join Movie Hub Downloader'
              : 'Download $title with Movie Hub Downloader');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not open sharing options: $error'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  String get _shareMessage {
    final rating = _movie?['vote_average'];
    return _movie == null
        ? 'Discover your next movie night with Movie Hub Downloader.'
        : 'Check out "$_movieTitle" on Movie Hub Downloader${rating == null ? '' : ' - rated $rating/10'}.';
  }

  Future<void> _copyShareMessage() async {
    await Clipboard.setData(ClipboardData(text: _shareMessage));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share message copied to clipboard.')),
    );
  }
}
