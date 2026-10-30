import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/cinema_palette.dart';

enum LegalPageType { about, copyright, terms }

class LegalInfoScreen extends StatelessWidget {
  const LegalInfoScreen({super.key, required this.type});

  final LegalPageType type;

  String get _title => switch (type) {
        LegalPageType.about => 'About Us',
        LegalPageType.copyright => 'Copyright Policy',
        LegalPageType.terms => 'Terms of Service',
      };

  IconData get _icon => switch (type) {
        LegalPageType.about => Icons.movie_filter_outlined,
        LegalPageType.copyright => Icons.copyright_outlined,
        LegalPageType.terms => Icons.gavel_outlined,
      };

  Color get _accent => CinemaPalette.gold;

  List<Color> get _heroColors =>
      const [CinemaPalette.wine, CinemaPalette.surface];

  String get _eyebrow => switch (type) {
        LegalPageType.about => 'ABOUT MOVIE HUB',
        LegalPageType.copyright => 'RIGHTS & REPORTING',
        LegalPageType.terms => 'TERMS & CONDITIONS',
      };

  String get _summary => switch (type) {
        LegalPageType.about =>
          'Discover Movie Hub, the choices available to you, and our commitment to a dependable experience.',
        LegalPageType.copyright =>
          'How we respect intellectual-property rights and review reports.',
        LegalPageType.terms =>
          'Please read these terms carefully before using Movie Hub.',
      };

  List<({String heading, String text})> get _sections => switch (type) {
        LegalPageType.about => [
            (
              heading: 'What Movie Hub does',
              text:
                  'Movie Hub is an entertainment discovery app. It helps users browse and organize information about movies and shows available through third-party sources.'
            ),
            (
              heading: 'Flexibility & Security',
              text:
                  'Explore movies and shows as a guest, or sign in whenever you want to access account features and join the community. Account authentication helps protect features tied to your identity. You stay in control of your device permissions and account choices; our Privacy Policy explains how information may be handled.'
            ),
            (
              heading: 'Continuous Support',
              text:
                  'We are committed to improving Movie Hub through maintenance, bug fixes, and thoughtful updates. Your feedback helps us identify problems, refine features, and make the app easier to use. Visit FAQs & Help for guidance or Contact Support to share an issue or suggestion.'
            ),
            (
              heading: 'Customer Support',
              text:
                  'We are dedicated to providing prompt, professional customer support. We aim to address inquiries and resolve issues efficiently, helping you enjoy a smooth, dependable experience. For assistance, open Contact Support from the navigation drawer and include the details of your question or issue so we can help you effectively.'
            ),
            (
              heading: 'Our role',
              text:
                  'We do not host, store, upload, stream, or distribute torrent files, media files, or downloads. Content availability and any external links are provided by independent third parties.'
            ),
            (
              heading: 'Your choices',
              text:
                  'Users are responsible for deciding whether to access third-party services and for complying with applicable law, platform rules, and the rights of content owners.'
            ),
          ],
        LegalPageType.copyright => [
            (
              heading: 'Respect for rights holders',
              text:
                  'We respect copyright and other intellectual-property rights. Movie Hub does not claim ownership of movie titles, artwork, metadata, trademarks, or content referenced by third-party services.'
            ),
            (
              heading: 'No hosted content',
              text:
                  'Movie Hub does not host or deliver the files made available through external services. Any access to an external site is governed by that site and its policies.'
            ),
            (
              heading: 'Copyright and DMCA notices',
              text:
                  'If you are a rights holder or authorized agent and believe an item in the app raises a copyright concern, email supportmoviehub@gmail.com. Include your name and contact details, the copyrighted work, the specific in-app item or link at issue, and a statement of your authority and good-faith belief. We will review the notice and, where appropriate, remove or disable the relevant reference. This contact is not represented as a registered DMCA designated agent.'
            ),
          ],
        LegalPageType.terms => [
            (
              heading: 'Content ownership',
              text:
                  'Movie titles, artwork, metadata, trademarks, and other material referenced in Movie Hub belong to their respective owners. Movie Hub does not claim ownership of third-party content and does not host, store, upload, stream, or distribute media files or torrent files.'
            ),
            (
              heading: 'Copyright policy and notices',
              text:
                  'We respect intellectual-property rights. Copyright or DMCA-style notices may be sent to supportmoviehub@gmail.com with your contact details, identification of the work, the relevant in-app item or link, and a statement of authority and good-faith belief. We will review reports and may remove or disable references where appropriate.'
            ),
            (
              heading: 'User responsibility',
              text:
                  'You must use the app lawfully and must not use it to infringe copyright or other rights. You are responsible for deciding whether any third-party service or material is authorized and lawful to access in your jurisdiction.'
            ),
            (
              heading: 'Limitation of liability',
              text:
                  'To the fullest extent permitted by applicable law, Movie Hub is provided without warranties of availability, accuracy, security, or fitness for a particular purpose. We are not responsible for third-party websites, content, services, downloads, or for losses arising from your use of them.'
            ),
            (
              heading: 'Modification of terms',
              text:
                  'We may update these terms as the app evolves. The updated version will be posted in the app with a revised date. Continued use after an update means you accept the revised terms.'
            ),
            (
              heading: 'Governing law',
              text:
                  'These terms are governed by applicable law. Where legally permitted, disputes will be addressed under the law and courts of the app operator\u2019s jurisdiction. Mandatory consumer-protection laws in your place of residence remain unaffected. The operator jurisdiction should be added before a public release.'
            ),
          ],
      };

