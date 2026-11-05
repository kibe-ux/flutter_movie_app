import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

Uri contactEmailUri(String email, {String subject = '', String body = ''}) {
  final fields = {
    if (subject.isNotEmpty) 'subject': subject,
    if (body.isNotEmpty) 'body': body,
  };
  // mailto fields need percent-encoded spaces rather than form-encoded '+'.
  return Uri(
    scheme: 'mailto',
    path: email,
    query: fields.isEmpty
        ? null
        : fields.entries
            .map((entry) =>
                '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}')
            .join('&'),
  );
}

Future<void> openContactEmail(
  BuildContext context, {
  required String email,
  String subject = '',
  String body = '',
}) async {
  try {
    if (await launchUrl(
      contactEmailUri(email, subject: subject, body: body),
      mode: LaunchMode.externalApplication,
    )) {
      return;
    }
  } catch (_) {
    // Keep the contact address available when no mail handler is installed.
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text('No email app could be opened. Email $email.'),
    action: SnackBarAction(
      label: 'Copy email',
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: email));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email address copied.')),
        );
      },
    ),
  ));
}
