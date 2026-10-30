import '../widgets/cinema_app_bar_surface.dart';
import 'package:flutter/material.dart';

import 'support_screen.dart';
import '../utils/cinema_palette.dart';

class FAQsScreen extends StatefulWidget {
  const FAQsScreen({super.key});

  @override
  State<FAQsScreen> createState() => _FAQsScreenState();
}

class _FAQsScreenState extends State<FAQsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedCategory = 'All topics';

  static const List<_Faq> _faqs = [
    _Faq(
      category: 'Discover',
      question: 'How do I find a movie or show?',
      answer:
          'Use Search to look up a title, then use Explore to browse by genre. Results and artwork are provided by our content-metadata source and can change over time.',
      icon: Icons.search_rounded,
    ),
    _Faq(
      category: 'My List',
      question: 'How do I save a title for later?',
      answer:
          'Tap the bookmark icon on a poster or movie details page. Saved titles appear in My List, where you can open them or swipe left to remove them.',
      icon: Icons.person_outline_rounded,
    ),
    _Faq(
      category: 'My List',
      question: 'Why is my saved list empty?',
      answer:
          'My List is saved on your device. Clearing app storage, reinstalling the app, or using another device can remove locally saved titles.',
      icon: Icons.download_for_offline_outlined,
    ),
    _Faq(
      category: 'Content',
      question: 'Why can\u2019t I find a title I expected?',
      answer:
          'Catalog results depend on the metadata provider and may vary as listings are updated. Try the exact title, a shorter search, or browse a related genre.',
      icon: Icons.new_releases_outlined,
    ),
    _Faq(
      category: 'Downloads',
      question: 'What should I check when playback or a download fails?',
      answer:
          'Check your connection and available device storage, then try again. If the problem continues, send Support the title, what you were doing, and any error message you saw.',
      icon: Icons.download_done_outlined,
    ),
    _Faq(
      category: 'Support',
      question: 'How do I report a problem or request a title?',
      answer:
          'Open Support to prepare an email for a bug report or content request. Requests are reviewed, but submitting one does not guarantee that a title will be added.',
      icon: Icons.support_agent_rounded,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final categories = [
      'All topics',
      ..._faqs.map((faq) => faq.category).toSet()
    ];
    final visibleFaqs = _faqs.where((faq) {
      final matchesCategory = _selectedCategory == 'All topics' ||
          faq.category == _selectedCategory;
      return matchesCategory &&
          (normalizedQuery.isEmpty ||
              faq.question.toLowerCase().contains(normalizedQuery) ||
              faq.answer.toLowerCase().contains(normalizedQuery) ||
              faq.category.toLowerCase().contains(normalizedQuery));
    }).toList();

    return Scaffold(
      backgroundColor: CinemaPalette.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        flexibleSpace: const CinemaAppBarSurface(),
        backgroundColor: CinemaPalette.background,
        foregroundColor: CinemaPalette.ivory,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('FAQs & help',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            _buildHero(),
            const SizedBox(height: 20),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              cursorColor: CinemaPalette.gold,
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(color: CinemaPalette.ivory),
              decoration: InputDecoration(
                hintText: 'Search for help',
                hintStyle: const TextStyle(color: CinemaPalette.muted),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: CinemaPalette.gold),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: CinemaPalette.muted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        tooltip: 'Clear search',
                      ),
                filled: true,
                fillColor: CinemaPalette.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                      color: CinemaPalette.ivory.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                      color: CinemaPalette.ivory.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: CinemaPalette.gold),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in categories)
                  ChoiceChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = category),
                    showCheckmark: false,
                    backgroundColor: CinemaPalette.surface,
                    selectedColor: const Color(0x28E6BB83),
                    side: BorderSide(
                        color: _selectedCategory == category
                            ? const Color(0x88E6BB83)
                            : const Color(0x22E6BB83)),
                    labelStyle: TextStyle(
                        color: _selectedCategory == category
                            ? CinemaPalette.gold
                            : CinemaPalette.muted,
                        fontWeight: FontWeight.w500),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              normalizedQuery.isEmpty && _selectedCategory == 'All topics'
                  ? 'Popular questions'
                  : '${visibleFaqs.length} ${visibleFaqs.length == 1 ? 'question' : 'questions'}',
              style: const TextStyle(
                color: CinemaPalette.ivory,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (visibleFaqs.isEmpty)
              _buildEmptyState()
            else ...[
              for (final faq in visibleFaqs) _buildFaqItem(faq),
            ],
            const SizedBox(height: 8),
            _buildSupportCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x33E6BB83)),
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [CinemaPalette.wine, CinemaPalette.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.help_outline_rounded, color: CinemaPalette.gold, size: 30),
          SizedBox(height: 20),
          Text('MOVIE HUB HELP CENTER',
              style: TextStyle(
                  color: CinemaPalette.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6)),
          SizedBox(height: 10),
          Text(
            'Find your answer.',
            style: TextStyle(
              color: CinemaPalette.ivory,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Find answers for search, saved titles, playback, and support.',
            style: TextStyle(
                color: CinemaPalette.muted, fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(_Faq faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: CinemaPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CinemaPalette.ivory.withValues(alpha: 0.08)),
      ),
      child: ExpansionTile(
        key: PageStorageKey(faq.question),
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: CinemaPalette.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(faq.icon, color: CinemaPalette.gold),
        ),
        title: Text(
          faq.question,
          style: const TextStyle(
            color: CinemaPalette.ivory,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          faq.category.toUpperCase(),
          style: const TextStyle(
            color: CinemaPalette.gold,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            height: 2,
          ),
        ),
        iconColor: CinemaPalette.gold,
        collapsedIconColor: CinemaPalette.muted,
        children: [
          Text(
            faq.answer,
            style: const TextStyle(
                color: CinemaPalette.muted, fontSize: 14, height: 1.7),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.manage_search_rounded,
              color: CinemaPalette.muted, size: 46),
          const SizedBox(height: 12),
          const Text('No matching questions',
              style: TextStyle(color: CinemaPalette.ivory)),
          const SizedBox(height: 4),
          const Text('Try a different word or contact support.',
              textAlign: TextAlign.center,
              style: TextStyle(color: CinemaPalette.muted, height: 1.5)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _query = '';
                _selectedCategory = 'All topics';
              });
            },
            style: TextButton.styleFrom(foregroundColor: CinemaPalette.gold),
            child: const Text('Show all questions'),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CinemaPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CinemaPalette.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.support_agent_rounded, color: CinemaPalette.gold),
          const SizedBox(height: 12),
          const Text('Still need help?',
              style: TextStyle(
                  color: CinemaPalette.ivory,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
              'Prepare an email with the title, device details, and any screenshots that may help.',
              style: TextStyle(color: CinemaPalette.muted, height: 1.4)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SupportScreen()),
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Contact support'),
            style: OutlinedButton.styleFrom(
              foregroundColor: CinemaPalette.gold,
              side: const BorderSide(color: CinemaPalette.gold),
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Faq {
  const _Faq({
    required this.category,
    required this.question,
    required this.answer,
    required this.icon,
  });

  final String category;
  final String question;
  final String answer;
  final IconData icon;
}
