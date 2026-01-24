import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'main_screen.dart';

class RevealSplashScreen extends StatefulWidget {
  const RevealSplashScreen({super.key});

  @override
  State<RevealSplashScreen> createState() => _RevealSplashScreenState();
}

class _RevealSplashScreenState extends State<RevealSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _revealController;
  late AnimationController _glowController;
  late AnimationController _particleController;
  late AnimationController _gradientController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _revealAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _particleAnimation;
  late Animation<double> _gradientAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimationSequence();
    FlutterNativeSplash.remove();
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

    _revealAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: Curves.easeInOutCubic,
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
    try {
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
          if (mounted) {
            _navigateToMainScreen();
          }
        });
      });
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navigateToMainScreen();
        }
      });
    }
  }

  void _navigateToMainScreen() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var curve = Curves.easeInOutCubic;
          var curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: curve,
          );

          return FadeTransition(
            opacity: curvedAnimation,
            child: child,
          );
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

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainScreen(),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
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
          AnimatedBuilder(
            animation: _gradientController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.5 + (_gradientAnimation.value * 0.5),
                    colors: [
                      const Color(0xFFFF005C).withOpacity(0.3).withValues(), // FIXED: Added .withValues()
                      const Color(0xFF9C27B0).withOpacity(0.2).withValues(), // FIXED: Added .withValues()
                      const Color(0xFF00D4FF).withOpacity(0.1).withValues(), // FIXED: Added .withValues()
                      const Color(0xFF0D0D0D),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.7).withValues(), // FIXED: Added .withValues()
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      'SKIP',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7).withValues(), // FIXED: Added .withValues()
                        fontSize: 12,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _revealController,
              builder: (context, child) {
                double progress =
                    (_revealController.value * 100).clamp(0.0, 100.0);

                return Opacity(
                  opacity: _revealController.value > 0.5 ? 1.0 : 0.0,
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              value: _revealController.value,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFF00D4FF).withOpacity(0.8).withValues(), // FIXED: Added .withValues()
                              ),
                              backgroundColor: Colors.white.withOpacity(0.1).withValues(), // FIXED: Added .withValues()
                            ),
                          ),
                          Text(
                            '${progress.toInt()}%',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8).withValues(), // FIXED: Added .withValues()
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AnimatedBuilder(
                        animation: _glowController,
                        builder: (context, child) {
                          return Text(
                            'Crafting Your Cinematic Experience...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(
                                  0.7 + (_glowAnimation.value * 0.3)).withValues(), // FIXED: Added .withValues()
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 1.2,
                            ),
                          );
                        },
                      ),
                    ],
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
                    color: const Color(0xFFFF005C)
                        .withOpacity(_glowAnimation.value * 0.3).withValues(), // FIXED: Added .withValues()
                    blurRadius: 60 + (_glowAnimation.value * 40),
                    spreadRadius: 10 + (_glowAnimation.value * 20),
                  ),
                  BoxShadow(
                    color: const Color(0xFF00D4FF)
                        .withOpacity(_glowAnimation.value * 0.2).withValues(), // FIXED: Added .withValues()
                    blurRadius: 40 + (_glowAnimation.value * 30),
                    spreadRadius: 5 + (_glowAnimation.value * 15),
                  ),
                ],
              ),
            );
          },
        ),
        _buildTextWithReveal(),
        Positioned(
          top: 20,
          right: 20,
          child: AnimatedBuilder(
            animation: _revealController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - _revealAnimation.value)),
                child: Opacity(
                  opacity: _revealAnimation.value,
                  child: Transform.rotate(
                    angle: _revealAnimation.value * 0.3,
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: const Color(0xFF00D4FF),
                      size: 36,
                      shadows: [
                        Shadow(
                          blurRadius: 15,
                          color: const Color(0xFF00D4FF).withOpacity(0.6).withValues(), // FIXED: Added .withValues()
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  Widget _buildTextWithReveal() {
    const String mainText = "FLIXORA X\nCINEMA";
    const String subtitle = "Ultimate Cinematic Experience";
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            Text(
              mainText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.05).withValues(), // FIXED: Added .withValues()
                fontSize: 42,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                height: 1.2,
              ),
            ),
            AnimatedBuilder(
              animation: _revealController,
              builder: (context, child) {
                return ClipPath(
                  clipper: _RevealClipper(_revealAnimation.value),
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: [
                          const Color(0xFFFF005C),
                          const Color(0xFF00D4FF),
                          const Color(0xFFFF005C),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds);
                    },
                    child: Text(
                      mainText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        height: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _opacityAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8).withValues(), // FIXED: Added .withValues()
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                ),
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
            return _buildAdvancedParticle(index: index, totalParticles: 12);
          }),
        );
      },
    );
  }

  Widget _buildAdvancedParticle(
      {required int index, required int totalParticles}) {
    double delay = (index / totalParticles) * 0.8;
    double animationValue = (_particleAnimation.value - delay).clamp(0.0, 1.0);

    double left = (MediaQuery.of(context).size.width * 0.1) +
        (index * MediaQuery.of(context).size.width * 0.08);
    double top = (MediaQuery.of(context).size.height * 0.2) +
        (index % 4 * MediaQuery.of(context).size.height * 0.2);

    List<Color> particleColors = [
      const Color(0xFFFF005C),
      const Color(0xFF00D4FF),
      const Color(0xFF9C27B0),
      const Color(0xFF00FF88),
    ];

    Color color = particleColors[index % particleColors.length];

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
                    color: color.withOpacity(0.6).withValues(), // FIXED: Added .withValues()
                    blurRadius: 10 + (animationValue * 20),
                    spreadRadius: 1 + (animationValue * 4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class _RevealClipper extends CustomClipper<Path> {
  final double revealPercent;

  const _RevealClipper(this.revealPercent);

  @override
  Path getClip(Size size) {
    final path = Path();
    path.addRect(Rect.fromLTRB(0, 0, size.width * revealPercent, size.height));
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    return oldClipper is _RevealClipper &&
        oldClipper.revealPercent != revealPercent;
  }
}