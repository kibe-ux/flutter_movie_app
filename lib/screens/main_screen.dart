import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'explore_screen.dart';
import 'search_screen.dart';
import 'premium_content_screen.dart';
import 'faqs_screen.dart';
import 'support_screen.dart';
import 'privacy_policy_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Shared set to track "My List" items
  final Set<int> _myListIds = {};

  // Colors
  final Color _primaryColor = const Color(0xFF0D0D0D);
  final Color _accentColor = const Color(0xFFFF005C);
  final Color _secondaryAccent = const Color(0xFF00D4FF);
  final Color _tertiaryAccent = const Color(0xFF9C27B0);
  final Color _surfaceColor = const Color(0xFF1A1A1A);
  final Color _onSurfaceColor = Colors.white;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(myListIds: _myListIds),
      ExploreScreen(myListIds: _myListIds),
      SearchScreen(myListIds: _myListIds),
    ];
  }

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
      _showSnackBar("Thanks for your $rating-star rating! 🎉");
    } else {
      _showSnackBar("Thanks for your feedback! We'll improve. ⭐");
      _showSupportScreen();
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
            stops: const [0.3, 0.6, 1.0],
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
                    "© 2024 Ultimate Entertainment\n50K+ Movies • 10K+ Shows. All rights reserved!",
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
      trailing: const Icon(Icons.chevron_right_rounded,
          color: Color.fromARGB(136, 255, 255, 255), size: 20),
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
