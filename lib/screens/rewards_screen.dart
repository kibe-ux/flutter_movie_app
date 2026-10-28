import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/rewards_service.dart';
import '../services/ad_free_access.dart';
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
                  backgroundColor: CinemaPalette.gold,
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
                        backgroundColor: CinemaPalette.gold,
                        foregroundColor: CinemaPalette.background),
                    child: const Text('Redeem coins')),
              ],
            ));
    if (mounted && accepted == true) await rewards.redeem(offer);
  }

  Widget _card({required Widget child, bool hero = false}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: hero ? null : CinemaPalette.surface,
          gradient: hero
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    CinemaPalette.wine,
                    CinemaPalette.surface,
                    CinemaPalette.background
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
              color: CinemaPalette.gold.withValues(alpha: hero ? 0.30 : 0.12)),
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
        color: CinemaPalette.gold,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
      ));

  Widget _badge(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: CinemaPalette.gold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: CinemaPalette.gold.withValues(alpha: 0.18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: CinemaPalette.gold, size: 14),
          const SizedBox(width: 7),
          Flexible(
              child: Text(label,
                  style: const TextStyle(
                      color: CinemaPalette.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w500))),
        ]),
      );

  Widget _coin() => ExcludeSemantics(
          child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8DCAE), CinemaPalette.gold, Color(0xFFAB7946)],
          ),
          border: Border.all(color: const Color(0xFFFFE9C8), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: CinemaPalette.gold.withValues(alpha: 0.12),
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
              color: Color(0xFF573717), size: 26),
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
            Wrap(spacing: 10, runSpacing: 10, children: [
              _badge(Icons.movie_filter_outlined, 'CINEMA REWARDS'),
              if (rewards.testAds) _badge(Icons.science_outlined, 'TEST MODE'),
            ]),
            const SizedBox(height: 22),
            Text('Make room for\nuninterrupted cinema.',
                style: _titleStyle(28)),
            const SizedBox(height: 10),
            const Text('Ad-free time, on your terms.',
                style: TextStyle(color: CinemaPalette.muted, height: 1.5)),
            if (member) ...[
              const SizedBox(height: 28),
              const Divider(color: Color(0x24E6BB83), height: 1),
              const SizedBox(height: 22),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _eyebrow('AVAILABLE BALANCE'),
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
                                    fontSize: 46,
                                    height: 1,
                                    fontWeight: FontWeight.w600)),
                            const TextSpan(
                                text: '  coins',
                                style: TextStyle(
                                    color: CinemaPalette.gold, fontSize: 15)),
                          ]))),
                      const SizedBox(height: 10),
                      const Text('Account-bound. No cash value.',
                          style: TextStyle(
                              color: CinemaPalette.muted,
                              fontSize: 12,
                              height: 1.5)),
                    ])),
                const SizedBox(width: 12),
                _coin(),
              ]),
              if (rewards.adFree && rewards.adFreeUntil != null) ...[
                const SizedBox(height: 20),
                _badge(Icons.verified_outlined, 'AD-FREE PASS ACTIVE'),
                const SizedBox(height: 10),
                Text(
                    'Until ${MaterialLocalizations.of(context).formatFullDate(rewards.adFreeUntil!.toLocal())} at ${TimeOfDay.fromDateTime(rewards.adFreeUntil!.toLocal()).format(context)}',
                    style: const TextStyle(
                        color: CinemaPalette.ivory, height: 1.5)),
              ] else if (rewards.loaded && sorted.isNotEmpty) ...[
                const SizedBox(height: 22),
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
                        color: CinemaPalette.gold,
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
                backgroundColor: CinemaPalette.gold,
                foregroundColor: CinemaPalette.background,
                minimumSize: const Size.fromHeight(52)),
            child: const Text('Sign in to Cinema Rewards'),
          ),
        ],
      ));

  Widget _watchCard(RewardsService rewards) {
    final allowed = !rewards.busy &&
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
                color: CinemaPalette.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.play_circle_outline_rounded,
                color: CinemaPalette.gold)),
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
              style: _titleStyle(22)),
        ])),
      ]),
      const SizedBox(height: 18),
      Text(
          rewards.testAds
              ? 'Preview a Google test ad. No coins are added and your balance stays unchanged.'
              : 'Complete one rewarded ad for ${rewards.coinsPerAd} coins. Each completed ad is a separate choice.',
          style: const TextStyle(color: CinemaPalette.muted, height: 1.6)),
      const SizedBox(height: 22),
      FilledButton.icon(
        onPressed: allowed ? () => _confirmWatch(rewards) : null,
        style: FilledButton.styleFrom(
          backgroundColor: CinemaPalette.gold,
          foregroundColor: CinemaPalette.background,
          disabledBackgroundColor: CinemaPalette.gold.withValues(alpha: 0.10),
          disabledForegroundColor: CinemaPalette.muted,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: rewards.busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: CinemaPalette.gold))
            : const Icon(Icons.play_arrow_rounded),
        label: Text(label, textAlign: TextAlign.center),
      ),
      const SizedBox(height: 14),
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

  Widget _offerCard(RewardsService rewards, RewardOffer offer) {
    final available = rewards.coins >= offer.coins;
    return _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: CinemaPalette.gold.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.schedule_rounded,
                color: available ? CinemaPalette.gold : CinemaPalette.muted)),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${offer.hours} ${offer.hours == 1 ? 'hour' : 'hours'} ad-free',
              style: _titleStyle(22)),
          const SizedBox(height: 5),
          Text('${offer.coins} coins',
              style: const TextStyle(
                  color: CinemaPalette.gold,
                  fontWeight: FontWeight.w600,
                  fontSize: 15)),
        ])),
      ]),
      const SizedBox(height: 16),
      const Text('Banner and interstitial ads paused.',
          style: TextStyle(color: CinemaPalette.muted, height: 1.5)),
      const SizedBox(height: 18),
      SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: rewards.busy || !available
                ? null
                : () => _redeem(rewards, offer),
            style: OutlinedButton.styleFrom(
              foregroundColor: CinemaPalette.gold,
              disabledForegroundColor: CinemaPalette.muted,
              side: BorderSide(
                  color: CinemaPalette.gold
                      .withValues(alpha: available ? 0.4 : 0.12)),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
                available
                    ? 'Redeem ${offer.coins} coins'
                    : '${offer.coins - rewards.coins} more coins needed',
                textAlign: TextAlign.center),
          )),
    ]));
  }

  Widget _details(RewardsService rewards) => _card(
          child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 10),
          iconColor: CinemaPalette.gold,
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
                      style:
                          TextStyle(color: CinemaPalette.gold, height: 1.5))),
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
                              color: CinemaPalette.gold, fontSize: 12)),
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
                primary: CinemaPalette.gold,
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
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                CinemaPalette.wine,
                CinemaPalette.surface,
                CinemaPalette.background
              ]))),
          actions: member
              ? [
                  IconButton(
                      tooltip: 'Refresh balance',
                      onPressed: rewards.busy ? null : rewards.refresh,
                      icon: const Icon(Icons.refresh_rounded, size: 21))
                ]
              : null,
        ),
        body: AnimatedBuilder(
          animation: AdFreeAccess.instance,
          builder: (context, _) => RefreshIndicator(
            color: CinemaPalette.gold,
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
                        _balance(rewards, member),
                        if (!member)
                          _guest()
                        else ...[
                          if (rewards.message != null)
                            Semantics(
                                liveRegion: true,
                                child: _card(
                                    child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.info_outline_rounded,
                                        color: CinemaPalette.gold, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Text(rewards.message!,
                                            style: const TextStyle(
                                                color: CinemaPalette.ivory,
                                                height: 1.5))),
                                  ],
                                ))),
                          if (!rewards.loaded && rewards.message == null)
                            const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: LinearProgressIndicator(
                                    color: CinemaPalette.gold, minHeight: 2)),
                          _watchCard(rewards),
                          if (rewards.offers.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _eyebrow('AD-FREE PASSES'),
                            const SizedBox(height: 8),
                            Text('Choose your quiet hours.',
                                style: _titleStyle(24)),
                            const SizedBox(height: 8),
                            const Text(
                                'Exact costs. No subscriptions. Redeem only when you are ready.',
                                style: TextStyle(
                                    color: CinemaPalette.muted, height: 1.5)),
                            const SizedBox(height: 20),
                            for (final offer in rewards.offers)
                              _offerCard(rewards, offer),
                          ],
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
                                foregroundColor: CinemaPalette.gold,
                                minimumSize: const Size.fromHeight(48)),
                            child: const Text('Keep browsing')),
                        const SizedBox(height: 12),
                      ],
                    )),
          ),
        ),
      ),
    );
  }
}
