import 'package:flutter/material.dart';

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
              gradient: const LinearGradient(colors: [
                Color(0xFF00D4FF),
                Color(0xFF9C27B0),
                Color(0xFFFF005C)
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.security_rounded, size: 60, color: Colors.white),
                const SizedBox(height: 16),
                const Text("Privacy & Data Protection",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text("Your privacy is important to us",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.update_rounded, color: const Color(0xFF00D4FF), size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Last Updated",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Text("June 2025",
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
              const [
                "• App usage statistics and analytics",
                "• Device information for optimization",
                "• Search queries and viewing preferences",
                "• Crash reports and performance data"
              ],
              Icons.collections_bookmark_rounded,
              const Color(0xFF00D4FF)),
          _buildPrivacySection(
              "How We Use Your Information",
              const [
                "• Improve app performance and user experience",
                "• Personalize content recommendations",
                "• Fix bugs and technical issues",
                "• Analyze usage patterns for better service"
              ],
              Icons.analytics_rounded,
              const Color(0xFFFF005C)),
          _buildPrivacySection(
              "Data Protection",
              const [
                "• We do not sell your personal data",
                "• Anonymous data collection only",
                "• Industry-standard security measures",
                "• Regular security audits and updates"
              ],
              Icons.shield_rounded,
              const Color(0xFF9C27B0)),
          _buildPrivacySection(
              "Third-Party Services",
              const [
                "• TMDB API for movie data",
                "• Google Analytics for app insights",
                "• Crash reporting services",
                "• All partners are GDPR compliant"
              ],
              Icons.extension_rounded,
              const Color(0xFF00D4FF)),
          _buildPrivacySection(
              "Your Rights",
              const [
                "• Access your personal data",
                "• Request data deletion",
                "• Opt-out of analytics",
                "• Contact us for privacy concerns"
              ],
              Icons.people_rounded,
              const Color(0xFFFF005C)),
          _buildPrivacySection(
              "Contact Information",
              const [
                "For privacy-related questions:",
                "Email: privacy@flixorax.com",
                "We respond within 48 hours"
              ],
              Icons.contact_support_rounded,
              const Color(0xFF9C27B0)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFF005C).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_rounded, color: const Color(0xFFFF005C), size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Important Note",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Text(
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
        color: const Color(0xFF1A1A1A),
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
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        iconColor: color,
        collapsedIconColor: color,
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
                                    style: const TextStyle(
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
      ),
    );
  }
}