  @override
  Widget build(BuildContext context) {
    const background = CinemaPalette.background;
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title:
            Text(_title, style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        foregroundColor: CinemaPalette.ivory,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: CinemaPalette.appBarGradient,
          ),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _heroColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _accent.withValues(alpha: 0.32)),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_icon, color: _accent, size: 30),
                  ),
                  const SizedBox(height: 20),
                  Text(_eyebrow,
                      style: TextStyle(
                          color: _accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.25,
                          fontSize: 11)),
                  const SizedBox(height: 8),
                  Text(_title,
                      style: const TextStyle(
                          color: CinemaPalette.ivory,
                          fontSize: 27,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(_summary,
                      style: const TextStyle(
                          color: CinemaPalette.muted, height: 1.45)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('INFORMATION',
                style: TextStyle(
                    color: _accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2)),
            const SizedBox(height: 10),
            for (final (index, section) in _sections.indexed)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: CinemaPalette.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: CinemaPalette.ivory.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text('${index + 1}',
                              style: TextStyle(
                                  color: _accent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12)),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(section.heading,
                              style: const TextStyle(
                                  color: CinemaPalette.ivory,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (section.text.contains('supportmoviehub@gmail.com'))
                      _LegalContactText(text: section.text)
                    else
                      SelectableText(section.text,
                          style: const TextStyle(
                              color: CinemaPalette.muted, height: 1.55)),
                  ],
                ),
              ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CinemaPalette.ivory.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Last updated: 19 October 2026\nKeep this information for your records and review it when using app services.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: CinemaPalette.muted, fontSize: 12, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalContactText extends StatefulWidget {
  const _LegalContactText({required this.text});
  final String text;

  @override
  State<_LegalContactText> createState() => _LegalContactTextState();
}

class _LegalContactTextState extends State<_LegalContactText> {
  static const _email = 'supportmoviehub@gmail.com';
  late final _emailTap = TapGestureRecognizer()..onTap = _openEmail;

  Future<void> _openEmail() async {
    try {
      if (await launchUrl(Uri(scheme: 'mailto', path: _email))) return;
    } catch (_) {
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      backgroundColor: CinemaPalette.wine,
      content: Text('Could not open an email app. Please email $_email.',
          style: TextStyle(color: CinemaPalette.ivory)),
    ));
  }

  @override
  void dispose() {
    _emailTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parts = widget.text.split(_email);
    return SelectableText.rich(
      TextSpan(children: [
        TextSpan(text: parts.first),
        TextSpan(
          text: _email,
          style: const TextStyle(
            color: CinemaPalette.gold,
            decoration: TextDecoration.underline,
            decorationColor: CinemaPalette.gold,
            fontWeight: FontWeight.w600,
          ),
          recognizer: _emailTap,
          mouseCursor: SystemMouseCursors.click,
        ),
        TextSpan(text: parts.last),
      ]),
      style: const TextStyle(color: CinemaPalette.muted, height: 1.55),
    );
  }
}
