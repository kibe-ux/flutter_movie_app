import 'package:flutter/material.dart';
import '../services/forum_service.dart';

class ForumBlockedUsersScreen extends StatelessWidget {
  const ForumBlockedUsersScreen(
      {super.key, required this.uid, required this.service});
  final String uid;
  final ForumService service;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Blocked users')),
        body: StreamBuilder(
            stream: service.blockedUsers(uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                    child: Text(
                        'Could not load blocked users. Please try again.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                    child: Text('You have not blocked anyone.'));
              }
              return ListView(
                  children: docs
                      .map((doc) => ListTile(
                            title: Text(
                                doc.data()['author'] as String? ?? 'Member'),
                            trailing: TextButton(
                                child: const Text('Unblock'),
                                onPressed: () async {
                                  try {
                                    await service.unblockUser(uid, doc.id);
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Could not unblock this user. Try again.')));
                                    }
                                  }
                                }),
                          ))
                      .toList());
            }),
      );
}
