import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'explore_screen.dart';
import 'search_screen.dart';
import 'forum_screen.dart';
import 'faqs_screen.dart';
import 'support_screen.dart';
import 'privacy_policy_screen.dart';
import 'legal_info_screen.dart';
import 'legal_screen.dart';
import 'profile_screen.dart';
import 'share_screen.dart';
import 'rewards_screen.dart';
import '../services/auth_service.dart';
import '../services/home_startup_service.dart';
import '../utils/cinema_palette.dart';
import '../widgets/movie_hub_app_bar.dart';
import '../widgets/rate_app_dialog.dart';
import '../widgets/retained_tab_view.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.initialHomeData});

  final HomeStartupData? initialHomeData;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const Color _drawerAccent = CinemaPalette.gold;
  static const Color _drawerBackground = CinemaPalette.background;
  static const Color _drawerText = CinemaPalette.ivory;
  static const Color _drawerMuted = CinemaPalette.muted;

  // Shared set to track "My List" items (REDUNDANT: now using MyList singleton)

  // Colors
  final Color _primaryColor = const Color(0xFF0D0D0D);
  final Color _surfaceColor = const Color(0xFF1A1A1A);
  final Color _onSurfaceColor = Colors.white;

  Widget _buildScreen(BuildContext context, int index) => switch (index) {
        0 =>
          HomeScreen(myListIds: const {}, initialData: widget.initialHomeData),
        // Refresh bookmark icons on return; the mounted State is retained.
        // ignore: prefer_const_constructors
        1 => ExploreScreen(myListIds: const {}),
        // ignore: prefer_const_constructors
        2 => SearchScreen(),
        _ => const ForumScreen(),
      };

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showFAQsScreen() {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => const FAQsScreen()));
  }

  void _showSupportScreen() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const SupportScreen()));
  }

  void _showPrivacyPolicyScreen() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()));
  }

  Future<void> _showRateUsDialog() async {
    final rating = await showDialog<int>(
      context: context,
      builder: (_) => const RateAppDialog(),
    );
    if (!mounted || rating == null) return;
    _handleRating(rating);
  }

  void _handleRating(int rating) {
    if (rating >= 4) {
      _showSnackBar("Thanks for your $rating-star rating! \u{1F389}");
    } else {
      _showSnackBar("Thanks for your feedback! We'll improve. \u2B50");
      _showSupportScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryColor,
      appBar: _selectedIndex == 0 ? _buildAppBar() : null,
      drawer: _buildNavigationDrawer(),
      body: RetainedTabView(
          index: _selectedIndex, itemCount: 4, itemBuilder: _buildScreen),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return MovieHubAppBar(
      accountAction: Consumer<AuthService>(
        builder: (context, authService, child) {
          return IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundImage: authService.photoURL != null
                  ? NetworkImage(authService.photoURL!)
                  : null,
              backgroundColor: Colors.grey[800],
              child: authService.photoURL == null
                  ? Text(
                      authService.displayName?.isNotEmpty == true
                          ? authService.displayName![0].toUpperCase()
                          : authService.email?.isNotEmpty == true
                              ? authService.email![0].toUpperCase()
                              : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            tooltip: 'Profile',
          );
        },
      ),
    );
  }

  Widget _buildNavigationDrawer() {
    return Drawer(
      backgroundColor: _drawerBackground,
      surfaceTintColor: Colors.transparent,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  CinemaPalette.wine,
                  CinemaPalette.surface,
                  _drawerBackground,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        header: true,
                        label: 'Movie Hub Downloader',
                        excludeSemantics: true,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Movie Hub',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _drawerText,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  height: 1.2,
                                )),
                            SizedBox(height: 6),
                            Text('DOWNLOADER',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _drawerAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 3,
                                  height: 1.4,
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Unlimited Movies & TV Shows',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _drawerMuted,
                            fontSize: 13,
                            height: 1.5,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0x20E6BB83)),
          _buildDrawerSectionLabel('YOUR EXPERIENCE'),
          _buildDrawerItem(
            title: 'Cinema Rewards',
            icon: Icons.toll_rounded,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const RewardsScreen()));
            },
          ),
          _buildDrawerSectionLabel('INFORMATION'),
          _buildAboutUsItem(),
          _buildCopyrightPolicyItem(),
          _buildTermsOfServiceItem(),
          _buildPrivacyItem(),
          _buildDisclaimerItem(),
          _buildDrawerSectionLabel('HELP & FEEDBACK'),
          _buildFAQsItem(),
          _buildSupportItem(),
          _buildRateUsItem(),
          _buildShareItem(),
          const SizedBox(height: 16),
          const Divider(
              height: 1, indent: 24, endIndent: 24, color: Color(0x20E6BB83)),
          _buildDrawerFooter(),
        ],
      ),
    );
  }

  Widget _buildDrawerSectionLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
        child: Semantics(
          header: true,
          child: Text(label,
              style: const TextStyle(
                color: _drawerMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
                height: 1.5,
              )),
        ),
      );

  Widget _buildAboutUsItem() => _buildLegalDrawerItem(
        title: 'About Us',
        icon: Icons.info_outline_rounded,
        type: LegalPageType.about,
      );

  Widget _buildDrawerFooter() => const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x14E6BB83),
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0x33E6BB83)),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Text('Movie Hub Downloader',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _drawerText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              )),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0x20E6BB83),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(7)),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Text('v1.0.0',
                                  style: TextStyle(
                                    color: _drawerMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  )),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _DrawerCatalogueCount(
                              value: '50K+',
                              label: 'MOVIES',
                              accentColor: _drawerAccent,
                              mutedColor: _drawerMuted,
                            ),
                          ),
                          SizedBox(
                            width: 1,
                            height: 30,
                            child: ColoredBox(color: Color(0x33E6BB83)),
                          ),
                          Expanded(
                            child: _DrawerCatalogueCount(
                              value: '20K+',
                              label: ' Tv SHOWS',
                              accentColor: _drawerAccent,
                              mutedColor: _drawerMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text('2026 Ultimate Entertainment',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _drawerMuted, fontSize: 11, height: 1.5)),
              SizedBox(height: 3),
              Text('All rights reserved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _drawerMuted, fontSize: 10, height: 1.5)),
            ],
          ),
        ),
      );

  Widget _buildCopyrightPolicyItem() => _buildLegalDrawerItem(
        title: 'Copyright Policy',
        icon: Icons.copyright_outlined,
        type: LegalPageType.copyright,
      );

  Widget _buildTermsOfServiceItem() => _buildLegalDrawerItem(
        title: 'Terms of Service',
        icon: Icons.gavel_outlined,
        type: LegalPageType.terms,
      );

  Widget _buildLegalDrawerItem({
    required String title,
    required IconData icon,
    required LegalPageType type,
  }) {
    return _buildDrawerItem(
      title: title,
      icon: icon,
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LegalInfoScreen(type: type)),
        );
      },
    );
  }

  Widget _buildFAQsItem() => _buildDrawerItem(
        title: 'FAQs & Help',
        icon: Icons.help_outline_rounded,
        onTap: () {
          Navigator.pop(context);
          _showFAQsScreen();
        },
      );

  Widget _buildSupportItem() => _buildDrawerItem(
        title: 'Contact Support',
        icon: Icons.help_center_rounded,
        onTap: () {
          Navigator.pop(context);
          _showSupportScreen();
        },
      );

  Widget _buildRateUsItem() => _buildDrawerItem(
        title: 'Rate Our App',
        icon: Icons.star_rate_rounded,
        onTap: () {
          Navigator.pop(context);
          _showRateUsDialog();
        },
      );

  Widget _buildPrivacyItem() => _buildDrawerItem(
        title: 'Privacy Policy',
        icon: Icons.security_rounded,
        onTap: () {
          Navigator.pop(context);
          _showPrivacyPolicyScreen();
        },
      );

  Widget _buildDisclaimerItem() => _buildDrawerItem(
        title: 'Legal & Disclaimer',
        icon: Icons.policy_outlined,
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LegalScreen()),
          );
        },
      );

  Widget _buildDrawerItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minLeadingWidth: 44,
          horizontalTitleGap: 14,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _drawerAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _drawerAccent, size: 24),
          ),
          title: Text(title,
              style: const TextStyle(
                color: _drawerText,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.4,
              )),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: _drawerMuted, size: 20),
          onTap: onTap,
        ),
      );

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CinemaPalette.wine,
            CinemaPalette.surface,
            CinemaPalette.background,
          ],
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 56 + MediaQuery.textScalerOf(context).scale(12) * 1.3,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(Icons.home_filled, 'Home', 0),
              _buildBottomNavItem(Icons.explore, 'Explore', 1),
              _buildBottomNavItem(Icons.search, 'Search', 2),
              _buildBottomNavItem(Icons.forum_rounded, 'Forum', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    const activeColor = CinemaPalette.gold;
    return Expanded(
        child: GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? activeColor : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? CinemaPalette.background
                  : _onSurfaceColor.withValues(alpha: 0.65),
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected
                  ? activeColor
                  : _onSurfaceColor.withValues(alpha: 0.65),
              fontSize: 12,
              height: 1.3,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildShareItem() {
    return _buildDrawerItem(
      title: 'Share App',
      icon: Icons.share_rounded,
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShareScreen()),
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.movie_rounded, color: _onSurfaceColor),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message, style: TextStyle(color: _onSurfaceColor)))
        ]),
        backgroundColor: _surfaceColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

class _DrawerCatalogueCount extends StatelessWidget {
  const _DrawerCatalogueCount({
    required this.value,
    required this.label,
    required this.accentColor,
    required this.mutedColor,
  });

  final String value;
  final String label;
  final Color accentColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accentColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                height: 1.2,
              )),
          const SizedBox(height: 5),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: mutedColor,
                fontSize: 10,
                letterSpacing: 1.4,
                height: 1.4,
              )),
        ],
      );
}
