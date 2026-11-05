import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/utils/contact_email.dart';
import 'package:moviehub_app/widgets/contact_email_text.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _EmailLauncher extends UrlLauncherPlatform {
  @override
  get linkDelegate => null;

  bool succeeds = true;
  bool throws = false;
  String? launchedUrl;
  LaunchOptions? options;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrl = url;
    this.options = options;
    if (throws) throw PlatformException(code: 'no_handler');
    return succeeds;
  }
}

void main() {
  late _EmailLauncher launcher;
  late UrlLauncherPlatform previous;

  setUp(() {
    previous = UrlLauncherPlatform.instance;
    launcher = _EmailLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  tearDown(() => UrlLauncherPlatform.instance = previous);

  test('email drafts preserve spaces, plus signs, ampersands and newlines', () {
    const subject = 'Playback & downloads + support';
    const body = 'Hello Movie Hub,\n\nTitle: A+B & C?\nPlease help.';
    final uri = contactEmailUri('supportmoviehub@gmail.com',
        subject: subject, body: body);

    expect(uri.scheme, 'mailto');
    expect(uri.path, 'supportmoviehub@gmail.com');
    expect(uri.query, contains('%20'));
    expect(uri.query, isNot(contains('+')));
    expect(uri.queryParameters, {'subject': subject, 'body': body});
  });

  testWidgets('privacy email text opens the external email composer',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ContactEmailText(
          text: 'privacymoviehub@gmail.com',
          email: 'privacymoviehub@gmail.com',
          subject: 'Movie Hub Privacy Request',
        ),
      ),
    ));
    await tester.tap(find.byType(ContactEmailText));
    await tester.pump();

    final uri = Uri.parse(launcher.launchedUrl!);
    expect(uri.path, 'privacymoviehub@gmail.com');
    expect(uri.queryParameters['subject'], 'Movie Hub Privacy Request');
    expect(launcher.options!.mode, PreferredLaunchMode.externalApplication);
    expect(find.byType(SnackBar), findsNothing);
  });

  for (final throws in [false, true]) {
    testWidgets('offers a copy fallback when launching fails (throws=$throws)',
        (tester) async {
      launcher.succeeds = false;
      launcher.throws = throws;
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return TextButton(
              onPressed: () =>
                  openContactEmail(context, email: 'supportmoviehub@gmail.com'),
              child: const Text('Contact'),
            );
          }),
        ),
      ));
      await tester.tap(find.text('Contact'));
      await tester.pumpAndSettle();
      expect(find.text('Copy email'), findsOneWidget);
      await tester.tap(find.text('Copy email'));
      await tester.pumpAndSettle();
      expect(copied, 'supportmoviehub@gmail.com');
    });
  }
}
