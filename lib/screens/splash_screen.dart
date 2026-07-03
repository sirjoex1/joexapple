import 'package:flutter/material.dart';

class JoeXSplashPage extends StatefulWidget {
  final VoidCallback onComplete;

  const JoeXSplashPage({super.key, required this.onComplete});

  @override
  State<JoeXSplashPage> createState() => _JoeXSplashPageState();
}

class _JoeXSplashPageState extends State<JoeXSplashPage>
    with TickerProviderStateMixin {
  // Split reveal animation controller
  late AnimationController _splitController;
  // Logo appear animation controller
  late AnimationController _logoController;
  // Name text animation controller
  late AnimationController _nameController;

  // Animations
  late Animation<Offset> _topHalfSlide;
  late Animation<Offset> _bottomHalfSlide;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _nameFade;
  late Animation<Offset> _nameSlide;
  late Animation<double> _bracketFade;
  late Animation<double> _glowPulse;

  // Glow pulse controller
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();

    // 1. Split controller — halves slide apart
    _splitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // 2. Logo controller — logo fades in + scales
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // 3. Name controller — text appears
    _nameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // 4. Glow pulse controller — continuous subtle glow
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Define animations
    _topHalfSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1.0),
    ).animate(CurvedAnimation(
      parent: _splitController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeInOutCubic),
    ));

    _bottomHalfSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1.0),
    ).animate(CurvedAnimation(
      parent: _splitController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeInOutCubic),
    ));

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutBack,
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _bracketFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _nameFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _nameController,
        curve: Curves.easeOut,
      ),
    );

    _nameSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _nameController,
      curve: Curves.easeOutCubic,
    ));

    _glowPulse = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    // Begin the animation sequence
    _startAnimationSequence();
  }

  void _startAnimationSequence() async {
    // Wait a brief moment before starting
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    // Phase 1: Logo appears in the center (while halves are still together)
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // Phase 2: Halves split apart
    _splitController.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // Phase 3: Name text appears
    _nameController.forward();

    // Start the glow pulse
    _glowController.repeat(reverse: true);

    // Wait for everything to settle, then complete
    await Future.delayed(const Duration(milliseconds: 2200));
    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _splitController.dispose();
    _logoController.dispose();
    _nameController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Stack(
        children: [
          // ===== TOP HALF (slides up) =====
          SlideTransition(
            position: _topHalfSlide,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: size.width,
                height: size.height / 2,
                child: Container(
                  color: const Color(0xFF0D0B14),
                  child: CustomPaint(
                    painter: _HorizontalLinesPainter(),
                    size: Size(size.width, size.height / 2),
                  ),
                ),
              ),
            ),
          ),

          // ===== BOTTOM HALF (slides down) =====
          SlideTransition(
            position: _bottomHalfSlide,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: size.width,
                height: size.height / 2,
                child: Container(
                  color: const Color(0xFF0D0B14),
                  child: CustomPaint(
                    painter: _HorizontalLinesPainter(),
                    size: Size(size.width, size.height / 2),
                  ),
                ),
              ),
            ),
          ),

          // ===== CENTER CONTENT (Logo + Name) — stays in place =====
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo with L-shaped corner brackets
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _logoController,
                    _glowController,
                  ]),
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: SizedBox(
                          width: 130,
                          height: 130,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Purple glow behind logo
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF7C3AED)
                                          .withValues(alpha: _glowPulse.value * 0.4),
                                      blurRadius: 40,
                                      spreadRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              // The actual logo
                              ClipOval(
                                child: SizedBox(
                                  width: 90,
                                  height: 90,
                                  child: Image.asset(
                                    "assets/app_logo.png",
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              // L-shaped corner brackets
                              FadeTransition(
                                opacity: _bracketFade,
                                child: CustomPaint(
                                  size: const Size(130, 130),
                                  painter: _CornerBracketsPainter(
                                    color: const Color(0xFF7C3AED),
                                    strokeWidth: 2.0,
                                    armLength: 16.0,
                                    padding: 8.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // App Name
                SlideTransition(
                  position: _nameSlide,
                  child: FadeTransition(
                    opacity: _nameFade,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) {
                            return const LinearGradient(
                              colors: [
                                Color(0xFFE0E0E0),
                                Colors.white,
                                Color(0xFFE0E0E0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ).createShader(bounds);
                          },
                          child: const Text(
                            "JoeX Apple",
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3.0,
                              color: Colors.white,
                              fontFamily: 'sans-serif-condensed',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Subtle purple underline accent
                        AnimatedBuilder(
                          animation: _nameController,
                          builder: (context, child) {
                            return Container(
                              width: 60 * _nameController.value,
                              height: 2,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(1),
                                gradient: const LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Color(0xFF7C3AED),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints thin horizontal lines (grid paper effect) on the half panels
class _HorizontalLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1530)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const double spacing = 24.0;
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints 4 L-shaped corner brackets around the logo
class _CornerBracketsPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double armLength;
  final double padding;

  _CornerBracketsPainter({
    required this.color,
    required this.strokeWidth,
    required this.armLength,
    required this.padding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double left = padding;
    final double top = padding;
    final double right = size.width - padding;
    final double bottom = size.height - padding;

    // Top-left corner
    canvas.drawLine(
      Offset(left, top),
      Offset(left + armLength, top),
      paint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left, top + armLength),
      paint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(right, top),
      Offset(right - armLength, top),
      paint,
    );
    canvas.drawLine(
      Offset(right, top),
      Offset(right, top + armLength),
      paint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left + armLength, bottom),
      paint,
    );
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left, bottom - armLength),
      paint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right - armLength, bottom),
      paint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - armLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.armLength != armLength ||
        oldDelegate.padding != padding;
  }
}
