import 'package:flutter/material.dart';

import '../utils/cinema_palette.dart';

/// A scrollable recovery state that fits small screens and enlarged text.
class ConnectionNotice extends StatefulWidget {
  const ConnectionNotice({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.offline = false,
  });

  final String title;
  final String message;
  final Future<void> Function() onRetry;
  final bool offline;

  @override
  State<ConnectionNotice> createState() => _ConnectionNoticeState();
}

class _ConnectionNoticeState extends State<ConnectionNotice> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [CinemaPalette.wine, CinemaPalette.surface],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: CinemaPalette.gold.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Icon(
                          widget.offline
                              ? Icons.wifi_off_rounded
                              : Icons.cloud_off_rounded,
                          color: CinemaPalette.gold,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Semantics(
                        header: true,
                        child: Text(widget.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: CinemaPalette.ivory,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            )),
                      ),
                      const SizedBox(height: 12),
                      Text(widget.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: CinemaPalette.muted,
                            fontSize: 15,
                            height: 1.5,
                          )),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _retrying ? null : _retry,
                          style: FilledButton.styleFrom(
                            backgroundColor: CinemaPalette.gold,
                            foregroundColor: CinemaPalette.background,
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _retrying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh_rounded, size: 20),
                          label: Text(
                              _retrying ? 'Checking connection…' : 'Try again'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
