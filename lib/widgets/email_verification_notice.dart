import 'package:flutter/material.dart';

import '../utils/cinema_palette.dart';

class EmailVerificationNotice extends StatelessWidget {
  const EmailVerificationNotice({
    super.key,
    required this.isBusy,
    required this.isSending,
    required this.onSend,
    required this.onCheck,
  });

  final bool isBusy;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0x12E6BB83),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x33E6BB83)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.mark_email_unread_outlined,
                    color: CinemaPalette.gold, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Confirm your email',
                      style: TextStyle(
                          color: CinemaPalette.ivory,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Open the verification email and follow its link. If you haven\'t received one, send a new email below and check your spam folder.',
              style: TextStyle(color: CinemaPalette.muted, height: 1.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onSend,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: CinemaPalette.gold,
                      disabledForegroundColor: CinemaPalette.muted,
                      side: const BorderSide(color: Color(0x66E6BB83))),
                  icon: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: CinemaPalette.gold))
                      : const Icon(Icons.outgoing_mail, size: 18),
                  label: Text(isSending ? 'Sending...' : 'Send verification'),
                ),
                TextButton(
                  onPressed: isBusy ? null : onCheck,
                  style: TextButton.styleFrom(
                      foregroundColor: CinemaPalette.gold,
                      disabledForegroundColor: CinemaPalette.muted),
                  child: const Text('Check status'),
                ),
              ],
            ),
          ],
        ),
      );
}
