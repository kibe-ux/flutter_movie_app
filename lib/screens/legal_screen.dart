import 'package:flutter/material.dart';
import '../utils/cinema_palette.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  static const _disclaimer = 'Legal Disclaimer\n\n'
      'Movie Hub helps you discover and organize information about movies and TV shows. Information and artwork supplied by third-party services are provided for reference and may change or become unavailable.\n\n'
      'Movie titles, posters, images, trademarks, and other third-party materials remain the property of their respective owners. Their inclusion in Movie Hub does not imply sponsorship, affiliation, or permission to use copyrighted material beyond what the rights holder or applicable law allows.\n\n'
      'This application uses the TMDB API but is not endorsed or certified by TMDB.\n\n'
      'Third-party services operate independently and are subject to their own terms and privacy policies. We do not guarantee the accuracy, completeness, availability, or security of information or services provided by others.\n\n'
      'Use Movie Hub responsibly, respect intellectual-property rights, and follow applicable laws and the terms of any services you access. For a concern about information or material shown in the app, contact Support and identify the relevant item so we can review it.\n\n'
      'Please also read our Terms of Service, Copyright Policy, and Privacy Policy for details about using Movie Hub and how information is handled.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinemaPalette.background,
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
        title: const Text('Legal & Disclaimer',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [CinemaPalette.wine, CinemaPalette.surface],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: CinemaPalette.gold.withValues(alpha: 0.28),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Legal information',
                      style: TextStyle(
                          color: CinemaPalette.ivory,
                          fontSize: 27,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text('Please read this information before using the app.',
                      style:
                          TextStyle(color: CinemaPalette.muted, height: 1.45)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CinemaPalette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: CinemaPalette.ivory.withValues(alpha: 0.08)),
              ),
              child: const SelectableText(
                _disclaimer,
                style: TextStyle(
                  fontSize: 14,
                  color: CinemaPalette.muted,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Last updated: 16 November 2026',
              textAlign: TextAlign.center,
              style: TextStyle(color: CinemaPalette.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
