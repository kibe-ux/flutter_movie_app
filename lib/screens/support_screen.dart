import 'package:flutter/material.dart';
import '../utils/cinema_palette.dart';
import '../utils/contact_email.dart';

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

  void _launchEmail({String subject = '', String body = ''}) {
    openContactEmail(
      context,
      email: _supportEmail,
      subject: subject.isNotEmpty ? subject : 'Movie Hub Support Request',
      body: body.isNotEmpty
          ? body
          : 'Hello Movie Hub Team,\n\nMy question or concern:\n\nApp version:\nPhone model:\n\nPlease do not include passwords or other sensitive information.',
    );
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
          child: SingleChildScrollView(
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
                      'Describe the issue, then review the email before sending.',
                      style:
                          TextStyle(color: CinemaPalette.muted, fontSize: 13),
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
                      side:
                          BorderSide(color: isSelected ? _accent : _borderDark),
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
                        'Which feature or title? What did you expect? What happened instead? Include any error message, but no passwords.',
                    hintStyle: const TextStyle(
                        color: CinemaPalette.muted, fontSize: 13),
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
                              'Hello Movie Hub Team,\n\nCategory: $selectedCategory\n\nWhat happened:\n${descController.text.trim()}\n\nApp version:\nPhone model and Android/iOS version:\nSteps to reproduce:\n\nPlease review these details before sending.',
                        );
                        Navigator.pop(ctx);
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
                    child: const Text('OPEN EMAIL DRAFT',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
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
        child: SingleChildScrollView(
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
                    style: TextStyle(color: CinemaPalette.muted, fontSize: 13),
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
                style:
                    const TextStyle(color: CinemaPalette.ivory, fontSize: 14),
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
                style:
                    const TextStyle(color: CinemaPalette.ivory, fontSize: 14),
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
                  child: const Text('OPEN EMAIL DRAFT',
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
              'Talk to the Movie Hub team',
              style: TextStyle(
                color: CinemaPalette.ivory,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 14),

            _buildActionCard(
              title: 'Email Support',
              subtitle: '$_supportEmail \u2014 opens your email app',
              badgeText: 'EMAIL',
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
                    subtitle: 'Tell us what went wrong',
                    onTap: () => _showBugReportSheet(context),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildTileButton(
                    title: 'Request Movie',
                    subtitle: 'Suggest a movie or TV show',
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
              question: 'What should I include in a support request?',
              answer:
                  'Include the affected feature or title, your app version, phone model, what you expected, and what happened instead. Exact error messages and steps to reproduce the issue help us investigate. Do not send passwords or sensitive account information.',
            ),
            _buildFaqTile(
              question: 'Can I request a movie or show?',
              answer:
                  'Yes. Select Request Movie, enter the title and optional release year, then review and send the email draft. Suggestions help us understand what you want to discover, but do not guarantee that a title will become available.',
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
                'Your message is sent only when you send it from your email app.\nNever share your password. Keep Movie Hub updated for the latest fixes.',
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
                  'How can we help?',
                  style: TextStyle(
                    color: CinemaPalette.ivory,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Ask a question, report a problem, or suggest a title.',
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: CinemaPalette.ivory,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _borderDark),
        ),
        clipBehavior: Clip.antiAlias,
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
      ),
    );
  }
}
