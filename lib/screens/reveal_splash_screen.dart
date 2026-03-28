import 'package:flutter/material.dart';
import 'main_screen.dart';

class RevealSplashScreen extends StatefulWidget {
  const RevealSplashScreen({super.key});

  @override
  State<RevealSplashScreen> createState() => _RevealSplashScreenState();
}

class _RevealSplashScreenState extends State<RevealSplashScreen>
    with TickerProviderStateMixin {
  // ✅ Guard to prevent double reveal
  static bool _revealHasRun = false;

  late AnimationController _slideController;
  late AnimationController _revealController;
  late AnimationController _glowController;
  late AnimationController _particleController;
  late AnimationController _gradientController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _particleAnimation;
  late Animation<double> _gradientAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    if (_revealHasRun) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToMainScreen();
      });
      return;
    }

    _revealHasRun = true;

    _setupAnimations();
    _startAnimationSequence();
  }

  void _setupAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _revealController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _gradientController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.elasticOut,
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _particleController,
        curve: Curves.easeOut,
      ),
    );

    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _gradientController,
        curve: Curves.easeInOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  void _startAnimationSequence() {
    _slideController.forward().whenComplete(() {
      Future.delayed(const Duration(milliseconds: 200), () {
        _revealController.forward();
      });

      Future.delayed(const Duration(milliseconds: 400), () {
        _glowController.forward();
      });

      Future.delayed(const Duration(milliseconds: 600), () {
        _particleController.forward();
        _gradientController.forward();
      });

      Future.delayed(const Duration(milliseconds: 3500), () {
        if (mounted) _navigateToMainScreen();
      });
    });
  }

  void _navigateToMainScreen() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation =
              CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
          return FadeTransition(opacity: curvedAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  void _skipToMainScreen() {
    _slideController.stop();
    _revealController.stop();
    _glowController.stop();
    _particleController.stop();
    _gradientController.stop();
    _navigateToMainScreen();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _revealController.dispose();
    _glowController.dispose();
    _particleController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          // Gradient background
          AnimatedBuilder(
            animation: _gradientController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.5 + (_gradientAnimation.value * 0.5),
                    colors: const [
                      Color(0x26FF005C), // semi-transparent
                      Color(0x339C27B0),
                      Color(0x1F00D4FF),
                      Color(0xFF0D0D0D),
                    ],
                    stops: const [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              );
            },
          ),
          _buildFloatingParticles(),
          Center(
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: _buildMainContent(),
              ),
            ),
          ),
          Positioned(
            top: 60,
            right: 30,
            child: AnimatedBuilder(
              animation: _revealController,
              builder: (context, child) {
                return Opacity(
                  opacity: _revealController.value > 0.7 ? 1.0 : 0.0,
                  child: TextButton(
                    onPressed: _skipToMainScreen,
                    child: const Text('SKIP', style: TextStyle(color: Colors.white)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow container
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Container(
              width: 300 + (_glowAnimation.value * 100),
              height: 200 + (_glowAnimation.value * 50),
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF005C).withValues(alpha: _glowAnimation.value * 0.3),
                    blurRadius: 60 + (_glowAnimation.value * 40),
                    spreadRadius: 10 + (_glowAnimation.value * 20),
                  ),
                  BoxShadow(
                    color: const Color(0xFF00D4FF).withValues(alpha: _glowAnimation.value * 0.2),
                    blurRadius: 40 + (_glowAnimation.value * 30),
                    spreadRadius: 5 + (_glowAnimation.value * 15),
                  ),
                ],
              ),
            );
          },
        ),
        _buildTextWithReveal(),
      ],
    );
  }

  Widget _buildTextWithReveal() {
    const mainText = "FLIXORA X\nCINEMA";
    const subtitle = "Ultimate Cinematic Experience";
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          mainText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _opacityAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: const Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300, letterSpacing: 2, color: Colors.white70),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFloatingParticles() {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        return Stack(
          children: List.generate(12, (index) {
            double animationValue = (_particleAnimation.value - (index / 12) * 0.8).clamp(0.0, 1.0);
            double left = MediaQuery.of(context).size.width * 0.1 + index * MediaQuery.of(context).size.width * 0.08;
            double top = MediaQuery.of(context).size.height * 0.2 + (index % 4) * MediaQuery.of(context).size.height * 0.2;
            Color color = [const Color(0xFFFF005C), const Color(0xFF00D4FF), const Color(0xFF9C27B0), const Color(0xFF00FF88)][index % 4];

            return Positioned(
              left: left,
              top: top,
              child: Opacity(
                opacity: animationValue * 0.8,
                child: Transform.translate(
                  offset: Offset(0, 40 * (1 - animationValue)),
                  child: Transform.scale(
                    scale: 0.3 + (animationValue * 0.7),
                    child: Container(
                      width: 4 + (animationValue * 8),
                      height: 4 + (animationValue * 8),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.6),
                            blurRadius: 10 + animationValue * 20,
                            spreadRadius: 1 + animationValue * 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
