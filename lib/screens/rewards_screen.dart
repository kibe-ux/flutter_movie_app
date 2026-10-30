import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/rewards_service.dart';
import '../utils/cinema_palette.dart';
import 'login_screen.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});
  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  static const _previewOffers = [
    RewardOffer('hour', 30, 1),
    RewardOffer('evening', 80, 3),
    RewardOffer('marathon', 150, 6),
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<RewardsService>().refresh());
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(context.read<RewardsService>().refresh());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(context.read<RewardsService>().refresh());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _confirmWatch(RewardsService rewards) async {
    final coins = rewards.coinsPerAd;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CinemaPalette.surface,
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
            rewards.testAds ? 'Preview a test ad?' : 'Watch a rewarded ad?',
            style: const TextStyle(color: CinemaPalette.ivory)),
        content: Text(
            rewards.testAds
                ? 'This is a Google test ad for checking the experience. It does not add spendable coins. Watching is optional; you can keep browsing either way.'
                : 'Complete one rewarded ad to earn $coins coins. Closing it before completion earns no coins. Watching is optional; you can keep browsing either way.',
            style: const TextStyle(color: CinemaPalette.muted, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(foregroundColor: CinemaPalette.muted),
              child: const Text('Not now')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: CinemaPalette.homeAccent,
                  foregroundColor: CinemaPalette.background),
              child: Text(rewards.testAds
                  ? 'Watch test ad'
                  : 'Watch for $coins coins')),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    if (rewards.testAds) {
      await rewards.watchTestAd(
          isActive: () =>
              mounted && (ModalRoute.of(context)?.isCurrent ?? false));
      return;
    }
    await rewards.watch(
        isActive: () =>
            mounted && (ModalRoute.of(context)?.isCurrent ?? false));
  }

  Future<void> _redeem(RewardsService rewards, RewardOffer offer) async {
    final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: CinemaPalette.surface,
              scrollable: true,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: const Text('Activate your ad-free pass?',
                  style: TextStyle(color: CinemaPalette.ivory)),
              content: Text(
                  'Use ${offer.coins} coins for ${offer.hours} ${offer.hours == 1 ? 'hour' : 'hours'} without banner or interstitial ads. Time starts immediately and continues while the app is closed. If a pass is active, this time is added to its end.',
                  style:
                      const TextStyle(color: CinemaPalette.muted, height: 1.5)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                        foregroundColor: CinemaPalette.muted),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                        backgroundColor: CinemaPalette.homeAccent,
                        foregroundColor: CinemaPalette.background),
                    child: const Text('Redeem coins')),
              ],
            ));
    if (mounted && accepted == true) await rewards.redeem(offer);
  }

  Widget _card({required Widget child, bool hero = false}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: hero ? null : CinemaPalette.surface,
          gradient: hero ? CinemaPalette.homeHeaderGradient : null,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: CinemaPalette.homeAccent
                  .withValues(alpha: hero ? 0.30 : 0.12)),
        ),
        child: Material(type: MaterialType.transparency, child: child),
      );

  TextStyle _titleStyle([double size = 20]) => TextStyle(
        color: CinemaPalette.ivory,
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.4,
      );

  Widget _eyebrow(String text) => Text(text,
      style: const TextStyle(
        color: CinemaPalette.homeAccent,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
      ));

  Widget _badge(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: CinemaPalette.homeAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
              color: CinemaPalette.homeAccent.withValues(alpha: 0.18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: CinemaPalette.homeAccent, size: 14),
          const SizedBox(width: 7),
          Flexible(
              child: Text(label,
                  style: const TextStyle(
                      color: CinemaPalette.homeAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w500))),
        ]),
      );

  Widget _coin() => ExcludeSemantics(
          child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8DCAE),
              CinemaPalette.homeAccent,
              Color(0xFFAB7946)
            ],
          ),
          border: Border.all(color: const Color(0xFFFFE9C8), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: CinemaPalette.homeAccent.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 6))
          ],
        ),
        child: Center(
            child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: CinemaPalette.background.withValues(alpha: 0.18))),
          child: const Icon(Icons.local_movies_outlined,
              color: Color(0xFF573717), size: 20),
        )),
      ));

  Widget _balance(RewardsService rewards, bool member) {
    final sorted = [...rewards.offers]
      ..sort((a, b) => a.coins.compareTo(b.coins));
    final next =
        sorted.where((offer) => offer.coins > rewards.coins).firstOrNull;
    return _card(
        hero: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!member) ...[
              Text('Cinema Rewards', style: _titleStyle(22)),
              const SizedBox(height: 8),
              const Text('Earn coins. Redeem ad-free time.',
                  style: TextStyle(color: CinemaPalette.muted)),
            ],
            if (member) ...[
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _eyebrow('YOUR COIN BALANCE'),
                      const SizedBox(height: 8),
                      Semantics(
                          label: rewards.loaded
                              ? '${rewards.coins} spendable coins'
                              : 'Balance not yet available',
                          excludeSemantics: true,
                          child: Text.rich(TextSpan(children: [
                            TextSpan(
                                text: rewards.loaded
                                    ? '${rewards.coins}'
                                    : '\u2014',
                                style: const TextStyle(
                                    color: CinemaPalette.ivory,
                                    fontSize: 44,
                                    height: 1,
                                    fontWeight: FontWeight.w600)),
                            const TextSpan(
                                text: '  coins',
                                style: TextStyle(
                                    color: CinemaPalette.homeAccent,
                                    fontSize: 15)),
                          ]))),
                      const SizedBox(height: 10),
                      Text(
                          rewards.loaded
                              ? 'Spend these coins on an ad-free pass below.'
                              : rewards.refreshing
                                  ? 'Loading your balance...'
                                  : 'Balance unavailable. Refresh to load your coins.',
                          style: const TextStyle(
                              color: CinemaPalette.muted,
                              fontSize: 12,
                              height: 1.5)),
                    ])),
                const SizedBox(width: 12),
                _coin(),
              ]),
              if (!rewards.loaded)
                TextButton.icon(
                  onPressed: rewards.busy || rewards.refreshing
                      ? null
                      : rewards.refresh,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(rewards.refreshing
                      ? 'Loading balance...'
                      : 'Load my balance'),
                  style: TextButton.styleFrom(
                      foregroundColor: CinemaPalette.homeAccent),
                ),
              if (rewards.adFree && rewards.adFreeUntil != null) ...[
                const SizedBox(height: 12),
                _badge(Icons.verified_outlined, 'AD-FREE PASS ACTIVE'),
                const SizedBox(height: 10),
                Text(
                    'Until ${MaterialLocalizations.of(context).formatFullDate(rewards.adFreeUntil!.toLocal())} at ${TimeOfDay.fromDateTime(rewards.adFreeUntil!.toLocal()).format(context)}',
                    style: const TextStyle(
                        color: CinemaPalette.ivory, height: 1.5)),
              ] else if (rewards.loaded && sorted.isNotEmpty) ...[
                const SizedBox(height: 12),
                if (rewards.coins >= sorted.first.coins)
                  const Text('An ad-free pass is available with your balance.',
                      style: TextStyle(color: CinemaPalette.ivory, height: 1.5))
                else if (next != null) ...[
                  Text(
                      '${rewards.coins} / ${next.coins} coins toward a ${next.hours}-hour pass',
                      style: const TextStyle(
                          color: CinemaPalette.muted,
                          fontSize: 12,
                          height: 1.5)),
                  const SizedBox(height: 10),
                  Semantics(
                      label: '${rewards.coins} of ${next.coins} coins',
                      child: LinearProgressIndicator(
                        value: (rewards.coins / next.coins).clamp(0.0, 1.0),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(4),
                        color: CinemaPalette.homeAccent,
                        backgroundColor: const Color(0x24E6BB83),
                      )),
                ],
              ],
            ],
          ],
        ));
  }

  Widget _guest() => _card(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badge(Icons.lock_outline_rounded, 'FOR YOUR ACCOUNT'),
          const SizedBox(height: 18),
          Text('Your own cinema wallet.', style: _titleStyle(23)),
          const SizedBox(height: 10),
          const Text(
              'Sign in to access rewards and keep your balance in your account. Browsing stays available as a guest.',
              style: TextStyle(color: CinemaPalette.muted, height: 1.6)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LoginScreen(
                        reason:
                            'Sign in to access Cinema Rewards. You can keep browsing without an account.'))),
            style: FilledButton.styleFrom(
                backgroundColor: CinemaPalette.homeAccent,
                foregroundColor: CinemaPalette.background,
                minimumSize: const Size.fromHeight(52)),
            child: const Text('Sign in to Cinema Rewards'),
          ),
        ],
      ));

  Widget _watchCard(RewardsService rewards) {
    final allowed = !rewards.busy &&
        !rewards.refreshing &&
        !rewards.adFree &&
        rewards.supported &&
        (rewards.testAds || (rewards.enabled && !rewards.pending));
    final label = rewards.busy
        ? rewards.activityLabel
        : rewards.adFree
            ? 'Your ad-free pass is active'
            : rewards.testAds
                ? 'Watch test ad'
                : rewards.pending
                    ? 'Reward confirmation pending'
                    : 'Watch for ${rewards.coinsPerAd} coins';
    return _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
                color: CinemaPalette.homeAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.play_circle_outline_rounded,
                color: CinemaPalette.homeAccent)),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _eyebrow(
              rewards.testAds ? 'REWARDED AD PREVIEW' : 'OPTIONAL REWARDED AD'),
          const SizedBox(height: 7),
          Text(
              rewards.testAds
                  ? 'Try the experience.'
                  : 'Earn at your own pace.',
              style: _titleStyle(18)),
        ])),
      ]),
      const SizedBox(height: 10),
      Text(
          rewards.testAds
              ? 'Preview a Google test ad. No coins are added and your balance stays unchanged.'
              : 'Complete one rewarded ad for ${rewards.coinsPerAd} coins. Each completed ad is a separate choice.',
          style: const TextStyle(color: CinemaPalette.muted, height: 1.6)),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: allowed ? () => _confirmWatch(rewards) : null,
        style: FilledButton.styleFrom(
          backgroundColor: CinemaPalette.homeAccent,
          foregroundColor: CinemaPalette.background,
          disabledBackgroundColor:
              CinemaPalette.homeAccent.withValues(alpha: 0.10),
          disabledForegroundColor: CinemaPalette.muted,
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: rewards.busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: CinemaPalette.background))
            : const Icon(Icons.play_arrow_rounded),
        label: Text(label, textAlign: TextAlign.center),
      ),
      const SizedBox(height: 8),
      Text(
          !rewards.supported
              ? 'Rewarded ads are available on Android and iOS.'
              : rewards.testAds
                  ? 'Test preview only. No spendable coins or revenue.'
                  : !rewards.enabled
                      ? 'Rewards are being prepared. Keep browsing as usual.'
                      : rewards.pending
                          ? 'Confirmation is pending. Refresh your balance shortly.'
                          : 'You may close an ad at any time. No clicks, installs or purchases are required by Movie Hub.',
          style: const TextStyle(
              color: CinemaPalette.muted, fontSize: 12, height: 1.5)),
    ]));
  }

  Widget _offerCard(RewardsService rewards, RewardOffer offer,
      {bool preview = false}) {
    final available =
        !preview && rewards.loaded && rewards.coins >= offer.coins;
    final info = Row(children: [
      const Icon(Icons.schedule_rounded,
          color: CinemaPalette.homeAccent, size: 22),
      const SizedBox(width: 10),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${offer.hours} ${offer.hours == 1 ? 'hour' : 'hours'} ad-free',
            style: _titleStyle(16)),
        const SizedBox(height: 4),
        Text('${offer.coins} coins',
            style: const TextStyle(color: CinemaPalette.muted, fontSize: 12)),
      ])),
    ]);
    final button = OutlinedButton(
      onPressed: rewards.busy || rewards.refreshing || !available
          ? null
          : () => _redeem(rewards, offer),
      style: OutlinedButton.styleFrom(
          foregroundColor: CinemaPalette.homeAccent,
          disabledForegroundColor: CinemaPalette.muted,
          side: BorderSide(
              color: CinemaPalette.homeAccent
                  .withValues(alpha: available ? .4 : .12)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: const Size(0, 40),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      child: Text(
          preview
              ? 'Connect to redeem'
              : available
                  ? 'Redeem ${offer.coins} coins'
                  : '${offer.coins - rewards.coins} more coins needed',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12)),
    );
    return _card(
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(12) > 16) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: button),
              ]);
        }
        return Row(children: [
          Expanded(child: info),
          const SizedBox(width: 12),
          Flexible(child: button)
        ]);
      }),
    );
  }

  Widget _details(RewardsService rewards) => _card(
          child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 10),
          iconColor: CinemaPalette.homeAccent,
          collapsedIconColor: CinemaPalette.muted,
          title: Text('How rewards work', style: _titleStyle(17)),
          subtitle: const Text('Your choice, from start to finish.',
              style: TextStyle(color: CinemaPalette.muted, fontSize: 12)),
          children: [
            if (rewards.testAds)
              const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                      'You are currently in test mode. The earning flow below is not live.',
                      style: TextStyle(
                          color: CinemaPalette.homeAccent, height: 1.5))),
            for (final step in [
              (
                '01',
                'Choose one ad',
                'Each ad requires your explicit choice. You can decline or close it and keep browsing.'
              ),
              (
                '02',
                'Receive the stated reward',
                'In live mode, a completed and confirmed ad adds the disclosed coins to your account.'
              ),
              (
                '03',
                'Redeem when you choose',
                'Pass time starts immediately, continues while the app is closed, and extends an existing pass.'
              ),
            ])
              Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.$1,
                          style: const TextStyle(
                              color: CinemaPalette.homeAccent, fontSize: 12)),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(step.$2,
                                style: const TextStyle(
                                    color: CinemaPalette.ivory,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 5),
                            Text(step.$3,
                                style: const TextStyle(
                                    color: CinemaPalette.muted,
                                    fontSize: 12,
                                    height: 1.6)),
                          ])),
                    ],
                  )),
          ],
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final rewards = context.watch<RewardsService>();
    final member = user != null && !user.isAnonymous;
    return Theme(
      data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: CinemaPalette.homeAccent,
                onPrimary: CinemaPalette.background,
                surface: CinemaPalette.surface,
                onSurface: CinemaPalette.ivory,
              )),
      child: Scaffold(
        backgroundColor: CinemaPalette.background,
        appBar: AppBar(
          title: const Text('Cinema Rewards',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
          backgroundColor: CinemaPalette.background,
          foregroundColor: CinemaPalette.ivory,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: const DecoratedBox(
              decoration:
                  BoxDecoration(gradient: CinemaPalette.appBarGradient)),
          actions: [
            if (member)
              IconButton(
                  tooltip: 'Refresh balance',
                  onPressed: rewards.busy || rewards.refreshing
                      ? null
                      : rewards.refresh,
                  icon: rewards.refreshing
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: CinemaPalette.homeAccent))
                      : const Icon(Icons.refresh_rounded, size: 21))
          ],
        ),
        body: RefreshIndicator(
          color: CinemaPalette.homeAccent,
          onRefresh: rewards.refresh,
          child: LayoutBuilder(
              builder: (context, constraints) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                        horizontal: constraints.maxWidth > 760
                            ? (constraints.maxWidth - 720) / 2
                            : 20,
                        vertical: 20),
                    children: [
                      if (member) ...[
                        _eyebrow('THE CINEMA CLUB'),
                        const SizedBox(height: 10),
                        Text('More cinema.\nFewer interruptions.',
                            style: _titleStyle(28)),
                        const SizedBox(height: 10),
                        const Text('Your rewards, your next movie night.',
                            style: TextStyle(
                                color: CinemaPalette.muted, height: 1.5)),
                        const SizedBox(height: 24),
                      ],
                      _balance(rewards, member),
                      if (!member)
                        _guest()
                      else ...[
                        if (rewards.message != null)
                          Semantics(
                              liveRegion: true,
                              child: _card(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                            rewards.refreshFailed
                                                ? Icons.cloud_off_rounded
                                                : Icons.info_outline_rounded,
                                            color: CinemaPalette.homeAccent,
                                            size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Text(rewards.message!,
                                                style: const TextStyle(
                                                    color: CinemaPalette.ivory,
                                                    height: 1.5))),
                                      ],
                                    ),
                                    if (rewards.refreshFailed ||
                                        rewards.pending)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: TextButton.icon(
                                          onPressed:
                                              rewards.busy || rewards.refreshing
                                                  ? null
                                                  : rewards.refresh,
                                          icon: const Icon(
                                              Icons.refresh_rounded,
                                              size: 18),
                                          label: Text(rewards.refreshing
                                              ? 'Checking...'
                                              : 'Try again'),
                                        ),
                                      ),
                                  ],
                                ),
                              )),
                        if (!rewards.loaded && rewards.message == null)
                          const Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: LinearProgressIndicator(
                                  color: CinemaPalette.homeAccent,
                                  minHeight: 2)),
                        const SizedBox(height: 10),
                        _watchCard(rewards),
                        const SizedBox(height: 12),
                        _eyebrow('AD-FREE PASSES'),
                        const SizedBox(height: 8),
                        Text('Redeem for ad-free time', style: _titleStyle(24)),
                        const SizedBox(height: 8),
                        Text(
                            rewards.offers.isEmpty
                                ? 'Preview only. Connect to load your balance and redeem.'
                                : 'Pause banner and interstitial ads. No subscription.',
                            style: const TextStyle(
                                color: CinemaPalette.muted, height: 1.5)),
                        const SizedBox(height: 20),
                        for (final offer in (rewards.offers.isEmpty
                            ? _previewOffers
                            : rewards.offers))
                          _offerCard(rewards, offer,
                              preview:
                                  rewards.offers.isEmpty || !rewards.loaded),
                      ],
                      _details(rewards),
                      const Text(
                          'Coins have no cash value and cannot be transferred. They are only usable for ad-free time in Movie Hub. Your movie access does not depend on rewarded ads.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: CinemaPalette.muted,
                              fontSize: 11,
                              height: 1.7)),
                      const SizedBox(height: 12),
                      TextButton(
                          onPressed: () => Navigator.maybePop(context),
                          style: TextButton.styleFrom(
                              foregroundColor: CinemaPalette.homeAccent,
                              minimumSize: const Size.fromHeight(48)),
                          child: const Text('Keep browsing')),
                      const SizedBox(height: 12),
                    ],
                  )),
        ),
      ),
    );
  }
}
