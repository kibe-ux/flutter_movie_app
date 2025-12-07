import 'package:flutter/material.dart';
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

  // Responsive values
  late double _screenWidth;
  late double _screenHeight;
  bool _isSmallScreen = false;
  bool _isVerySmallScreen = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get screen size
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
    _isSmallScreen = _screenWidth < 360; // Phones like iPhone SE
    _isVerySmallScreen = _screenWidth < 320; // Very small devices

    // Start animations after we know screen size
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnimationSequence();
    });
  }

  void _setupAnimations() {
    _slideController = AnimationController(
      duration: Duration(milliseconds: _isSmallScreen ? 1500 : 1800),
      vsync: this,
    );

    _revealController = AnimationController(
      duration: Duration(milliseconds: _isSmallScreen ? 1500 : 2000),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: Duration(milliseconds: _isSmallScreen ? 1200 : 1500),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: Duration(milliseconds: _isSmallScreen ? 2000 : 2500),
      vsync: this,
    );

    _gradientController = AnimationController(
      duration: Duration(milliseconds: _isSmallScreen ? 2500 : 3000),
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
        Future.delayed(Duration(milliseconds: _isSmallScreen ? 150 : 200), () {
          _revealController.forward();
        });

        Future.delayed(Duration(milliseconds: _isSmallScreen ? 300 : 400), () {
          _glowController.forward();
        });

        Future.delayed(Duration(milliseconds: _isSmallScreen ? 450 : 600), () {
          _particleController.forward();
          _gradientController.forward();
        });

        Future.delayed(Duration(milliseconds: _isSmallScreen ? 3000 : 3500),
            () {
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
        transitionDuration: Duration(milliseconds: _isSmallScreen ? 600 : 800),
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
          // Responsive gradient background
          AnimatedBuilder(
            animation: _gradientController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2 +
                        (_gradientAnimation.value *
                            0.5), // Smaller radius for small screens
                    colors: [
                      const Color(0xFFFF005C).withOpacity(0.3),
                      const Color(0xFF9C27B0).withOpacity(0.2),
                      const Color(0xFF00D4FF).withOpacity(0.1),
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
                padding: EdgeInsets.symmetric(
                  horizontal: _isVerySmallScreen ? 16 : 32,
                  vertical: _isVerySmallScreen ? 12 : 24,
                ),
                child: _buildMainContent(),
              ),
            ),
          ),
          // Responsive skip button
          Positioned(
            top: _isSmallScreen ? 40 : 60,
            right: _isSmallScreen ? 20 : 30,
            child: AnimatedBuilder(
              animation: _revealController,
              builder: (context, child) {
                return Opacity(
                  opacity: _revealController.value > 0.7 ? 1.0 : 0.0,
                  child: TextButton(
                    onPressed: _skipToMainScreen,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.7),
                      padding: EdgeInsets.symmetric(
                        horizontal: _isSmallScreen ? 12 : 16,
                        vertical: _isSmallScreen ? 6 : 8,
                      ),
                    ),
                    child: Text(
                      'SKIP',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: _isSmallScreen ? 10 : 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
        // Responsive glow effect
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            final baseWidth =
                _isVerySmallScreen ? 240 : (_isSmallScreen ? 280 : 300);
            final baseHeight =
                _isVerySmallScreen ? 160 : (_isSmallScreen ? 180 : 200);

            return Container(
              width: baseWidth +
                  (_glowAnimation.value * (_isSmallScreen ? 80 : 100)),
              height: baseHeight +
                  (_glowAnimation.value * (_isSmallScreen ? 40 : 50)),
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(_isSmallScreen ? 30 : 40),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF005C)
                        .withOpacity(_glowAnimation.value * 0.3),
                    blurRadius: (_isSmallScreen ? 40 : 60) +
                        (_glowAnimation.value * (_isSmallScreen ? 30 : 40)),
                    spreadRadius: (_isSmallScreen ? 8 : 10) +
                        (_glowAnimation.value * (_isSmallScreen ? 15 : 20)),
                  ),
                  BoxShadow(
                    color: const Color(0xFF00D4FF)
                        .withOpacity(_glowAnimation.value * 0.2),
                    blurRadius: (_isSmallScreen ? 30 : 40) +
                        (_glowAnimation.value * (_isSmallScreen ? 25 : 30)),
                    spreadRadius: (_isSmallScreen ? 4 : 5) +
                        (_glowAnimation.value * (_isSmallScreen ? 12 : 15)),
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
    const String mainText = "FLIXORA X\nCINEMA";
    const String subtitle = "Ultimate Cinematic Experience";

    // Responsive font sizes
    final mainFontSize = _isVerySmallScreen ? 32 : (_isSmallScreen ? 36 : 42);
    final subtitleFontSize =
        _isVerySmallScreen ? 12 : (_isSmallScreen ? 14 : 16);
    final mainLetterSpacing = _isSmallScreen ? 2.0 : 3.0;
    final subtitleLetterSpacing = _isSmallScreen ? 1.5 : 2.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            // Background text
            Text(
              mainText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.05),
                fontSize: mainFontSize.toDouble(),
                fontWeight: FontWeight.w900,
                letterSpacing: mainLetterSpacing,
                height: 1.2,
              ),
            ),
            // Animated reveal text
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
                      style: TextStyle(
                        fontSize: mainFontSize.toDouble(),
                        fontWeight: FontWeight.w900,
                        letterSpacing: mainLetterSpacing,
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
        SizedBox(height: _isSmallScreen ? 12 : 16),
        AnimatedBuilder(
          animation: _opacityAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: subtitleFontSize.toDouble(),
                  fontWeight: FontWeight.w300,
                  letterSpacing: subtitleLetterSpacing,
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
          children: List.generate(_isSmallScreen ? 8 : 12, (index) {
            double delay = (index / (_isSmallScreen ? 8 : 12)) * 0.8;
            double animationValue =
                (_particleAnimation.value - delay).clamp(0.0, 1.0);

            // Responsive particle positioning
            double left =
                (_screenWidth * 0.1) + (index * (_isSmallScreen ? 25 : 30));
            double top = (_screenHeight * 0.2) +
                (index % (_isSmallScreen ? 3 : 4) * (_isSmallScreen ? 50 : 60));

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
                  offset: Offset(
                      0, (_isSmallScreen ? 30 : 40) * (1 - animationValue)),
                  child: Transform.scale(
                    scale: 0.3 + (animationValue * 0.7),
                    child: Container(
                      width: (_isSmallScreen ? 3 : 4) +
                          (animationValue * (_isSmallScreen ? 6 : 8)),
                      height: (_isSmallScreen ? 3 : 4) +
                          (animationValue * (_isSmallScreen ? 6 : 8)),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.6),
                            blurRadius: (_isSmallScreen ? 8 : 10) +
                                (animationValue * (_isSmallScreen ? 15 : 20)),
                            spreadRadius:
                                1 + (animationValue * (_isSmallScreen ? 3 : 4)),
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
