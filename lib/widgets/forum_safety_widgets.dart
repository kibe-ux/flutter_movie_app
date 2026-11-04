import 'package:flutter/material.dart';
import '../services/forum_service.dart';

const communityTerms = 'Movie Hub Community Rules — version 1\n\n'
    'Treat people respectfully. No harassment, hate, threats, bullying or impersonation.\n\n'
    'No sexual exploitation, sexual content involving minors, graphic violence, or encouragement of self-harm.\n\n'
    'No spam, scams, personal information posted without permission, or illegal content. Share only content you have permission to use; do not post unauthorized movie files or download links.\n\n'
    'Posts and replies are public. Use Report post, Report reply or Report user to alert moderators. Blocking hides that author’s content in your signed-in feed and prevents replies/likes between you on each other’s posts.\n\n'
    'Moderators may remove content that violates these rules. Repeated abuse may lead to further account action. For questions or an appeal, contact privacymoviehub@gmail.com.\n\n'
    'By agreeing, you accept these rules for your community contributions.';

Future<bool> showCommunityTerms(BuildContext context,
        {bool accepting = false}) async =>
    await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Community rules and terms'),
              content: const SingleChildScrollView(child: Text(communityTerms)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(accepting ? 'Cancel' : 'Close')),
                if (accepting)
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Agree and continue')),
              ],
            )) ??
    false;

class ForumSafetyMenu extends StatelessWidget {
  const ForumSafetyMenu(
      {super.key, required this.reply, required this.onSelected});
  final bool reply;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Content options',
        onSelected: onSelected,
        itemBuilder: (_) => [
          PopupMenuItem(
              value: 'content',
              child: Text(reply ? 'Report reply' : 'Report post')),
          const PopupMenuItem(value: 'user', child: Text('Report user')),
          const PopupMenuItem(value: 'block', child: Text('Block user')),
        ],
      );
}

class ForumReportInput {
  const ForumReportInput(this.reason, this.details);
  final String reason;
  final String details;
}

class ForumReportDialog extends StatefulWidget {
  const ForumReportDialog({super.key, required this.title});
  final String title;
  @override
  State<ForumReportDialog> createState() => _ForumReportDialogState();
}

class _ForumReportDialogState extends State<ForumReportDialog> {
  String _reason = ForumService.reportReasons.first;
  final _details = TextEditingController();
  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'Reports are private and reviewed by moderators. Choose the closest reason.'),
          DropdownButton<String>(
              isExpanded: true,
              value: _reason,
              items: ForumService.reportReasons
                  .map((reason) =>
                      DropdownMenuItem(value: reason, child: Text(reason)))
                  .toList(),
              onChanged: (reason) {
                if (reason != null) setState(() => _reason = reason);
              }),
          TextField(
              controller: _details,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Additional details (optional)')),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(
                  context, ForumReportInput(_reason, _details.text.trim())),
              child: const Text('Send report')),
        ],
      );
}
