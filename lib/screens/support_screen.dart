import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  void _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@flixorax.com',
      queryParameters: {
        'subject': 'FLIXORA X Support Request',
        'body': 'Hello FLIXORA X Team,\n\nI need help with:'
      },
    );
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
              gradient: const LinearGradient(colors: [
                Color(0xFFFF005C),
                Color(0xFF9C27B0),
                Color(0xFF00D4FF)
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.help_center_rounded, size: 60, color: Colors.white),
                const SizedBox(height: 16),
                const Text("We're Here to Help!",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text(
                    "Get instant support for any issues or questions about FLIXORA X",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text("Contact Options",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildContactOption(Icons.email_rounded, "Email Support",
              "Get detailed help via email", const Color(0xFFFF005C), _launchEmail),
          _buildContactOption(Icons.phone_rounded, "Call Support",
              "24/7 customer service", const Color(0xFF00D4FF), _launchPhone),
          _buildContactOption(Icons.language_rounded, "Visit Website",
              "Learn more about FLIXORA X", const Color(0xFF9C27B0), _launchWebsite),
          const SizedBox(height: 24),
          const Text("Quick Help",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildQuickHelpItem("Report a Bug", "Found an issue? Let us know",
              Icons.bug_report_rounded, const Color(0xFFFF005C)),
          _buildQuickHelpItem("Feature Request", "Suggest new features",
              Icons.lightbulb_rounded, const Color(0xFF00D4FF)),
          _buildQuickHelpItem("Movie Request", "Request missing content",
              Icons.movie_creation_rounded, const Color(0xFF9C27B0)),
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
                Icon(Icons.access_time_filled_rounded,
                    color: const Color(0xFF00D4FF), size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Average Response Time",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Text(
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
      color: const Color(0xFF1A1A1A),
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
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
        color: const Color(0xFF1A1A1A),
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
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        trailing: Icon(Icons.chevron_right_rounded, color: color, size: 20),
        onTap: () {},
      ),
    );
  }
}
