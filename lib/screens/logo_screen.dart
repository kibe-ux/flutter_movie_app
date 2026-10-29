import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/home_startup_service.dart';
import '../widgets/movie_hub_icon.dart';
import 'splash_screen.dart';

/// The first Flutter frame continues the native black launch screen.
class LogoScreen extends StatefulWidget {
  const LogoScreen({super.key, this.initialize, this.startupService});
  final Future<void> Function()? initialize;
  final HomeStartupService? startupService;
  @override
  State<LogoScreen> createState() => _LogoScreenState();
}

class _LogoScreenState extends State<LogoScreen> {
  Timer? _timer;
  bool _showSplash = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _showSplash = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
          initialize: widget.initialize, startupService: widget.startupService);
    }
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          systemNavigationBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarIconBrightness: Brightness.light),
      child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: MovieHubIcon(size: 128))),
    );
  }
}
