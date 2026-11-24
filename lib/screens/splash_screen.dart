import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design/design_system.dart';
import '../design/identity.dart';

// ─────────────────────────────────────────────────────────────
// الاستهلال — نفس فكرة مشروع gpt، باسم JoeX PRO ولون المنصة
// خلفية داكنة بضوء خفيف في الوسط، ونبضة نور تلف حول حواف الشاشة (وهج ناعم
// تحت خط رفيع ساطع). في الوسط الشعار يصعد ويعبره ضوء من اعلاه لاسفله مع خط
// يمتد خارج حافتيه، وتحته الاسم على لوح زجاج مغبش. لا نصوص اخرى. بعد لحظة
// تُركّب الشاشة التالية تحته ويذوب هو فوقها.
// ─────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  /// قبل الخروج مباشرة: تُركّب الشاشة التالية تحتها
  final Future<void> Function()? onReveal;

  const SplashScreen({super.key, this.onComplete, this.onReveal});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

typedef JoeXSplashPage = SplashScreen;

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// الدخول ثم الوقفة: الشعار والزجاج يصعدان في اوله
  late final AnimationController _main = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  /// الذوبان فوق الشاشة التالية
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  /// نبضة الحواف: لفة كل 2.8 ثانية
  late final AnimationController _edge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  /// الضوء العابر فوق الشعار: كل 2.4 ثانية
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  bool _started = false;
  bool _exiting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (motionAllowed(context)) {
        _edge.repeat();
        _scan.repeat();
      }
      _run();
    }
  }

  Future<void> _run() async {
    // لا يبدأ قبل الشعار حتى لا يظهر متأخرا
    if (!isWidgetTest) {
      try {
        await Future.wait([
          precacheImage(const AssetImage(kLogoAsset), context),
          precacheImage(const AssetImage(kHeaderAsset), context),
        ]);
      } catch (_) {}
      if (!mounted) return;
    }
    await _main.forward();
    if (!mounted) return;

    await widget.onReveal?.call();
    if (!mounted) return;
    setState(() => _exiting = true);

    await _exit.forward();
    if (!mounted) return;
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _main.dispose();
    _exit.dispose();
    _edge.dispose();
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final logo = math.min(156.0, size.width * 0.4);

    return Material(
      type: MaterialType.transparency,
      child: Directionality(
        textDirection: appDir,
        child: IgnorePointer(
          ignoring: _exiting,
          child: AnimatedBuilder(
            animation: Listenable.merge([_main, _exit, _edge, _scan]),
            builder: (context, _) {
              final m = _main.value;
              final out = Motion.standard.transform(_exit.value);
              // تنفس الوهج: يخف في منتصف كل لفة
              final breath =
                  1 - 0.45 * (0.5 - 0.5 * math.cos(_edge.value * 2 * math.pi));
              final rise = phase(m, 0, 0.39, Motion.emphasized);
              final riseGlass = phase(m, 0.08, 0.47, Motion.emphasized);
              final edgeIn = phase(m, 0.08, 0.47, Curves.easeOut);

              return Opacity(
                opacity: 1 - out,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // الخلفية: ضوء خفيف بلون المنصة في الوسط
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.08),
                          radius: 1.1,
                          colors: [kJadeInk, kCoal, kInk],
                          stops: const [0, 0.48, 1],
                        ),
                      ),
                    ),
                    // نبضة الحواف
                    Opacity(
                      opacity: edgeIn,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _EdgeLightPainter(
                            turn: _edge.value,
                            glow: breath,
                            colors: [kEmeraldDeep, kJade, kWhite, kEmeraldPale],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // الشعار فوق هالته
                          SizedBox(
                            width: logo * 2.4,
                            height: logo,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Opacity(
                                  opacity: breath,
                                  child: Container(
                                    width: logo * 2.4,
                                    height: logo * 2.4,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          kEmerald.withValues(alpha: 0.32),
                                          kJade.withValues(alpha: 0.12),
                                          kJade.withValues(alpha: 0),
                                        ],
                                        stops: const [0, 0.42, 0.68],
                                      ),
                                    ),
                                  ),
                                ),
                                Opacity(
                                  opacity: rise,
                                  child: Transform.translate(
                                    offset: Offset(0, 10 * (1 - rise)),
                                    child: Transform.scale(
                                      scale: 0.97 + 0.03 * rise,
                                      child: _ScannedLogo(
                                        size: logo,
                                        scan: motionAllowed(context)
                                            ? _scan.value
                                            : -1,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 26),
                          // الاسم على زجاج مغبش
                          Opacity(
                            opacity: riseGlass,
                            child: Transform.translate(
                              offset: Offset(0, 10 * (1 - riseGlass)),
                              child: Transform.scale(
                                scale: 0.97 + 0.03 * riseGlass,
                                child: const _GlassName(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// الشعار في دائرته بوهج بلون المنصة، يعبره من اعلاه لاسفله ضوء داخل
/// الدائرة وخط رفيع يمتد خارج حافتيه. [scan] من 0 الى 1، وسالب بلا ضوء.
class _ScannedLogo extends StatelessWidget {
  final double size;
  final double scan;
  const _ScannedLogo({required this.size, required this.scan});

  @override
  Widget build(BuildContext context) {
    // الضوء يعبر في اول 70% من كل دورة ثم يرتاح
    final p = scan < 0 ? -1.0 : (scan / 0.7);
    final moving = p >= 0 && p <= 1;
    final lineOpacity = !moving
        ? 0.0
        : (p < 0.11 ? p / 0.11 : (p > 0.89 ? (1 - p) / 0.11 : 1.0));
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kEmerald.withValues(alpha: 0.45),
                    blurRadius: 22,
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    kLogoAsset,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => ColoredBox(color: kCoal),
                  ),
                  if (moving)
                    // شريط ضوء ينزل داخل الدائرة فقط
                    Align(
                      alignment: Alignment(0, -1.6 + 3.2 * p),
                      child: FractionallySizedBox(
                        widthFactor: 1,
                        heightFactor: 0.34,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                kEmeraldPale.withValues(alpha: 0),
                                kWhite.withValues(alpha: 0.55),
                                kEmeraldPale.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (moving)
            Positioned(
              left: -size * 0.18,
              right: -size * 0.18,
              top: size * p.clamp(0.0, 1.0) - 0.75,
              height: 1.5,
              child: Opacity(
                opacity: lineOpacity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        kEmeraldPale.withValues(alpha: 0),
                        kEmeraldPale.withValues(alpha: 0.9),
                        kEmeraldPale.withValues(alpha: 0),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kEmerald.withValues(alpha: 0.55),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// JoeX PRO على لوح زجاج مغبش بحافة بيضاء خافتة
class _GlassName extends StatelessWidget {
  const _GlassName();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0xCC000000),
            blurRadius: 60,
            spreadRadius: -24,
            offset: Offset(0, 24),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  kWhite.withValues(alpha: 0.11),
                  kWhite.withValues(alpha: 0.035),
                ],
              ),
              border: Border.all(color: kWhite.withValues(alpha: 0.14)),
            ),
            child: const NameMark(size: 26, spacing: 1.4),
          ),
        ),
      ),
    );
  }
}

/// نبضة نور تلف حول حواف الشاشة: قوس ملون يدور على الاطار، وتحته وهج ناعم
/// يتنفس. [turn] من 0 الى 1 لفة كاملة.
class _EdgeLightPainter extends CustomPainter {
  final double turn;
  final double glow;
  final List<Color> colors;
  const _EdgeLightPainter({
    required this.turn,
    required this.glow,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final shader = SweepGradient(
      center: Alignment.center,
      transform: GradientRotation(turn * 2 * math.pi),
      colors: [
        colors[0].withValues(alpha: 0),
        colors[0].withValues(alpha: 0),
        colors[0],
        colors[1],
        colors[2],
        colors[3],
        colors[3].withValues(alpha: 0),
      ],
      stops: const [
        0,
        250 / 360,
        284 / 360,
        312 / 360,
        336 / 360,
        349 / 360,
        1,
      ],
    ).createShader(rect);

    final frame = RRect.fromRectAndRadius(
      rect.deflate(1),
      const Radius.circular(28),
    );
    // الوهج الناعم تحت الخط
    canvas.drawRRect(
      frame.deflate(7),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..shader = shader
        ..color = Color.fromRGBO(255, 255, 255, glow.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
    );
    // الخط الساطع على الحافة
    canvas.drawRRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _EdgeLightPainter old) =>
      old.turn != turn || old.glow != glow || old.colors != colors;
}
