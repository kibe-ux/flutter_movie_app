import 'package:flutter/material.dart';

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
        iconColor: const Color(0xFFFF005C),
        collapsedIconColor: const Color(0xFF00D4FF),
        children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(answer,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14, height: 1.5)))
        ],
      ),
    );
  }
}