import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/cinema_palette.dart';
import '../widgets/ad_privacy_choices.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _privacyEmail = 'privacymoviehub@gmail.com';
  static const _accent = CinemaPalette.gold;
  static const _heroSurface = CinemaPalette.wine;
  static const _cardSurface = CinemaPalette.surface;

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
        title: const Text('Privacy Center'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                _buildHero(),
                const SizedBox(height: 20),
                _buildSummaryCard(),
                const AdPrivacyChoices(),
                _buildGroupLabel('INFORMATION & USE'),
                _buildSection(
                  icon: Icons.data_usage_rounded,
                  title: 'Information the app may use',
                  paragraphs: const [
                    'Movie Hub processes information you provide, information generated when you use its features, and technical information supplied by your device or connected services. You can browse the catalog as a guest; account features require sign-in.',
                    'Account information includes your email address, account identifier, verification status, and any display name or profile photo URL you choose to provide. Firebase Authentication handles sign-in credentials and account authentication.',
                    'Depending on the features you use, information may include saved titles, search terms, viewing and download activity, forum posts, replies and likes, support messages, and Cinema Rewards activity. Analytics and crash reporting, when enabled, may process usage events, device and app details, identifiers, error reports and diagnostic information.',
                  ],
                ),
                _buildSection(
                  icon: Icons.devices_outlined,
                  title: 'Information stored on your device',
                  paragraphs: const [
                    'Features such as My List, favorites,settings, and downloads may store information locally on your device so they work between app sessions.',
                    'You can remove locally stored app information through the relevant feature where available, or by clearing the app\u2019s storage in your device settings. This may remove saved titles and preferences.',
                  ],
                ),
                _buildSection(
                  icon: Icons.tune_rounded,
                  title: 'Purpose of data collection',
                  paragraphs: const [
                    'Providing app features: We use searches, title selections and preferences to retrieve movie information, support discovery, save your choices and resume supported viewing features. Account details allow us to authenticate you, manage your profile, verify your email and support account recovery.',
                    'Community and support: We use information you submit to publish forum contributions, associate replies and likes with an account, and investigate and respond to questions or reported problems.',
                    'Reliability and security: Usage events and diagnostics help us understand feature performance, identify errors and improve stability. Account and reward records support authentication, reward verification, prevention of duplicate grants, and investigation of suspected misuse.',
                    'Advertising and optional rewards: When enabled, advertising services use technical data and ad interactions to deliver and measure ads, apply applicable privacy choices and detect invalid activity. Cinema Rewards uses verified completion and redemption records to maintain your balance and ad-free access.',
                    'Please provide only information needed for the feature or request. Do not include passwords, payment details, identity documents or other sensitive personal information in forum posts, search terms or support messages.',
                  ],
                ),
                _buildSection(
                  icon: Icons.hub_outlined,
                  title: 'Sharing of data',
                  paragraphs: const [
                    'Service providers: Movie Hub uses Firebase services for authentication, forum storage, analytics and crash reporting where enabled, and backend services for catalog requests and optional reward verification. These services process information needed to perform their functions. Google Mobile Ads and its partners may process advertising data as described in the advertising section below.',
                    'Content providers: Requests for movie metadata, artwork, trailers or downloads may connect to TMDB, YouTube, Films365 or other content hosts. The receiving service may obtain your IP address, request details and device information. External websites and services apply their own privacy notices and may process data in other countries.',
                    'Public contributions: Forum posts, replies, display names and profile images are visible to other people who access the forum, including guests. Avoid posting personal contact details or information about children. Other people may copy or share public content outside Movie Hub.',
                    'Legal and safety disclosures: Information may be disclosed where necessary to comply with applicable law or a valid legal request, investigate fraud or abuse, or protect the rights and safety of users and the service. Review connected providers\' privacy notices for their own use, disclosure and retention practices.',
                  ],
                ),
                _buildGroupLabel('PROTECTION & CONTROL'),
                _buildSection(
                  icon: Icons.child_care_rounded,
                  title: 'Children\'s privacy',
                  paragraphs: const [
                    'Movie Hub is intended for a general audience aged 13 and older and is not directed to children under 13. Children under 13 should not create an account or submit personal information through the app. Local requirements concerning a young person\'s use of online services may set a higher age or require permission from a parent or guardian.',
                    'The app does not currently verify users\' ages or provide a verified parental-consent process. A catalog title, guest browsing option or advertising content rating does not establish that every feature or item of content is suitable for a child.',
                    'If you are a parent or guardian and believe a child under 13 has provided personal information, contact privacymoviehub@gmail.com with enough detail to identify the account or content. Do not send identity documents or additional sensitive information about the child in your initial message.',
                    'If we learn that personal information has been collected from a child under 13, we will investigate and take appropriate steps to remove that information and disable the associated account where applicable. We may request proportionate verification before acting on a request to protect the child\'s information.',
                  ],
                ),
                _buildSection(
                  icon: Icons.security_rounded,
                  title: 'Data security',
                  paragraphs: const [
                    'Movie Hub uses Firebase Authentication to manage sign-in and requires authentication for account features such as posting to the forum and accessing account-linked rewards. Supported account operations may require a recent sign-in to help protect against unauthorized changes.',
                    'The app relies on the security controls of its hosting and connected service providers. Protection of cloud records also depends on correctly configured backend permissions and access rules. Information saved on your device is subject to your device\'s security settings; local preferences and downloaded files should not be treated as an encrypted vault.',
                    'No method of online transmission or electronic storage is completely secure. Use a strong, unique password, keep your device and app updated, and avoid sharing sign-in details. If you suspect unauthorized account access or a data security issue, contact privacymoviehub@gmail.com without sending your password.',
                  ],
                ),
                _buildSection(
                  icon: Icons.auto_delete_outlined,
                  title: 'Data retention and deletion',
                  paragraphs: const [
                    'Retention depends on the type of information, the feature involved and the connected provider. Account information is kept while your account exists. Forum contributions remain until removed. Reward balances, verification receipts and redemption records may remain after sign-in account deletion because the app does not currently remove those records automatically. There is no single automatic deletion period across all data categories.',
                    'Local data: Saved titles, watch history, preferences and cached information may remain on your device until you remove them through available app controls or clear app storage in device settings. Downloaded or exported files may need to be deleted separately. Signing out does not by itself erase local information or cloud records.',
                    'Account deletion: Use Delete Account in Profile to delete your Firebase Authentication account. You may need to sign in again before completing this action. This removes the sign-in account; it does not automatically erase forum posts, replies, reward records, analytics or diagnostic data held separately.',
                    'Related records: Remove your own forum posts using the available controls before deleting your account, or email privacymoviehub@gmail.com to request removal of account-linked content and reward records. Include the account email and enough information to locate the records, but never send your password. We may need to verify your connection to the account before processing the request.',
                    'Exceptions and provider records: Some information may need to be retained to meet legal obligations, prevent fraud, resolve disputes or maintain security. Where an exception applies, we will explain the reason when responding to your request. Provider-held analytics, diagnostics and backup copies follow the relevant provider\'s retention and deletion processes; deletion from every system may not be immediate.',
                  ],
                ),
                _buildSection(
                  icon: Icons.lock_outline_rounded,
                  title: 'Your choices and requests',
                  paragraphs: const [
                    'You can browse as a guest, update your profile, sign out, manage device permissions and clear local app data. Use Delete Account in Profile to remove your sign-in account, and review Data retention and deletion above for information about records stored separately.',
                    'To request access to, correction of or deletion of personal information, or to raise a concern about its use, email privacymoviehub@gmail.com. Depending on your location, additional rights may apply. We may need proportionate information to verify your request and will explain any limits that affect our response.',
                  ],
                ),
                _buildGroupLabel('ADS & REWARDS'),
                _buildSection(
                  icon: Icons.ads_click_outlined,
                  title: 'Advertising and privacy choices',
                  paragraphs: const [
                    'When advertising is enabled, Google Mobile Ads and its advertising partners may collect or process IP addresses, device identifiers, ad interactions, and diagnostic information to deliver ads, measure performance, and detect fraud. Their services may use device storage and similar technologies.',
                    'Where required, Google\'s consent form asks for your choices before ads are requested. You can reopen the form using Ad privacy choices on this page when that option is required and available. Your choices affect which advertising requests are permitted.',
                    'Google explains its advertising data practices at https://policies.google.com/technologies/ads and its privacy policy at https://policies.google.com/privacy.',
                  ],
                ),
                _buildSection(
                  icon: Icons.toll_rounded,
                  title: 'Cinema Rewards',
                  paragraphs: const [
                    'If you choose to use Cinema Rewards, we store your coin balance, ad-free expiry, reward session identifiers, verified ad completion receipts and coin redemptions with your signed-in account. This information lets us deliver rewards and prevent duplicate grants. Coins are not transferable and have no cash value.',
                    'Reward verification uses your account identifier and an app-generated session identifier. We do not include your email address in rewarded-ad verification metadata. Reward records may be retained for account services, security and resolving disputes. Contact support for questions or deletion requests concerning these records.',
                  ],
                ),
                _buildGroupLabel('HELP & REQUESTS'),
                _buildContactCard(context),
                const SizedBox(height: 16),
                const Text(
                  'Last updated: 28 October 2026. We may update this policy as app features or data practices change. The latest version and revision date are available on this page.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: CinemaPalette.muted, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Semantics(
          header: true,
          child: Text(label,
              style: const TextStyle(
                color: CinemaPalette.muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
                height: 1.5,
              )),
        ),
      );

  Widget _buildIconBadge(IconData icon) => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _accent, size: 24),
      );

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_heroSurface, _cardSurface],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _accent.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIconBadge(Icons.shield_outlined),
          const SizedBox(width: 16),
          const Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your data, clearly explained',
                  style: TextStyle(
                      color: CinemaPalette.ivory,
                      fontSize: 24,
                      height: 1.25,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Text('How Movie Hub handles your information.',
                  style: TextStyle(color: CinemaPalette.muted, height: 1.4)),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withValues(alpha: 0.12)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _accent, size: 22),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Your privacy choices, in one place. Read this policy alongside the notices of connected services.',
              style: TextStyle(color: CinemaPalette.muted, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<String> paragraphs,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CinemaPalette.ivory.withValues(alpha: 0.08)),
      ),
      child: ExpansionTile(
        key: PageStorageKey<String>(title),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: _buildIconBadge(icon),
        title: Text(title,
            style: const TextStyle(
                color: CinemaPalette.ivory,
                fontWeight: FontWeight.w500,
                height: 1.4,
                fontSize: 15)),
        subtitle: icon == Icons.child_care_rounded
            ? const SelectableText(
                _privacyEmail,
                style: TextStyle(
                  color: _accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              )
            : null,
        iconColor: _accent,
        collapsedIconColor: CinemaPalette.muted,
        children: [
          for (final paragraph in paragraphs) ...[
            Text(paragraph,
                style:
                    const TextStyle(color: CinemaPalette.muted, height: 1.5)),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIconBadge(Icons.mail_outline_rounded),
              const SizedBox(width: 14),
              const Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Privacy requests',
                      style: TextStyle(
                          color: CinemaPalette.ivory,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 5),
                  Text('Questions about your data? Contact us.',
                      style:
                          TextStyle(color: CinemaPalette.muted, height: 1.45)),
                ],
              )),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                await Clipboard.setData(
                    const ClipboardData(text: _privacyEmail));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Privacy email copied to clipboard.')),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: _accent.withValues(alpha: 0.65)),
              ),
              child: const Row(
                children: [
                  Expanded(
                      child: Text(_privacyEmail,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, height: 1.5))),
                  SizedBox(width: 8),
                  Icon(Icons.copy_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
