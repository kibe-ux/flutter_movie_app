import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';
import '../utils/cinema_palette.dart';

class AdPrivacyChoices extends StatefulWidget {
  const AdPrivacyChoices({super.key});

  @override
  State<AdPrivacyChoices> createState() => _AdPrivacyChoicesState();
}

class _AdPrivacyChoicesState extends State<AdPrivacyChoices> {
  late final Future<bool> _required = _checkRequirement();
  bool _busy = false;

  Future<bool> _checkRequirement() async {
    if (kIsWeb ||
        ![TargetPlatform.android, TargetPlatform.iOS]
            .contains(defaultTargetPlatform) ||
        AdService().usesTestAds) {
      return false;
    }
    try {
      await AdService().init();
      return await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showChoices() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ads = AdService();
    ads.beginPrivacyUpdate();
    var failed = false;
    try {
      await ConsentForm.showPrivacyOptionsForm((error) {
        failed = error != null;
      });
    } catch (_) {
      failed = true;
    } finally {
      await ads.finishPrivacyUpdate();
      if (mounted) {
        setState(() => _busy = false);
        if (failed) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Privacy choices could not be opened. Please try again.')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: _required,
        builder: (context, snapshot) {
          if (snapshot.data != true) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _showChoices,
              style:
                  OutlinedButton.styleFrom(foregroundColor: CinemaPalette.gold),
              icon: const Icon(Icons.privacy_tip_outlined),
              label: Text(
                  _busy ? 'Opening privacy choices...' : 'Ad privacy choices'),
            ),
          );
        },
      );
}
