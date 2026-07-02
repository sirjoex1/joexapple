import 'dart:math' as math;
import 'package:flutter/material.dart';

class JoeXSplashPage extends StatefulWidget {
  final VoidCallback onComplete;

  const JoeXSplashPage({super.key, required this.onComplete});

  @override
  State<JoeXSplashPage> createState() => _JoeXSplashPageState();
}

class _JoeXSplashPageState extends State<JoeXSplashPage>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _serverController;

  @override
  void initState() {
    super.initState();

    // 1. Core rotation for circular arc animation
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // 2. Pulse controller for the blinking cursor
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // 3. Loading progression controller
    _serverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    // Begin sequence
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _serverController.forward().then((_) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) {
              widget.onComplete();
            }
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // 1. Deep matte black background with a subtle radial vignette
          Container(
            width: size.width,
            height: size.height,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Color(0xFF161618), // Subtle lighter center
                  Color(0xFF0A0A0A), // Deep matte black outer
                ],
                stops: [0.0, 1.0],
              ),
            ),
          ),

          // 2. Clean subtle grid pattern overlay
          Positioned.fill(
            child: CustomPaint(
              painter: GridBackgroundPainter(),
            ),
          ),

          // 3. Main Foreground UI
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 24.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: 10),

                  // Middle Section: App core dashboard
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // A. Minimal Pill Tag (Replaced green badge)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFA8A8B3).withValues(alpha: 0.3),
                            width: 1.0,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.security,
                              color: Color(0xFFA8A8B3),
                              size: 11,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "JOEX CYBERNETIC BYPASS",
                              style: TextStyle(
                                color: Color(0xFFA8A8B3),
                                fontSize: 9.0,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 55),

                      // B. Rotating circular core with Logo
                      AnimatedBuilder(
                        animation: _rotationController,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer rotating metallic double ring and electric blue arc
                              SizedBox(
                                width: 170,
                                height: 170,
                                child: CustomPaint(
                                  painter: CircularCorePainter(
                                    rotation: _rotationController.value * 2 * math.pi,
                                  ),
                                ),
                              ),
                              // Glowing/shadowed inner circle frame with logo
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF0A0A0A),
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        "assets/app_logo.png",
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  // Inner shadow overlay for premium military feel
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF3A3A3C),
                                        width: 1.0,
                                      ),
                                      gradient: RadialGradient(
                                        colors: [
                                          Colors.transparent,
                                          const Color(0xFF0A0A0A).withValues(alpha: 0.7),
                                        ],
                                        stops: const [0.7, 1.0],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 45),

                      // C. Modern Gradient App Title
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return const LinearGradient(
                            colors: [
                              Color(0xFF8E8E93), // Slate silver
                              Colors.white,      // Pure white
                              Color(0xFF8E8E93), // Slate silver
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ).createShader(bounds);
                        },
                        child: const Text(
                          "JOEX TOOL",
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4.5,
                            color: Colors.white,
                            fontFamily: 'sans-serif-condensed',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // D. Subtitle (Arabic)
                      const Text(
                        "أقوى اسكربت فك تشفير في الشرق الأوسط",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF8E8E93),
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                  // Bottom Loader: Minimal progress indicator & telemetry log
                  AnimatedBuilder(
                    animation: Listenable.merge([_serverController, _pulseController]),
                    builder: (context, _) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Status text with blinking cursor in monospace
                                Text(
                                  "${_getCyberDiagnosticsLog(_serverController.value)}${_pulseController.value > 0.5 ? '_' : ''}",
                                  style: const TextStyle(
                                    color: Color(0xFF8E8E93),
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                // Percentage right-aligned in monospace
                                Text(
                                  "${(_serverController.value * 100).toInt()}%",
                                  style: const TextStyle(
                                    color: Color(0xFFA8A8B3),
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Thin 2px height progress bar
                            Container(
                              width: double.infinity,
                              height: 2,
                              color: const Color(0xFF2C2C2E), // Dark track
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: _serverController.value,
                                child: Container(
                                  height: 2,
                                  color: const Color(0xFFA8A8B3), // Silver fill
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  // Clean, professional telemetry logs (no green indicators, no emojis)
  String _getCyberDiagnosticsLog(double progress) {
    if (progress < 0.15) {
      return "CONNECTING TO SATELLITE LINK";
    } else if (progress < 0.35) {
      return "EXTRACTING RSA DECRYPTION KEY VALS";
    } else if (progress < 0.55) {
      return "INJECTING PROBABILITY MATRIX";
    } else if (progress < 0.75) {
      return "STABILIZING SECURE PORT 8443";
    } else if (progress < 0.92) {
      return "DECODING CELLULAR ENCRYPTION 100%";
    } else {
      return "ALL SECURE TUNNELS ESTABLISHED";
    }
  }
}

// Clean grid pattern painter
class GridBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF2C2C2E).withValues(alpha: 0.12)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const double cellSpacing = 35.0;
    for (double y = 0; y < size.height; y += cellSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = 0; x < size.width; x += cellSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant GridBackgroundPainter oldDelegate) => false;
}

// Sleek double ring with electric blue rotating arc
class CircularCorePainter extends CustomPainter {
  final double rotation;

  CircularCorePainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double outerRadius = size.width / 2;
    final double innerRadius = outerRadius - 6;

    // 1. Draw outer metallic ring
    final outerRingPaint = Paint()
      ..color = const Color(0xFF3A3A3C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, outerRadius, outerRingPaint);

    // 2. Draw inner metallic ring
    final innerRingPaint = Paint()
      ..color = const Color(0xFF2C2C2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, innerRadius, innerRingPaint);

    // 3. Draw thin military/technical detail marks
    final detailPaint = Paint()
      ..color = const Color(0xFFA8A8B3).withValues(alpha: 0.3)
      ..strokeWidth = 1.0;

    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final start = Offset(
        center.dx + (outerRadius - 2) * math.cos(angle),
        center.dy + (outerRadius - 2) * math.sin(angle),
      );
      final end = Offset(
        center.dx + (outerRadius + 2) * math.cos(angle),
        center.dy + (outerRadius + 2) * math.sin(angle),
      );
      canvas.drawLine(start, end, detailPaint);
    }

    // 4. Draw cold electric blue rotating arc highlight
    final arcPaint = Paint()
      ..color = const Color(0xFF4A9EFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(
      center: center,
      radius: (outerRadius + innerRadius) / 2,
    );

    canvas.drawArc(
      rect,
      rotation,
      1.0, // Sweep angle (~57 degrees)
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CircularCorePainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}
