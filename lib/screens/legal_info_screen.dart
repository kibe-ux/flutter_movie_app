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
              heading: 'What you can do with Movie Hub',
              text:
                  'Browse movies and TV shows, explore title details, save favourites and personal lists, and take part in community discussions. Available features may vary depending on whether you are browsing as a guest or signed in.'
            ),
            (
              heading: 'Always improving',
              text:
                  'We are working to make Movie Hub easier to navigate and more dependable through bug fixes, maintenance, and useful updates. Your feedback helps us understand what works, what needs attention, and which improvements matter most to you.'
            ),
            (
              heading: 'Our commitment',
              text:
                  'We aim to make Movie Hub welcoming and useful, respect the rights of creators and our community, and keep improving the app based on feedback. We work to explain our features and policies clearly so you can make informed choices while using Movie Hub.'
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
                  'We respect and are committed to protecting copyright and other intellectual-property rights. Movie Hub does not claim ownership of movie titles, images, artwork, metadata, trademarks, or other third-party materials shown or referenced in the app; those rights belong to their respective owners.'
            ),
            (
              heading: 'No hosted content',
              text:
                  'Movie Hub does not host or deliver movie files. Files stored or shared by users on their own devices or through external services are not hosted on our app. Access to an external site is governed by that site and its policies.'
            ),
            (
              heading: 'Copyright and DMCA notices',
              text:
                  'We review copyright notices under applicable law, including the Digital Millennium Copyright Act (DMCA) where it applies. Rights holders and their authorized agents can send a formal notice using the separate Infringing notice requirements and Takedown requests and infringement reports sections below.'
            ),
            (
              heading: 'Infringing notice requirements',
              text:
                  '• The title or identification of the copyrighted work.\n• A description of the material you believe is infringing and its exact location in the app, such as a page or link.\n• Your contact information, including name, mailing address, email address, and phone number.\n• A statement that you have a good-faith belief the use is not authorized by the rights holder, its agent, or the law.\n• A statement that the information in your notice is accurate and, where required by law, that you are authorized to act for the rights holder.\n• Your physical or electronic signature.'
            ),
            (
              heading: 'Review of notices',
              text:
                  'We will review notices and, where appropriate and consistent with applicable law, remove or disable the relevant reference. This contact is not represented as a registered DMCA designated agent.'
            ),
            (
              heading: 'Takedown requests',
              text:
                  'Rights holders or their authorized agents may request that an allegedly infringing reference be removed or disabled. Email supportmoviehub@gmail.com with the item’s title and exact in-app location, your contact details, and the notice information listed above. We will review the request and take appropriate action consistent with applicable law.'
            ),
            (
              heading: 'Reporting infringement',
              text:
                  'To report a suspected copyright concern, email supportmoviehub@gmail.com. Include the title and in-app page or link, describe the concern, and provide your contact details. You do not need to be the rights holder to report a concern. We will review reports and may remove or disable a reference where appropriate and consistent with applicable law.'
            ),
            (
              heading: 'Content sourcing',
              text:
                  'Movie Hub aims to provide access only to content that is legally available. We take reasonable steps to review sources and expect them to comply with applicable copyright laws and this policy. Sources are external services, and we cannot guarantee their content or practices.'
            ),
            (
              heading: 'Legal compliance and piracy',
              text:
                  'Movie Hub expects everyone to follow applicable copyright laws and the terms of third-party services. We have no tolerance for piracy or attempts to use the app to find, share, or promote unauthorized copies of copyrighted works. Do not use Movie Hub or external links reached through it for unlawful access or distribution. Report suspected infringement to supportmoviehub@gmail.com. We will review reports and may remove or disable references where appropriate and consistent with applicable law.'
            ),
          ],
        LegalPageType.terms => [
            (
              heading: 'Using Movie Hub',
              text:
                  'These Terms of Service explain the rules for using Movie Hub’s movie and TV discovery features, saved lists, accounts, community forum, and Cinema Rewards. The Privacy Policy explains how information is handled, and the Copyright Policy explains how to report rights concerns. By using Movie Hub, you agree to follow these terms and applicable laws. Some features are available to guests; account features require you to sign in. If you do not agree, please stop using the app.'
            ),
            (
              heading: 'Content ownership',
              text:
                  'Movie Hub is provided for informational and discovery purposes. Movie Hub owns its app design and original materials. Other content belongs to its respective owners. Viewing or saving a reference does not give you permission to copy, distribute, or otherwise use protected material. Movie Hub uses the TMDB API but is not endorsed or certified by TMDB.'
            ),
            (
              heading: 'Copyright policy and notices',
              text:
                  'Respect the rights of creators and use third-party materials only as permitted by their owners and applicable law. If you believe a reference in Movie Hub infringes copyright, report it using the steps in our Copyright Policy. We review notices and may remove or disable references when appropriate. Movie Hub does not host or deliver movie files.'
            ),
            (
              heading: 'User responsibility',
              text:
                  'Use Movie Hub lawfully and respectfully. Do not try to access accounts or systems without permission, disrupt or interfere with the app, submit information you know is false, misuse advertising or rewards, or use the app to find or promote pirated content. Follow the terms of third-party services you choose to visit. Do not post another person’s private information without their permission.'
            ),
            (
              heading: 'Account security and deletion',
              text:
                  'Provide accurate account details and keep your password private. You are responsible for activity carried out through your account, so tell Support promptly if you think someone else has accessed it. To delete your account, go to Profile and complete the verification and confirmation steps. Some cleanup may take time after a request is accepted. Uninstalling Movie Hub does not delete your account; see the Privacy Policy for details about deletion and data retention.'
            ),
            (
              heading: 'Privacy and saved information',
              text:
                  'Read the Privacy Policy to understand what information Movie Hub and connected services use, the choices available to you, and how to contact us about your information. Some saved titles, preferences, and history are stored only on your device. Clearing app storage or reinstalling the app may remove them, and signing in does not guarantee that device-only information is backed up or transferred.'
            ),
            (
              heading: 'Advertising and your choices',
              text:
                  'Movie Hub may show advertisements. Their availability and content can vary, and an advertisement does not mean Movie Hub endorses the advertised product or service. Where available, use Ad privacy choices to review your advertising consent. Do not create fake ad views or clicks or ask others to do so. Rewarded ads are optional; their rules are described in the Cinema Rewards section.'
            ),
            (
              heading: 'Forum rules and account suspension',
              text:
                  'Keep discussions respectful and follow the community rules. Do not post harassment, hate speech, threats, sexual or exploitative material, scams, spam, impersonation, unlawful content, or material you do not have permission to share. Use report and block tools to raise concerns or manage interactions. We may remove content or limit account access when rules are broken, especially for serious or repeated violations. Contact Support with relevant details if you think we made a mistake.'
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
