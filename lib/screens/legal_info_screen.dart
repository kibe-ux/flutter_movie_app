import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../utils/cinema_palette.dart';
import '../utils/contact_email.dart';

enum LegalPageType { about, copyright, terms }

class LegalInfoScreen extends StatelessWidget {
  const LegalInfoScreen({super.key, required this.type});

  final LegalPageType type;

  String get _title => switch (type) {
        LegalPageType.about => 'About Us',
        LegalPageType.copyright => 'Copyright Policy',
        LegalPageType.terms => 'Terms of Service',
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
          'Find your next movie night, keep your favourites close, and discover more with Movie Hub.',
        LegalPageType.copyright =>
          'How we respect intellectual-property rights and review reports.',
        LegalPageType.terms =>
          'Please read these terms carefully before using Movie Hub.',
      };

  List<({String heading, String text})> get _sections => switch (type) {
        LegalPageType.about => [
            (
              heading: 'Our mission',
              text:
                  'Our mission is to make discovering movies and TV shows simple, personal, and enjoyable. Movie Hub brings browsing, title information, and your saved favourites into one place, helping you spend less time searching and more time finding stories that interest you. We want every movie lover to feel welcome, whether exploring a familiar genre or discovering something new.'
            ),
            (
              heading: 'Explore on your terms',
              text:
                  'Start exploring as a guest, or sign in to use account features and join the community. Choose how you use Movie Hub, manage your device permissions, and review your privacy options. Our Privacy Policy explains how your information is handled.'
            ),
            (
              heading: 'Always improving',
              text:
                  'We are working to make Movie Hub easier to navigate and more dependable through bug fixes, maintenance, and useful updates. Your feedback helps us understand what works, what needs attention, and which improvements matter most to you.'
            ),
            (
              heading: 'Help when you need it',
              text:
                  'Find answers in FAQs & Help, or open Contact Support from the navigation menu to ask a question or report a problem. Tell us what happened and include the app version and any relevant error message so we can investigate. Please never share your password.'
            ),
            (
              heading: 'Independent discovery',
              text:
                  'Movie Hub helps you discover and organize entertainment information supplied by third-party services. Movie titles, artwork, and other third-party materials belong to their respective owners. This application uses the TMDB API but is not endorsed or certified by TMDB.'
            ),
            (
              heading: 'Respectful, responsible use',
              text:
                  'Help keep Movie Hub welcoming by treating other community members with respect and following the community rules. Respect the rights of creators and use third-party services in accordance with their terms and applicable laws. Report inappropriate content or concerns through the available reporting and support options.'
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
              heading: 'Using Movie Hub',
              text:
                  'These terms explain the conditions for using Movie Hub, including discovery, saved collections, account features, the forum, and Cinema Rewards. Please read them alongside our Privacy Policy and Copyright Policy. If you do not agree, do not use the app. Some features are available to guests; others require a signed-in account.'
            ),
            (
              heading: 'Content ownership',
              text:
                  'Movie titles, artwork, metadata, trademarks, and other third-party materials belong to their respective owners. Movie Hub helps you discover and organize information; displaying a title does not grant permission to use copyrighted material. This application uses the TMDB API but is not endorsed or certified by TMDB.'
            ),
            (
              heading: 'Copyright policy and notices',
              text:
                  'We respect intellectual-property rights. If you are a rights holder or authorized representative, send concerns to supportmoviehub@gmail.com. Include your contact details, the work concerned, the specific in-app item, and an explanation of your authority and concern. We review reports and may remove or disable references where appropriate. See our Copyright Policy for reporting details.'
            ),
            (
              heading: 'User responsibility',
              text:
                  'Use Movie Hub lawfully and respect the rights of others. Do not attempt unauthorized access to accounts or systems, disrupt the service, submit fraudulent information, or manipulate advertising or rewards. Access third-party services only in accordance with applicable law and their terms. Never share another person\'s private information without permission.'
            ),
            (
              heading: 'Account security and deletion',
              text:
                  'Provide accurate account details and keep your sign-in credentials private. You are responsible for activity you authorize through your account. If you suspect unauthorized access, secure your account and contact Support. Request account deletion from Profile and complete the verification and confirmation steps. Cleanup may continue after a request is accepted. Uninstalling the app does not delete your account; our Privacy Policy explains deletion and retention.'
            ),
            (
              heading: 'Privacy and saved information',
              text:
                  'Our Privacy Policy explains the information used by Movie Hub and connected services, your privacy choices, and how to contact us about your data. Some saved titles, preferences, and history are stored on your device. Clearing app storage or reinstalling may remove them, and signing in does not by itself guarantee that device-only information is backed up or transferred.'
            ),
            (
              heading: 'Advertising and your choices',
              text:
                  'Movie Hub includes advertising. Ad availability and content can vary, and an advertisement is not an endorsement by Movie Hub. Where required and available, use Ad privacy choices to review your consent. Do not generate artificial ad views or clicks, or encourage others to do so. Rewarded ads are optional and are explained separately below.'
            ),
            (
              heading: 'Forum rules and account suspension',
              text:
                  'Follow the community rules and keep discussions respectful. Do not post harassment, hate speech, threats, sexually explicit or exploitative material, scams, spam, impersonation, unlawful content, or material you do not have permission to share. Use report and block tools to raise concerns and manage interactions. We may remove rule-breaking content or restrict accounts for serious or repeated violations. Contact Support with the relevant details if you believe a decision is incorrect.'
            ),
            (
              heading: 'Cinema Coins, rewarded ads, and redemption',
              text:
                  'Cinema Coins are account-bound promotional credits for the rewards displayed in Cinema Rewards. They have no cash value and cannot be sold, transferred, or exchanged for money. Each rewarded ad requires your choice, with its reward disclosed beforehand; declining does not prevent normal browsing. In live mode, completing the required action earns the disclosed reward after verification, which may take time. Test ads do not award spendable coins. Redemption requires an eligible signed-in account and sufficient confirmed coins. Review the cost and duration before confirming. A successful redemption deducts the stated coins and starts the selected ad-free pass immediately. Pass time continues while the app is closed, and another redemption extends an active pass. Movie Hub is responsible for delivering its rewards; contact Support if a completed reward is missing.'
            ),
            (
              heading: 'Availability and third-party services',
              text:
                  'We work to keep Movie Hub useful and dependable, but uninterrupted access, error-free operation, and the accuracy or continued availability of third-party information cannot be guaranteed. Features may be affected by maintenance, connectivity, or provider changes. External services operate under their own terms and privacy policies. Report problems through Support so we can investigate.'
            ),
            (
              heading: 'Modification of terms',
              text:
                  'We may revise these terms when features, service practices, or applicable requirements change. The current version is available in the app with its revision date. Review updated terms before continuing to use Movie Hub. Changes do not remove rights or obligations that applicable law requires us to preserve.'
            ),
            (
              heading: 'Your rights and resolving concerns',
              text:
                  'Nothing in these terms is intended to exclude rights or remedies that cannot lawfully be excluded, including mandatory consumer protections. For a concern about the app, your account, moderation, or rewards, contact supportmoviehub@gmail.com with enough detail for us to investigate. Do not include passwords. Contacting Support does not prevent you from using other remedies available under applicable law.'
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
              child: Text(
                'Last updated: ${switch (type) {
                  LegalPageType.about => '16 November 2026',
                  LegalPageType.terms => '16 November 2026',
                  LegalPageType.copyright => '19 October 2026',
                }}\nKeep this information for your records and review it when using app services.',
                textAlign: TextAlign.center,
                style: const TextStyle(
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
    await openContactEmail(context,
        email: _email, subject: 'Movie Hub Legal Inquiry');
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
