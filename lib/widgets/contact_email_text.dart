import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../utils/cinema_palette.dart';
import '../utils/contact_email.dart';

class ContactEmailText extends StatefulWidget {
  const ContactEmailText({
    super.key,
    required this.text,
    required this.email,
    this.subject = '',
    this.style,
  });

  final String text;
  final String email;
  final String subject;
  final TextStyle? style;

  @override
  State<ContactEmailText> createState() => _ContactEmailTextState();
}

class _ContactEmailTextState extends State<ContactEmailText> {
  late final _emailTap = TapGestureRecognizer()
    ..onTap = () =>
        openContactEmail(context, email: widget.email, subject: widget.subject);

  @override
  void dispose() {
    _emailTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parts = widget.text.split(widget.email);
    return Text.rich(
      TextSpan(children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0)
            TextSpan(
              text: widget.email,
              style: const TextStyle(
                color: CinemaPalette.gold,
                decoration: TextDecoration.underline,
              ),
              recognizer: _emailTap,
              mouseCursor: SystemMouseCursors.click,
            ),
          TextSpan(text: parts[i]),
        ],
      ]),
      style: widget.style,
    );
  }
}
