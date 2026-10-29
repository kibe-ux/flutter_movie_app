import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/movie_more_info.dart';

class InlineTrailerPlayer extends StatefulWidget {
  const InlineTrailerPlayer({super.key, required this.video});
  final MovieInfoVideo video;
  @override
  State<InlineTrailerPlayer> createState() => _InlineTrailerPlayerState();
}

class _InlineTrailerPlayerState extends State<InlineTrailerPlayer>
    with WidgetsBindingObserver {
  static const _appReferer = 'https://com.moviehub.app/';
  late final WebViewController _controller;
  Timer? _timer;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = WebViewController();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _controller.setBackgroundColor(Colors.black);
      await _controller.setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final scheme = Uri.tryParse(request.url)?.scheme;
          return scheme == 'https' || scheme == 'http'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
        onPageFinished: (_) {
          _timer?.cancel();
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true) _fail();
        },
      ));
      if (mounted) await _load();
    } catch (_) {
      _fail();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 25), _fail);
    try {
      await _controller.loadRequest(widget.video.embedUri,
          headers: const {'Referer': _appReferer});
    } catch (_) {
      _fail();
    }
  }

  void _fail() {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _pause() {
    unawaited(_controller
        .runJavaScript(
            'document.querySelectorAll("video").forEach(function(video){video.pause();});')
        .catchError((Object _) {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent == false) _pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_controller
        .loadHtmlString('<html><body></body></html>')
        .catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        LayoutBuilder(
            builder: (context, constraints) => SizedBox(
                  width: double.infinity,
                  height: math.max(200, constraints.maxWidth * 9 / 16),
                  child: WebViewWidget(controller: _controller),
                )),
        if (_loading)
          const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator()),
        if (_failed)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(children: [
                const Text(
                    'This trailer could not load. Try again or select another trailer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70)),
                TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry trailer')),
              ])),
      ]);
}
