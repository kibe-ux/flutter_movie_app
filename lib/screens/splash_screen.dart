import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/auth_wrapper.dart';
import '../services/catalogue_service.dart';
import '../utils/cinema_palette.dart';
import 'main_screen.dart';
import '../services/home_startup_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.initialize, this.startupService});

  final Future<void> Function()? initialize;
  final HomeStartupService? startupService;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _imageController;
  late AnimationController _textController;

  late Animation<double> _imageScaleAnimation;

  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;

  bool _startupFailed = false;
  bool _starting = false;
  bool _initialized = false;
  late final Future<void> _minimumDisplay;
  String _startupMessage = 'Unable to start. Please try again.';

  @override
  void initState() {
    super.initState();
    _minimumDisplay = Future<void>.delayed(const Duration(milliseconds: 1400));

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0A0A0A),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _imageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _imageScaleAnimation = Tween<double>(begin: 1.06, end: 1.0).animate(
      CurvedAnimation(
        parent: _imageController,
        curve: Curves.easeOutCubic,
      ),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _textFadeAnimation = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOutCubic,
      ),
    );

    _imageController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _textController.forward();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startApp();
    });
  }

  Future<void> _startApp() async {
    if (_starting) return;
    _starting = true;
    setState(() => _startupFailed = false);
    try {
      if (!_initialized) {
        await widget.initialize?.call();
        _initialized = true;
      }
      if (!mounted) return;
      final service = widget.startupService;
      final homeData = await service?.load();
      if (!mounted) return;
      if (service != null && homeData != null) {
        unawaited(
            service.preloadImages(homeData, context).catchError((Object _) {
          debugPrint('Startup artwork will load on the home screen.');
        }));
      }
      await _minimumDisplay;
      if (mounted) _navigateToHome(homeData);
    } catch (error) {
      debugPrint('App startup failed: ${error.runtimeType}');
      if (mounted) {
        setState(() {
          _startupFailed = true;
          _startupMessage = error is CatalogueLoadException
              ? error.message
              : 'Unable to start. Please try again.';
        });
      }
    } finally {
      _starting = false;
    }
  }

  void _navigateToHome(HomeStartupData? homeData) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AuthWrapper(child: MainScreen(initialHomeData: homeData)),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _imageController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _imageController,
            builder: (context, child) {
              return Transform.scale(
                scale: _imageScaleAnimation.value,
                child: Image.asset(
                  'assets/images/splash.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              );
            },
          ),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.4),
                  Colors.black.withValues(alpha: 0.92),
                ],
                stops: const [0.0, 0.35, 0.65, 1.0],
              ),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.fromLTRB(20, 24, 20, 75),
                  child: SlideTransition(
                    position: _textSlideAnimation,
                    child: FadeTransition(
                      opacity: _textFadeAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Movie Hub',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: Color(0xFFD4AF78),
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(0, 2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your World.Your Cinema...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 2.2,
                              color: Color(0xFFB8A08B),
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(0, 2),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_startupFailed) ...[
                            Text(
                              _startupMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                            TextButton(
                              onPressed: _startApp,
                              child: const Text('Retry'),
                            ),
                          ] else
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  CinemaPalette.gold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
