import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/forum_service.dart';

class ForumModerationScreen extends StatefulWidget {
  const ForumModerationScreen(
      {super.key, required this.service, required this.uid});
  final ForumService service;
  final String uid;
  @override
  State<ForumModerationScreen> createState() => _ForumModerationScreenState();
}

class _ForumModerationScreenState extends State<ForumModerationScreen> {
  late final _reports = widget.service.reports();
  final _busy = <String>{};
  Future<void> _review(String id, bool remove) async {
    if (!_busy.add(id)) return;
    setState(() {});
    try {
      await widget.service.reviewReport(id, widget.uid, remove: remove);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is StateError
                ? error.message.toString()
                : 'Could not review this report. Check your moderator access and connection.')));
      }
    } finally {
      _busy.remove(id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Moderation reports')),
        body: StreamBuilder(
            stream: _reports,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                    child: Text(
                        'Reports require moderator access. Refresh your sign-in and try again.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('No open reports.'));
              }
              return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final report = doc.data();
                    return Card(
                        key: ValueKey(doc.id),
                        margin: const EdgeInsets.all(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${report['targetType']} report: ${report['reason']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                Text(
                                    'Reported account: ${report['targetUid']}'),
                                if ((report['details'] as String? ?? '')
                                    .isNotEmpty)
                                  Text(report['details'] as String),
                                _ReportedContent(
                                    service: widget.service, report: report),
                                Wrap(spacing: 8, children: [
                                  TextButton(
                                      onPressed: _busy.contains(doc.id)
                                          ? null
                                          : () => _review(doc.id, false),
                                      child: const Text('Dismiss report')),
                                  FilledButton(
                                      onPressed: _busy.contains(doc.id)
                                          ? null
                                          : () async {
                                              final confirmed =
                                                  await showDialog<bool>(
                                                      context: context,
                                                      builder: (ctx) =>
                                                          AlertDialog(
                                                            title: const Text(
                                                                'Remove reported content?'),
                                                            content: const Text(
                                                                'The post or reply text will be replaced with a removal notice. Removing a post also closes access to its replies.'),
                                                            actions: [
                                                              TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          ctx,
                                                                          false),
                                                                  child: const Text(
                                                                      'Cancel')),
                                                              FilledButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          ctx,
                                                                          true),
                                                                  child: const Text(
                                                                      'Remove'))
                                                            ],
                                                          ));
                                              if (confirmed == true &&
                                                  mounted) {
                                                await _review(doc.id, true);
                                              }
                                            },
                                      child: Text(report['commentId'] == null
                                          ? 'Remove reported post'
                                          : 'Remove reported reply')),
                                ]),
                              ]),
                        ));
                  });
            }),
      );
}

class _ReportedContent extends StatefulWidget {
  const _ReportedContent({required this.service, required this.report});
  final ForumService service;
  final Map<String, dynamic> report;
  @override
  State<_ReportedContent> createState() => _ReportedContentState();
}

class _ReportedContentState extends State<_ReportedContent> {
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _content =
      widget.service.reportedContent(widget.report);
  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: _content,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Could not load reported content.');
        }
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final data = snapshot.data!.data();
        if (data == null) {
          return const Text(
              'Content no longer exists. Dismiss the report after review.');
        }
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('${data['title'] ?? ''}\n${data['content'] ?? ''}',
                maxLines: 20, overflow: TextOverflow.ellipsis));
      });
}
