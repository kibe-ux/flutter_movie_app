import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'home_screen.dart';
import 'explore_screen.dart';
import 'search_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final Color _primaryColor = const Color(0xFF0D0D0D);
  final Color _accentColor = const Color(0xFFFF005C);
  final Color _secondaryAccent = const Color(0xFF00D4FF);
  final Color _tertiaryAccent = const Color(0xFF9C27B0);
  final Color _surfaceColor = const Color(0xFF1A1A1A);
  final Color _onSurfaceColor = Colors.white;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ExploreScreen(),
    const SearchScreen(),
  ];

  void _onItemTapped(int index) {
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

  void _showPremiumContentScreen() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const PremiumContentScreen()));
  }

  void _showRateUsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _surfaceColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.star, color: _secondaryAccent, size: 32),
              const SizedBox(width: 12),
              Text("Rate FLIXORA X",
                  style: TextStyle(
                      color: _onSurfaceColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("How would you rate your experience?",
                  style: TextStyle(
                      color: _onSurfaceColor.withOpacity(0.8), fontSize: 16)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      _handleRating(index + 1);
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child:
                          Icon(Icons.star, color: _secondaryAccent, size: 36),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Text("Tap a star to rate",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _onSurfaceColor.withOpacity(0.6), fontSize: 14)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Maybe Later",
                  style: TextStyle(color: _secondaryAccent, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  void _handleRating(int rating) {
    if (rating >= 4) {
      _showSnackBar("Thanks for your ${rating}-star rating! 🎉");
    } else {
      _showSnackBar("Thanks for your feedback! We'll improve. ⭐");
      _showSupportScreen();
    }
  }

  void _launchStoreURL() async {
    final Uri url = Uri.parse(
        'https://play.google.com/store/apps/details?id=your.package.name');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showSnackBar("Could not open store page");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryColor,
      appBar: _selectedIndex == 0 ? _buildAppBar() : null,
      drawer: _buildNavigationDrawer(),
      body: _screens[_selectedIndex],
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 90,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryColor, _primaryColor.withOpacity(0.9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      title: ShaderMask(
        shaderCallback: (bounds) {
          return LinearGradient(
            colors: [_accentColor, _secondaryAccent, _tertiaryAccent],
            stops: [0.3, 0.6, 1.0],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(bounds);
        },
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("FLIXORA ",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
            Text("X",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
          ],
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildNavigationDrawer() {
    return Drawer(
      backgroundColor: _primaryColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accentColor, _secondaryAccent, _tertiaryAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.movie_filter_rounded,
                      size: 70, color: _onSurfaceColor),
                ),
                const SizedBox(height: 16),
                ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      colors: [_onSurfaceColor, _secondaryAccent, _accentColor],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(bounds);
                  },
                  child: const Text("FLIXORA X",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2)),
                ),
                const SizedBox(height: 8),
                Text("Unlimited Movies & Shows",
                    style: TextStyle(
                        color: _onSurfaceColor.withOpacity(0.9), fontSize: 16)),
              ],
            ),
          ),
          _buildPremiumContentItem(),
          _buildDrawerItem("⭐ Favorites", Icons.favorite_rounded, _accentColor),
          const Divider(color: Colors.white24),
          _buildFAQsItem(),
          _buildSupportItem(),
          _buildRateUsItem(),
          _buildPrivacyItem(),
          const Divider(color: Colors.white24),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text("FLIXORA X  v1.0.0",
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text(
                    "© 2024 Ultimate Entertainment\n50K+ Movies • 10K+ Shows . All rights reserved!",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(String title, IconData icon, Color color) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
      trailing:
          Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
      onTap: () {
        Navigator.pop(context);
        _showSnackBar("$title • Coming Soon!");
      },
    );
  }

  Widget _buildPremiumContentItem() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accentColor, _tertiaryAccent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _onSurfaceColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.workspace_premium_rounded,
              color: _onSurfaceColor, size: 24),
        ),
        title: const Text("🚀 Premium Access",
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        subtitle: const Text("Unlock exclusive content",
            style: TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _onSurfaceColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text("PRO",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
        onTap: () {
          Navigator.pop(context);
          _showPremiumContentScreen();
        },
      ),
    );
  }

  Widget _buildFAQsItem() {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _secondaryAccent.withOpacity(0.3),
              _secondaryAccent.withOpacity(0.1)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child:
            Icon(Icons.help_outline_rounded, color: _secondaryAccent, size: 24),
      ),
      title: const Text("❓ FAQs & Help",
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
      trailing:
          Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
      onTap: () {
        Navigator.pop(context);
        _showFAQsScreen();
      },
    );
  }

  Widget _buildSupportItem() {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _secondaryAccent.withOpacity(0.3),
              _secondaryAccent.withOpacity(0.1)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child:
            Icon(Icons.help_center_rounded, color: _secondaryAccent, size: 24),
      ),
      title: const Text("📞 Contact Support",
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
      trailing:
          Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
      onTap: () {
        Navigator.pop(context);
        _showSupportScreen();
      },
    );
  }

  Widget _buildRateUsItem() {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _accentColor.withOpacity(0.3),
              _accentColor.withOpacity(0.1)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.star_rate_rounded, color: _accentColor, size: 24),
      ),
      title: const Text("⭐ Rate Our App",
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.chevron_right_rounded,
          color: const Color.fromARGB(136, 255, 255, 255), size: 20),
      onTap: () {
        Navigator.pop(context);
        _showRateUsDialog();
      },
    );
  }

  Widget _buildPrivacyItem() {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _tertiaryAccent.withOpacity(0.3),
              _tertiaryAccent.withOpacity(0.1)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.security_rounded, color: _tertiaryAccent, size: 24),
      ),
      title: const Text("🔒 Privacy Policy",
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
      trailing:
          Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
      onTap: () {
        Navigator.pop(context);
        _showPrivacyPolicyScreen();
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor, _primaryColor.withOpacity(0.95)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 20,
              offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(Icons.home_filled, 'Home', 0),
              _buildBottomNavItem(Icons.explore, 'Explore', 1),
              _buildBottomNavItem(Icons.search, 'Search', 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [_accentColor, _secondaryAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? _onSurfaceColor
                  : _onSurfaceColor.withOpacity(0.6),
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color:
                  isSelected ? _accentColor : _onSurfaceColor.withOpacity(0.6),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
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

class PremiumContentScreen extends StatelessWidget {
  const PremiumContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Premium Content",
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFF005C),
                  Color(0xFF9C27B0),
                  Color(0xFF00D4FF)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF0D0D0D).withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.workspace_premium_rounded,
                      size: 60, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text("FLIXORA X PREMIUM",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2)),
                const SizedBox(height: 12),
                Text("Unlock Everything • Ad-Free • 4K HDR",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.9), fontSize: 16)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildPremiumFeatureSection(),
                const SizedBox(height: 24),
                _buildExclusiveMoviesSection(),
                const SizedBox(height: 24),
                _buildPremiumBenefits(),
                const SizedBox(height: 24),
                _buildUpgradeButton(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeatureSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFF005C).withOpacity(0.1),
            Color(0xFF00D4FF).withOpacity(0.1)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFFFF005C).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.star_rounded, color: Color(0xFFFF005C), size: 28),
            const SizedBox(width: 12),
            Text("Premium Features",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold))
          ]),
          const SizedBox(height: 16),
          _buildFeatureItem("🎬 Exclusive Movies & Shows",
              "Early access to new releases", Icons.movie_creation_rounded),
          _buildFeatureItem("📺 Ad-Free Experience",
              "Watch without interruptions", Icons.no_accounts_rounded),
          _buildFeatureItem("🎯 4K Ultra HD Streaming",
              "Highest quality available", Icons.hd_rounded),
          _buildFeatureItem("📱 Multiple Devices",
              "Watch on phone, tablet, and TV", Icons.devices_rounded),
          _buildFeatureItem("💾 Offline Downloads", "Download and watch later",
              Icons.download_for_offline_rounded),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF00D4FF).withOpacity(0.3),
                  Color(0xFFFF005C).withOpacity(0.3)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExclusiveMoviesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Exclusive Premium Content",
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPremiumMovieCard("Avengers: Endgame", "4.9 ⭐"),
              _buildPremiumMovieCard("Dune: Part Two", "4.8 ⭐"),
              _buildPremiumMovieCard("John Wick 4", "4.7 ⭐"),
              _buildPremiumMovieCard("Oppenheimer", "4.9 ⭐"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumMovieCard(String title, String rating) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Color(0xFFFF005C), Color(0xFF9C27B0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                    color: Color(0xFFFF005C).withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 6))
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFF0D0D0D).withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(rating,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_open_rounded,
                          color: Colors.white, size: 40),
                      const SizedBox(height: 8),
                      Text("PREMIUM",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
              maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildPremiumBenefits() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF00D4FF).withOpacity(0.1),
            Color(0xFF9C27B0).withOpacity(0.1)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFF00D4FF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.workspace_premium_rounded,
                color: Color(0xFF00D4FF), size: 28),
            const SizedBox(width: 12),
            Text("Why Go Premium?",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold))
          ]),
          const SizedBox(height: 16),
          _buildBenefitItem(
              "🚀 Early Access", "Watch new releases 30 days early"),
          _buildBenefitItem("🌟 Premium Support", "Priority customer service"),
          _buildBenefitItem("🎵 Dolby Atmos", "Immersive audio experience"),
          _buildBenefitItem(
              "📊 Watch Statistics", "Detailed viewing analytics"),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Color(0xFF00D4FF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF005C), Color(0xFF9C27B0)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text("Ready to Upgrade?",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Join thousands of satisfied premium users",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.9), fontSize: 16)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text("₹299",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text("/month",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 16)),
                        ],
                      ),
                      Text("7-day free trial • Cancel anytime",
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14)),
                    ]),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("🎉 Premium upgrade coming soon!"),
                      backgroundColor: Color(0xFF00D4FF),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Color(0xFFFF005C),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                  ),
                  child: Text("UPGRADE NOW",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FAQsScreen extends StatelessWidget {
  const FAQsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("FAQs & Help",
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildFAQItem("How do I search for movies?",
              "Use the Search tab at the bottom navigation. You can search by title, genre, actor, or director."),
          _buildFAQItem("Is FLIXORA X free to use?",
              "Yes! FLIXORA X is completely free with access to thousands of movies and TV shows."),
          _buildFAQItem("Can I download movies for offline viewing?",
              "Currently, we don't support offline downloads. All content is streamed online."),
          _buildFAQItem("How often is new content added?",
              "We add new movies and shows every week. Check the Explore section for latest additions."),
          _buildFAQItem("Do I need to create an account?",
              "No account required! Enjoy all features without any registration."),
          _buildFAQItem("How do I report a problem?",
              "Go to Support in the menu to contact our team. We typically respond within 24 hours."),
          _buildFAQItem("What video qualities are available?",
              "We support multiple qualities from 480p to 4K, depending on your internet connection."),
          _buildFAQItem("Can I request specific movies?",
              "Yes! Use the Support section to send us your movie requests. We consider all suggestions."),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Text(question,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(answer,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14, height: 1.5)))
        ],
        iconColor: Color(0xFFFF005C),
        collapsedIconColor: Color(0xFF00D4FF),
      ),
    );
  }
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  void _launchEmail() async {
    final Uri emailLaunchUri =
        Uri(scheme: 'mailto', path: 'support@flixorax.com', queryParameters: {
      'subject': 'FLIXORA X Support Request',
      'body': 'Hello FLIXORA X Team,\n\nI need help with:'
    });
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
  }

  void _launchPhone() async {
    final Uri phoneLaunchUri = Uri(scheme: 'tel', path: '+11234567890');
    if (await canLaunchUrl(phoneLaunchUri)) {
      await launchUrl(phoneLaunchUri);
    }
  }

  void _launchWebsite() async {
    final Uri websiteLaunchUri = Uri(scheme: 'https', host: 'www.flixorax.com');
    if (await canLaunchUrl(websiteLaunchUri)) {
      await launchUrl(websiteLaunchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Support Center",
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Color(0xFFFF005C),
                Color(0xFF9C27B0),
                Color(0xFF00D4FF)
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(Icons.help_center_rounded, size: 60, color: Colors.white),
                const SizedBox(height: 16),
                Text("We're Here to Help!",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                    "Get instant support for any issues or questions about FLIXORA X",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.9), fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text("Contact Options",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildContactOption(Icons.email_rounded, "Email Support",
              "Get detailed help via email", Color(0xFFFF005C), _launchEmail),
          _buildContactOption(Icons.phone_rounded, "Call Support",
              "24/7 customer service", Color(0xFF00D4FF), _launchPhone),
          _buildContactOption(Icons.language_rounded, "Visit Website",
              "Learn more about FLIXORA X", Color(0xFF9C27B0), _launchWebsite),
          const SizedBox(height: 24),
          Text("Quick Help",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildQuickHelpItem("Report a Bug", "Found an issue? Let us know",
              Icons.bug_report_rounded, Color(0xFFFF005C)),
          _buildQuickHelpItem("Feature Request", "Suggest new features",
              Icons.lightbulb_rounded, Color(0xFF00D4FF)),
          _buildQuickHelpItem("Movie Request", "Request missing content",
              Icons.movie_creation_rounded, Color(0xFF9C27B0)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFF00D4FF).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_filled_rounded,
                    color: Color(0xFF00D4FF), size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Average Response Time",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text(
                          "We typically respond within 2-4 hours during business hours",
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactOption(IconData icon, String title, String subtitle,
      Color color, VoidCallback onTap) {
    return Card(
      color: Color(0xFF1A1A1A),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title,
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: TextStyle(color: Colors.white70, fontSize: 14)),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildQuickHelpItem(
      String title, String subtitle, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: TextStyle(color: Colors.white, fontSize: 16)),
        subtitle: Text(subtitle,
            style: TextStyle(color: Colors.white70, fontSize: 14)),
        trailing: Icon(Icons.chevron_right_rounded, color: color, size: 20),
        onTap: () {},
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Privacy Policy",
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Color(0xFF00D4FF),
                Color(0xFF9C27B0),
                Color(0xFFFF005C)
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(Icons.security_rounded, size: 60, color: Colors.white),
                const SizedBox(height: 16),
                Text("Privacy & Data Protection",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text("Your privacy is important to us",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.9), fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFF00D4FF).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.update_rounded, color: Color(0xFF00D4FF), size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Last Updated",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text("June 2025",
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildPrivacySection(
              "Information We Collect",
              [
                "• App usage statistics and analytics",
                "• Device information for optimization",
                "• Search queries and viewing preferences",
                "• Crash reports and performance data"
              ],
              Icons.collections_bookmark_rounded,
              Color(0xFF00D4FF)),
          _buildPrivacySection(
              "How We Use Your Information",
              [
                "• Improve app performance and user experience",
                "• Personalize content recommendations",
                "• Fix bugs and technical issues",
                "• Analyze usage patterns for better service"
              ],
              Icons.analytics_rounded,
              Color(0xFFFF005C)),
          _buildPrivacySection(
              "Data Protection",
              [
                "• We do not sell your personal data",
                "• Anonymous data collection only",
                "• Industry-standard security measures",
                "• Regular security audits and updates"
              ],
              Icons.shield_rounded,
              Color(0xFF9C27B0)),
          _buildPrivacySection(
              "Third-Party Services",
              [
                "• TMDB API for movie data",
                "• Google Analytics for app insights",
                "• Crash reporting services",
                "• All partners are GDPR compliant"
              ],
              Icons.extension_rounded,
              Color(0xFF00D4FF)),
          _buildPrivacySection(
              "Your Rights",
              [
                "• Access your personal data",
                "• Request data deletion",
                "• Opt-out of analytics",
                "• Contact us for privacy concerns"
              ],
              Icons.people_rounded,
              Color(0xFFFF005C)),
          _buildPrivacySection(
              "Contact Information",
              [
                "For privacy-related questions:",
                "Email: privacy@flixorax.com",
                "We respond within 48 hours"
              ],
              Icons.contact_support_rounded,
              Color(0xFF9C27B0)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFFFF005C).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_rounded, color: Color(0xFFFF005C), size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Important Note",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text(
                          "By using FLIXORA X, you agree to our Terms of Service and Privacy Policy. We may update this policy periodically.",
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPrivacySection(
      String title, List<String> points, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title,
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: points
                  .map((point) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(top: 8, right: 12),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                                child: Text(point,
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 15,
                                        height: 1.4))),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
        iconColor: color,
        collapsedIconColor: color,
      ),
    );
  }
}