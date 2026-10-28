import 'package:flutter/material.dart';

import '../utils/cinema_palette.dart';

class RateAppDialog extends StatefulWidget {
  const RateAppDialog({super.key});

  @override
  State<RateAppDialog> createState() => _RateAppDialogState();
}

class _RateAppDialogState extends State<RateAppDialog> {
  int _rating = 0;

  static const _descriptions = [
    'Choose your rating',
    'Not great',
    'Could be better',
    'It\'s okay',
    'Really good',
    'Love it!',
  ];

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: CinemaPalette.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: Color(0x33E6BB83)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [CinemaPalette.wine, CinemaPalette.surface],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0x18E6BB83),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.star_rounded,
                            color: CinemaPalette.gold, size: 28),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Close rating',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded,
                            color: CinemaPalette.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text('YOUR EXPERIENCE',
                      style: TextStyle(
                        color: CinemaPalette.gold,
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 8),
                  const Text('Rate Movie Hub',
                      style: TextStyle(
                        color: CinemaPalette.ivory,
                        fontSize: 26,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 10),
                  const Text('How has your time with Movie Hub been?',
                      style:
                          TextStyle(color: CinemaPalette.muted, height: 1.5)),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 2,
                    runSpacing: 8,
                    children: List.generate(5, (index) {
                      final value = index + 1;
                      return Semantics(
                        label: '$value ${value == 1 ? 'star' : 'stars'}',
                        button: true,
                        selected: _rating == value,
                        onTap: () => setState(() => _rating = value),
                        child: ExcludeSemantics(
                          child: IconButton(
                            tooltip: '$value ${value == 1 ? 'star' : 'stars'}',
                            constraints: const BoxConstraints.tightFor(
                                width: 44, height: 48),
                            padding: const EdgeInsets.all(4),
                            onPressed: () => setState(() => _rating = value),
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 160),
                              child: Icon(
                                _rating >= value
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                key: ValueKey(_rating >= value),
                                size: 34,
                                color: _rating >= value
                                    ? CinemaPalette.gold
                                    : CinemaPalette.muted,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    child: Text(_descriptions[_rating],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _rating == 0
                              ? CinemaPalette.muted
                              : CinemaPalette.gold,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        )),
                  ),
                  const SizedBox(height: 26),
                  FilledButton(
                    onPressed: _rating == 0
                        ? null
                        : () => Navigator.of(context).pop(_rating),
                    style: FilledButton.styleFrom(
                      backgroundColor: CinemaPalette.gold,
                      foregroundColor: CinemaPalette.background,
                      disabledBackgroundColor: const Color(0x22E6BB83),
                      disabledForegroundColor: CinemaPalette.muted,
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Submit rating',
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                        foregroundColor: CinemaPalette.muted),
                    child: const Text('Maybe later'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
