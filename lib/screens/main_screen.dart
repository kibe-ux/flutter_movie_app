import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
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
import '../services/rewards_service.dart';
import '../services/auth_service.dart';
import '../services/home_startup_service.dart';
import '../utils/cinema_palette.dart';
import '../widgets/movie_hub_app_bar.dart';
import '../widgets/movie_hub_icon.dart';
import '../widgets/retained_tab_view.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.initialHomeData});

  final HomeStartupData? initialHomeData;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDailyReward());
  }

  Future<void> _checkDailyReward() async {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return;
    final uid = user.uid;
    final coinsEarned = await context.read<RewardsService>().claimDailyBonus();
    if (coinsEarned > 0 && mounted && auth.currentUser?.uid == uid) {
      _showSnackBar(
          '\u{1F389} Daily Check-in Bonus: +$coinsEarned Cinema Coins added to your balance!');
    }
  }

  static const Color _drawerAccent = CinemaPalette.gold;
  static const Color _drawerBackground = CinemaPalette.background;
  static const Color _drawerText = CinemaPalette.ivory;
  static const Color _drawerMuted = CinemaPalette.muted;

  // Shared set to track "My List" items (REDUNDANT: now using MyListService singleton)

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

  Future<void> _openPlayStoreRating() async {
    try {
      await const MethodChannel('moviehub/store')
          .invokeMethod<void>('openListing');
      return;
    } on PlatformException {
      // The device has neither a usable Play Store nor a browser.
    } on MissingPluginException {
      // Google Play is only supported by the Android application.
    }
    if (!mounted) return;
    _showSnackBar('Could not open Google Play. Please try again.');
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
    // Keep this drawer open beneath internal pages so Back returns to the menu
    // at its current scroll position instead of exposing the Home screen.
    return Drawer(
      backgroundColor: _drawerBackground,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
        side: BorderSide(color: Color(0x28E6BB83)),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(),
          _buildDrawerSectionLabel('YOUR EXPERIENCE'),
          _buildDrawerItem(
            title: 'Cinema Rewards',
            onTap: () {
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

  Widget _buildDrawerHeader() => Container(
        decoration: const BoxDecoration(
          gradient: CinemaPalette.appBarGradient,
          border: Border(bottom: BorderSide(color: CinemaPalette.headerBorder)),
        ),
        child: const SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 28, 24, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MOVIE HUB',
                    style: TextStyle(
                        color: CinemaPalette.appBarText,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        height: 1.2)),
                SizedBox(height: 7),
                Text('DOWNLOADER',
                    style: TextStyle(
                        color: _drawerAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3)),
                SizedBox(height: 22),
                SizedBox(
                    width: 36,
                    height: 2,
                    child: ColoredBox(color: _drawerAccent)),
                SizedBox(height: 14),
                Text('Your next great adventure starts here.',
                    style: TextStyle(
                        color: _drawerMuted, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ),
      );

  Widget _buildDrawerSectionLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
        child: Semantics(
          header: true,
          child: Text(label,
              style: const TextStyle(
                color: _drawerAccent,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
                height: 1.5,
              )),
        ),
      );

  Widget _buildAboutUsItem() => _buildLegalDrawerItem(
        title: 'About Us',
        type: LegalPageType.about,
      );

  Widget _buildDrawerFooter() {
    const version =
        String.fromEnvironment('FLUTTER_BUILD_NAME', defaultValue: '1.0.0');
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: CinemaPalette.appBarGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CinemaPalette.headerBorder),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                MovieHubIcon(size: 42),
                SizedBox(width: 14),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MOVIE HUB',
                        style: TextStyle(
                            color: CinemaPalette.appBarText,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                    SizedBox(height: 6),
                    Text('Version $version',
                        style: TextStyle(
                            color: CinemaPalette.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCopyrightPolicyItem() => _buildLegalDrawerItem(
        title: 'Copyright Policy',
        type: LegalPageType.copyright,
      );

  Widget _buildTermsOfServiceItem() => _buildLegalDrawerItem(
        title: 'Terms of Service',
        type: LegalPageType.terms,
      );

  Widget _buildLegalDrawerItem({
    required String title,
    required LegalPageType type,
  }) {
    return _buildDrawerItem(
      title: title,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LegalInfoScreen(type: type)),
        );
      },
    );
  }

  Widget _buildFAQsItem() => _buildDrawerItem(
        title: 'FAQs & Help',
        onTap: () {
          _showFAQsScreen();
        },
      );

  Widget _buildSupportItem() => _buildDrawerItem(
        title: 'Contact Support',
        onTap: () {
          _showSupportScreen();
        },
      );

  Widget _buildRateUsItem() => _buildDrawerItem(
        title: 'Rate Our App',
        onTap: () {
          Navigator.pop(context);
          _openPlayStoreRating();
        },
      );

  Widget _buildPrivacyItem() => _buildDrawerItem(
        title: 'Privacy Policy',
        onTap: () {
          _showPrivacyPolicyScreen();
        },
      );

  Widget _buildDisclaimerItem() => _buildDrawerItem(
        title: 'Legal & Disclaimer',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LegalScreen()),
          );
        },
      );

  Widget _buildDrawerItem({
    required String title,
    required VoidCallback onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: Material(
          color: CinemaPalette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: _drawerText.withValues(alpha: .055)),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(title,
                style: const TextStyle(
                    color: _drawerText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4)),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: _drawerMuted, size: 20),
            onTap: onTap,
            splashColor: Colors.transparent,
          ),
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
              _buildBottomNavItem(Icons.explore, 'Discover', 1),
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
      onTap: () {
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
