import 'package:flutter/material.dart';
import '../utils/cinema_palette.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  // Shared cinema palette.
  final Color _bgDark = CinemaPalette.background;
  final Color _surfaceDark = CinemaPalette.surface;
  final Color _cardDark = CinemaPalette.wine;
  final Color _borderDark = CinemaPalette.gold.withValues(alpha: 0.18);
  final Color _accent = CinemaPalette.gold;
  static const String _supportEmail = 'supportmoviehub@gmail.com';

  Future<void> _launchUrlHelper(Uri uri, String fallbackMessage) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(fallbackMessage),
              backgroundColor: CinemaPalette.surface,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(fallbackMessage),
            backgroundColor: CinemaPalette.surface,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _launchEmail({String subject = '', String body = ''}) {
    final emailUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': subject.isNotEmpty ? subject : 'Movie Hub Support Request',
        'body': body.isNotEmpty
            ? body
            : 'Hello Movie Hub Team,\n\nI need assistance with:'
      },
    );
    _launchUrlHelper(emailUri, 'Please email us directly at $_supportEmail');
  }

  void _showBugReportSheet(BuildContext context) {
    String selectedCategory = 'Playback or streaming';
    final TextEditingController descController = TextEditingController();
    final categories = [
      'Playback or streaming',
      'Download or storage',
      'Audio or subtitles',
      'Account or sign-in',
      'Other'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: _surfaceDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: _borderDark),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CinemaPalette.muted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: CinemaPalette.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bug_report_rounded,
                        color: CinemaPalette.gold, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report an Issue',
                        style: TextStyle(
                            color: CinemaPalette.ivory,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Include enough detail for us to investigate',
                        style:
                            TextStyle(color: CinemaPalette.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Category',
                  style: TextStyle(
                      color: CinemaPalette.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((cat) {
                  final isSelected = cat == selectedCategory;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (val) {
                      setModalState(() => selectedCategory = cat);
                    },
                    selectedColor: _accent.withValues(alpha: 0.2),
                    backgroundColor: _cardDark,
                    side: BorderSide(color: isSelected ? _accent : _borderDark),
                    labelStyle: TextStyle(
                      color: isSelected ? _accent : CinemaPalette.muted,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Tell us what happened',
                  style: TextStyle(
                      color: CinemaPalette.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                maxLines: 4,
                style:
                    const TextStyle(color: CinemaPalette.ivory, fontSize: 14),
                decoration: InputDecoration(
                  hintText:
                      'Title, what you expected, what happened, and any error message',
                  hintStyle:
                      const TextStyle(color: CinemaPalette.muted, fontSize: 13),
                  filled: true,
                  fillColor: _cardDark,
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _accent),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (descController.text.trim().isNotEmpty) {
                      _launchEmail(
                        subject: '[$selectedCategory] Bug Report - Movie Hub',
                        body:
                            'Category: $selectedCategory\n\nDescription:\n${descController.text.trim()}\n\nDevice: Mobile App',
                      );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              const Text('Your email draft is ready to send.'),
                          backgroundColor: const Color(0xFF00C853),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: CinemaPalette.background,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('SUBMIT REPORT',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMovieRequestSheet(BuildContext context) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController yearController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          top: 24,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: _surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: _borderDark),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: CinemaPalette.muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.movie_filter_rounded,
                      color: _accent, size: 24),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request Movie or Show',
                      style: TextStyle(
                          color: CinemaPalette.ivory,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Requests are reviewed but are not guaranteed',
                      style:
                          TextStyle(color: CinemaPalette.muted, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Title / Name',
                style: TextStyle(
                    color: CinemaPalette.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              style: const TextStyle(color: CinemaPalette.ivory, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. Interstellar, Breaking Bad',
                hintStyle:
                    const TextStyle(color: CinemaPalette.muted, fontSize: 13),
                filled: true,
                fillColor: _cardDark,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _borderDark),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _borderDark),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _accent),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Release Year (Optional)',
                style: TextStyle(
                    color: CinemaPalette.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: yearController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: CinemaPalette.ivory, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. 2024',
                hintStyle:
                    const TextStyle(color: CinemaPalette.muted, fontSize: 13),
                filled: true,
                fillColor: _cardDark,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _borderDark),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _borderDark),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _accent),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (titleController.text.trim().isNotEmpty) {
                    final year = yearController.text.trim();
                    final yrStr = year.isNotEmpty ? ' ($year)' : '';
                    _launchEmail(
                      subject:
                          'Movie Request: ${titleController.text.trim()}$yrStr',
                      body:
                          'Requested title: ${titleController.text.trim()}$yrStr\n\nPlease add any helpful details below:\n',
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            const Text('Your request email is ready to send.'),
                        backgroundColor: _accent,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: CinemaPalette.background,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('SUBMIT REQUEST',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
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
        title: const Text(
          'Support & Help',
          style: TextStyle(
            color: CinemaPalette.appBarText,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: CinemaPalette.ivory, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Live Banner
            _buildLiveStatusBanner(),
            const SizedBox(height: 28),

            // Section Header: Direct Channels
            const Text(
              'Direct Assistance',
              style: TextStyle(
                color: CinemaPalette.ivory,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 14),

            _buildActionCard(
              title: 'Email Concierge',
              subtitle: '$_supportEmail \u2014 opens your email app',
              icon: Icons.alternate_email_rounded,
              badgeText: 'Priority',
              badgeColor: _accent,
              onTap: () => _launchEmail(),
            ),
            const SizedBox(height: 28),

            // Section Header: Interactive Help
            const Text(
              'Quick Actions',
              style: TextStyle(
                color: CinemaPalette.ivory,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _buildTileButton(
                    title: 'Report Bug',
                    subtitle: 'Prepare a detailed issue report',
                    icon: Icons.bug_report_rounded,
                    color: CinemaPalette.gold,
                    onTap: () => _showBugReportSheet(context),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildTileButton(
                    title: 'Request Movie',
                    subtitle: 'Suggest a title to add',
                    icon: Icons.movie_filter_rounded,
                    color: _accent,
                    onTap: () => _showMovieRequestSheet(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Section Header: FAQ Accordion
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                color: CinemaPalette.ivory,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 14),

            _buildFaqTile(
              question: 'How do I get help with a playback problem?',
              answer:
                  'Use Report Bug and include the title, what you were trying to do, what happened, and any message you saw. This information helps us investigate the issue.',
            ),
            _buildFaqTile(
              question: 'Can I request a movie or show?',
              answer:
                  'Yes. Select Request Movie, enter the title and optional release year, then send the email draft. We review requests, but cannot guarantee availability.',
            ),
            _buildFaqTile(
              question: 'Why can\u2019t I find a title or saved movie?',
              answer:
                  'Try searching with a shorter or exact title, then browse Explore by genre. My List is stored on your device, so clearing app storage or reinstalling can remove saved titles.',
            ),
            const SizedBox(height: 36),

            // Security & Privacy Note
            Center(
              child: Text(
                'Movie Hub Support \u2022 Support opens in your email app.\nPlease keep the app updated for the latest fixes and features.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CinemaPalette.ivory.withValues(alpha: 0.35),
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStatusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderDark),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: CinemaPalette.gold,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: CinemaPalette.gold,
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need help with the app?',
                  style: TextStyle(
                    color: CinemaPalette.ivory,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Choose an option below to prepare an email',
                  style: TextStyle(
                    color: CinemaPalette.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _borderDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'HELP',
              style: TextStyle(
                color: CinemaPalette.muted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surfaceDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderDark),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _borderDark),
                ),
                child: Icon(icon, color: CinemaPalette.ivory, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: CinemaPalette.ivory,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: CinemaPalette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: CinemaPalette.muted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTileButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surfaceDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: CinemaPalette.ivory,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: CinemaPalette.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqTile({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderDark),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: _accent,
          collapsedIconColor: CinemaPalette.muted,
          title: Text(
            question,
            style: const TextStyle(
              color: CinemaPalette.ivory,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          childrenPadding:
              const EdgeInsets.only(left: 18, right: 18, bottom: 18),
          children: [
            Text(
              answer,
              style: const TextStyle(
                color: CinemaPalette.muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
