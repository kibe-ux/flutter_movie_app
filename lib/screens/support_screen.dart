import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});
  final Color _primaryColor = const Color(0xFF0D0D0D);
  final Color _accentColor = const Color(0xFFFF005C);
  final Color _secondaryAccent = const Color(0xFF00D4FF);
  final Color _tertiaryAccent = const Color(0xFF9C27B0);
  final Color _surfaceColor = const Color(0xFF1A1A1A);
  final Color _onSurfaceColor = Colors.white;
  Future<void> _launchEmail({String subject = '', String body = ''}) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@flixorax.com',
      queryParameters: {
        'subject': subject.isNotEmpty ? subject : 'FLIXORA X Support Request',
        'body': body.isNotEmpty ? body : 'Hello FLIXORA X Team,\n\nI need help with:'
      },
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: const Text('Cannot launch email app. Email: support@flixorax.com'),
          backgroundColor: _accentColor,
        ),
      );
    }
  }
  Future<void> _launchPhone() async {
    final Uri phoneLaunchUri = Uri(scheme: 'tel', path: '+11234567890');
    
    if (await canLaunchUrl(phoneLaunchUri)) {
      await launchUrl(phoneLaunchUri);
    } else {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: const Text('Cannot make phone call. Number: +1 123-456-7890'),
          backgroundColor: _secondaryAccent,
        ),
      );
    }
  }
  Future<void> _launchWebsite() async {
    const String url = 'https://www.flixorax.com';
    final Uri websiteLaunchUri = Uri.parse(url);
    if (await canLaunchUrl(websiteLaunchUri)) {
      await launchUrl(websiteLaunchUri);
    } else {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Text('Cannot open website. Visit: $url'),
          backgroundColor: _tertiaryAccent,
        ),
      );
    }
  }
  void _showBugReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String bugDescription = '';
        String stepsToReproduce = '';
        
        return AlertDialog(
          backgroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.bug_report_rounded, color: _accentColor, size: 32),
              const SizedBox(width: 12),
              Text("Report a Bug",
                  style: TextStyle(
                      color: _onSurfaceColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Describe the bug you encountered:",
                    style: TextStyle(color: _onSurfaceColor.withValues(alpha: 0.8), fontSize: 16)),
                const SizedBox(height: 12),
                TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'What happened?',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    filled: true,
                    fillColor: Colors.grey.shade900,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (value) => bugDescription = value,
                ),
                const SizedBox(height: 16),
                Text("Steps to reproduce:",
                    style: TextStyle(color: _onSurfaceColor.withValues(alpha: 0.8), fontSize: 16)),
                const SizedBox(height: 12),
                TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '1. Open app\n2. Click...\n3. Error appears',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    filled: true,
                    fillColor: Colors.grey.shade900,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (value) => stepsToReproduce = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: _secondaryAccent, fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () {
                if (bugDescription.isNotEmpty) {
                  _launchEmail(
                    subject: 'Bug Report - FLIXORA X',
                    body: 'Bug Description:\n$bugDescription\n\nSteps to Reproduce:\n$stepsToReproduce\n\nDevice Info: [Please describe your device]',
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Bug report submitted successfully!'),
                      backgroundColor: _accentColor,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Submit Report", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }
  void _showFeatureRequestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String featureDescription = '';
        String whyImportant = '';
        return AlertDialog(
          backgroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.lightbulb_rounded, color: _secondaryAccent, size: 32),
              const SizedBox(width: 12),
              Text("Request Feature",
                  style: TextStyle(
                      color: _onSurfaceColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Describe your feature idea:",
                    style: TextStyle(color: _onSurfaceColor.withValues(alpha: 0.8), fontSize: 16)),
                const SizedBox(height: 12),
                TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'What feature would you like to see?',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    filled: true,
                    fillColor: Colors.grey.shade900,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (value) => featureDescription = value,
                ),
                const SizedBox(height: 16),
                Text("Why is this important?",
                    style: TextStyle(color: _onSurfaceColor.withValues(alpha: 0.8), fontSize: 16)),
                const SizedBox(height: 12),
                TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'How would this improve your experience?',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    filled: true,
                    fillColor: Colors.grey.shade900,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (value) => whyImportant = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: _secondaryAccent, fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () {
                if (featureDescription.isNotEmpty) {
                  _launchEmail(
                    subject: 'Feature Request - FLIXORA X',
                    body: 'Feature Idea:\n$featureDescription\n\nWhy Important:\n$whyImportant',
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Feature request submitted!'),
                      backgroundColor: _secondaryAccent,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _secondaryAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Submit Request", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }
  void _showMovieRequestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String movieTitle = '';
        String movieYear = '';
        return AlertDialog(
          backgroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.movie_creation_rounded, color: _tertiaryAccent, size: 32),
              const SizedBox(width: 12),
              Text("Request Movie",
                  style: TextStyle(
                      color: _onSurfaceColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Movie Title:",
                    style: TextStyle(color: _onSurfaceColor.withValues(alpha: 0.8), fontSize: 16)),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Enter movie or show title',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    filled: true,
                    fillColor: Colors.grey.shade900,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (value) => movieTitle = value,
                ),
                const SizedBox(height: 16),
                Text("Year (Optional):",
                    style: TextStyle(color: _onSurfaceColor.withValues(alpha: 0.8), fontSize: 16)),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'e.g., 2023',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    filled: true,
                    fillColor: Colors.grey.shade900,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => movieYear = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: _secondaryAccent, fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () {
                if (movieTitle.isNotEmpty) {
                  String yearText = movieYear.isNotEmpty ? ' ($movieYear)' : '';
                  _launchEmail(
                    subject: 'Movie Request - FLIXORA X',
                    body: 'I would like to request:\n\nMovie/Show: $movieTitle$yearText\n\nAdditional Notes: [Any specific details about this request]',
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Movie request for "$movieTitle" submitted!'),
                      backgroundColor: _tertiaryAccent,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _tertiaryAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Submit Request", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Support Center", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accentColor, _tertiaryAccent, _secondaryAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.help_center_rounded, size: 60, color: Colors.white),
                const SizedBox(height: 16),
                const Text("We're Here to Help!", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text("Get instant support for any issues or questions about FLIXORA X", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text("Contact Options", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildContactOption(Icons.email_rounded, "Email Support", "Get detailed help via email", _accentColor, () => _launchEmail()),
          _buildContactOption(Icons.phone_rounded, "Call Support", "24/7 customer service", _secondaryAccent, _launchPhone),
          _buildContactOption(Icons.language_rounded, "Visit Website", "Learn more about FLIXORA X", _tertiaryAccent, _launchWebsite),
          const SizedBox(height: 24),
          const Text("Quick Help", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildQuickHelpItem(context, "Report a Bug", "Found an issue? Let us know", Icons.bug_report_rounded, _accentColor, () => _showBugReportDialog(context)),
          _buildQuickHelpItem(context, "Feature Request", "Suggest new features", Icons.lightbulb_rounded, _secondaryAccent, () => _showFeatureRequestDialog(context)),
          _buildQuickHelpItem(context, "Movie Request", "Request missing content", Icons.movie_creation_rounded, _tertiaryAccent, () => _showMovieRequestDialog(context)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _secondaryAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_filled_rounded, color: _secondaryAccent, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Average Response Time", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const Text("We typically respond within 2-4 hours during business hours", style: TextStyle(color: Colors.white70, fontSize: 14)),
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

  Widget _buildContactOption(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Card(
      color: _surfaceColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
        ),
        onTap: onTap,
      ),
    );
  }
  Widget _buildQuickHelpItem(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        trailing: Icon(Icons.chevron_right_rounded, color: color, size: 20),
        onTap: onTap,
      ),
    );
  }
}
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
