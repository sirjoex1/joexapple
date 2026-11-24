import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'design_system.dart';

// ═══════════════════════════════════════════════════════════════
// قطع هوية JoeX PRO المشتركة — اسود واخضر:
// رسام الوسام بحلقات خضراء، الاسم بحروف ملكية، الخط الاخضر بماسة،
// العملة الخضراء للخطوات، البطاقة السوداء بحافة خضراء، الماسة،
// والرأس المشترك بصورته وشعاره، ولوح التذكرة.
// ═══════════════════════════════════════════════════════════════

/// ماسة (معيّن) بنصف عرض [rx] ونصف ارتفاع [ry]
Path diamondPath(Offset c, double rx, [double? ry]) {
  final h = ry ?? rx;
  return Path()
    ..moveTo(c.dx, c.dy - h)
    ..lineTo(c.dx + rx, c.dy)
    ..lineTo(c.dx, c.dy + h)
    ..lineTo(c.dx - rx, c.dy)
    ..close();
}

/// مربع مستدير مدار 45 درجة: ماسة بزوايا ناعمة
Path softDiamondPath(Offset c, double r, double corner) {
  final side = r * math.sqrt2;
  final rect = Rect.fromCenter(center: Offset.zero, width: side, height: side);
  final rr = Path()
    ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(corner)));
  // دوران 45 درجة ثم نقل الى المركز، بمصفوفة عمودية 4x4
  const k = math.sqrt1_2;
  return rr.transform(
    Float64List.fromList([
      k, k, 0, 0, //
      -k, k, 0, 0, //
      0, 0, 1, 0, //
      c.dx, c.dy, 0, 1,
    ]),
  );
}

// ── الوسام ──────────────────────────────────────────────────────

class MedallionPainter extends CustomPainter {
  final double draw;
  final double spin;
  final double? progress;
  final double inner;

  const MedallionPainter({
    required this.draw,
    required this.spin,
    required this.inner,
    this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (draw <= 0) return;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;
    final thin = r > 40;

    // هالة: تدرج دائري بدل الضباب، اخف على المعالج في كل اطار
    final haloRect = Rect.fromCircle(center: c, radius: r * 1.25);
    canvas.drawCircle(
      c,
      r * 1.25,
      Paint()
        ..shader = RadialGradient(
          colors: [
            kJade.withValues(alpha: 0.3 * draw),
            kJade.withValues(alpha: 0.12 * draw),
            kJade.withValues(alpha: 0),
          ],
          stops: const [0.4, 0.72, 1],
        ).createShader(haloRect),
    );

    // الحلقتان: الخارجية ثم الداخلية، ترسمان من الاعلى
    final sweep = math.pi * 2 * draw;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thin ? 1.4 : 1.2
        ..color = kEmerald.withValues(alpha: 0.85),
    );
    final mid = (r + inner) / 2 + 1;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: mid),
      -math.pi / 2,
      -sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = kEmerald.withValues(alpha: 0.4),
    );

    // مؤشرات دقيقة بين الحلقتين تدور ببطء
    if (thin) {
      final ticks = Paint()
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;
      const n = 48;
      for (var i = 0; i < n; i++) {
        final a = spin * math.pi * 0.5 + i * math.pi * 2 / n;
        final long = i % 4 == 0;
        final d = Offset(math.cos(a), math.sin(a));
        ticks.color = kEmerald.withValues(alpha: (long ? 0.55 : 0.22) * draw);
        canvas.drawLine(c + d * (r - (long ? 7 : 5)), c + d * (r - 2.5), ticks);
      }
    }

    // قوس التقدم
    final p = progress;
    if (p != null && p > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        math.pi * 2 * p.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = kEmerald.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        math.pi * 2 * p.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            colors: [kEmeraldDeep, kEmerald, kEmeraldPale, kEmeraldDeep],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    // مذنّب يطوف على الحلقة الخارجية
    if (draw >= 1) {
      final a = spin * math.pi * 2;
      const tail = math.pi * 0.35;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        a - tail,
        tail,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: a - tail,
            endAngle: a,
            colors: [kEmerald.withValues(alpha: 0), kEmeraldPale],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
      final head = c + Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawCircle(
        head,
        4,
        Paint()
          ..color = kEmerald.withValues(alpha: 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(head, 1.8, Paint()..color = kWhite);
    }
  }

  @override
  bool shouldRepaint(covariant MedallionPainter old) =>
      old.draw != draw ||
      old.spin != spin ||
      old.progress != progress ||
      old.inner != inner;
}

// ── الاسم ──────────────────────────────────────────────────────

/// JoeX ابيض و PRO زمردي بحروف ملكية
class NameMark extends StatelessWidget {
  final double size;
  final double spacing;
  final TextAlign? align;

  const NameMark({
    super.key,
    required this.size,
    this.spacing = 1.2,
    this.align,
  });

  static const List<Shadow> lift = [
    Shadow(color: Color(0xCC000000), blurRadius: 12),
  ];

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: 'JoeX '),
        TextSpan(
          text: 'PRO',
          style: TextStyle(color: kEmerald),
        ),
      ],
    ),
    textDirection: TextDirection.ltr,
    textAlign: align,
    maxLines: 1,
    style: markText(
      kWhite,
      size,
      weight: FontWeight.w700,
      spacing: spacing,
    ).copyWith(shadows: lift),
  );
}

// ── الخط الذهبي ────────────────────────────────────────────────

/// خطان ذهبيان يمتدان من ماسة في الوسط ويذوبان نحو الطرفين
class GoldRule extends StatelessWidget {
  final double width;
  final double draw;
  const GoldRule({super.key, required this.width, this.draw = 1});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 12,
    child: CustomPaint(painter: _GoldRulePainter(draw: draw)),
  );
}

class _GoldRulePainter extends CustomPainter {
  final double draw;
  const _GoldRulePainter({required this.draw});

  @override
  void paint(Canvas canvas, Size size) {
    if (draw <= 0) return;
    final c = size.center(Offset.zero);
    final reach = (size.width / 2 - 1) * draw;
    for (final dir in [-1.0, 1.0]) {
      final start = c + Offset(dir * 8, 0);
      final end = c + Offset(dir * reach, 0);
      if ((end.dx - start.dx) * dir <= 0) continue;
      canvas.drawLine(
        start,
        end,
        Paint()
          ..strokeWidth = 1
          ..shader = LinearGradient(
            colors: [
              kEmerald.withValues(alpha: 0.9),
              kEmerald.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromPoints(start, end)),
      );
    }
    final d = 4.2 * Motion.overshoot.transform(draw.clamp(0.0, 1.0));
    final gem = diamondPath(c, d * 0.75, d);
    canvas.drawPath(
      gem,
      Paint()
        ..color = kEmerald.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(gem, Paint()..color = kEmeraldPale);
  }

  @override
  bool shouldRepaint(covariant _GoldRulePainter old) => old.draw != draw;
}

// ── العملة ─────────────────────────────────────────────────────

/// عملة ذهبية للخطوات والشروط: خاملة باطار ذهبي خافت، حالية بنفسجية
/// مضيئة بحلقة ذهب، ومكتملة ذهبية ممتلئة. [label] نص في قلبها.
class Coin extends StatelessWidget {
  final double size;
  final Widget label;
  final bool active;
  final bool done;

  const Coin({
    super.key,
    required this.size,
    required this.label,
    this.active = false,
    this.done = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: done ? 2 : (active ? 1 : 0)),
      duration: Motion.medium,
      curve: Motion.standard,
      builder: (context, s, child) => CustomPaint(
        painter: _CoinPainter(state: s),
        child: SizedBox.square(
          dimension: size,
          child: Center(child: child),
        ),
      ),
      child: label,
    );
  }

  /// لون النص في قلب العملة لكل حالة
  static Color ink({required bool active, required bool done}) =>
      done ? kOnEmerald : (active ? kWhite : kWhiteSoft);
}

class _CoinPainter extends CustomPainter {
  /// 0 خاملة، 1 حالية، 2 مكتملة
  final double state;
  const _CoinPainter({required this.state});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1;
    final a = state.clamp(0.0, 1.0);
    final b = (state - 1).clamp(0.0, 1.0);
    final rect = Rect.fromCircle(center: c, radius: r);

    if (a > 0) {
      canvas.drawCircle(
        c,
        r * 1.1,
        Paint()
          ..color = Color.lerp(kJade, kEmerald, b)!.withValues(alpha: 0.45 * a)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5),
      );
    }
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(Color.lerp(kCoalHi, kJade, a), kEmeraldPale, b)!,
            Color.lerp(Color.lerp(kCoal, kJadeDeep, a), kEmeraldDeep, b)!,
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 + 0.8 * a
        ..color = Color.lerp(
          kEmerald.withValues(alpha: 0.4),
          kEmerald,
          math.max(a, b),
        )!,
    );
    canvas.drawCircle(
      c,
      r - 3.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = (b > 0.5 ? kEmeraldInk : kEmerald).withValues(
          alpha: 0.25 + 0.2 * b,
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _CoinPainter old) => old.state != state;
}

// ── البطاقة المخملية ────────────────────────────────────────────

/// بطاقة مخملية بنفسجية بحافة مذهبة تلمع في زاويتين وتذوب بينهما.
/// [glow] يضيف هالة بنفسجية حولها.
class VelvetCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final bool glow;

  const VelvetCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 26,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            kCoalHi.withValues(alpha: 0.9),
            kCoal.withValues(alpha: 0.94),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
          if (glow)
            BoxShadow(color: kJade.withValues(alpha: 0.3), blurRadius: 36),
        ],
      ),
      child: CustomPaint(
        foregroundPainter: GildedEdgePainter(radius: radius),
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
  }
}

/// حافة ذهبية رفيعة حول مستطيل مستدير: ساطعة في الزاويتين المتقابلتين
class GildedEdgePainter extends CustomPainter {
  final double radius;
  final double strength;
  const GildedEdgePainter({required this.radius, this.strength = 1});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = (Offset.zero & size).deflate(0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            kEmerald.withValues(alpha: 0.85 * strength),
            kEmerald.withValues(alpha: 0.12 * strength),
            kMist.withValues(alpha: 0.1 * strength),
            kEmerald.withValues(alpha: 0.6 * strength),
          ],
          stops: const [0, 0.35, 0.65, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant GildedEdgePainter old) =>
      old.radius != radius || old.strength != strength;
}

// ── البريق ────────────────────────────────────────────────────

/// نجوم ذهبية صغيرة تومض: كل نجمة بطورها الخاص على [t] من 0 الى 1
class TwinklePainter extends CustomPainter {
  final double t;
  final int seed;
  final int count;
  final double opacity;

  const TwinklePainter({
    required this.t,
    this.seed = 11,
    this.count = 28,
    this.opacity = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final rnd = math.Random(seed);
    for (var i = 0; i < count; i++) {
      final p = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
      );
      final phaseShift = rnd.nextDouble();
      final s = 1.2 + rnd.nextDouble() * 2.6;
      final w = 0.5 + 0.5 * math.sin((t + phaseShift) * math.pi * 2);
      final a = (0.15 + 0.75 * w) * opacity;
      final star = Path()
        ..moveTo(p.dx, p.dy - s * 2)
        ..lineTo(p.dx + s * 0.35, p.dy - s * 0.35)
        ..lineTo(p.dx + s * 2, p.dy)
        ..lineTo(p.dx + s * 0.35, p.dy + s * 0.35)
        ..lineTo(p.dx, p.dy + s * 2)
        ..lineTo(p.dx - s * 0.35, p.dy + s * 0.35)
        ..lineTo(p.dx - s * 2, p.dy)
        ..lineTo(p.dx - s * 0.35, p.dy - s * 0.35)
        ..close();
      canvas.drawCircle(
        p,
        s * 1.8,
        Paint()..color = kEmerald.withValues(alpha: 0.1 * a),
      );
      canvas.drawPath(star, Paint()..color = kEmeraldPale.withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(covariant TwinklePainter old) =>
      old.t != t ||
      old.seed != seed ||
      old.count != count ||
      old.opacity != opacity;
}

// ── الرأس المشترك ──────────────────────────────────────────────

/// رأس صفحتي الدخول والصفوف: صورة بعرض الشاشة من اعلاها بزاويتين سفليتين
/// مستديرتين، عليها شارة الاسم، والشعار في دائرة بحلقة زمردية نصفها تحت حافتها.
/// الصورة من [kHeaderAsset]، ولو تعذر تحميلها يظهر سطح داكن بخطوط مائلة.
class HeroHeader extends StatelessWidget {
  final double width;
  final double topPad;

  /// طول الصورة اذا احتاجت الصفحة ان تقلصه، وبدونه [imageHeight]
  final double? bannerHeight;

  /// شارة الاسم على الصورة، وصفحة الدخول تخفيها
  final bool badge;

  const HeroHeader({
    super.key,
    required this.width,
    required this.topPad,
    this.bannerHeight,
    this.badge = true,
  });

  static double imageHeight(double width, double topPad) =>
      topPad + math.min(width * 0.46, 260);

  static double logoSize(double width) => (width * 0.18).clamp(60.0, 84.0);

  /// الطول كله: الصورة ونصف الشعار تحتها
  static double height(double width, double topPad) =>
      imageHeight(width, topPad) + logoSize(width) / 2;

  @override
  Widget build(BuildContext context) {
    final imageH = bannerHeight ?? imageHeight(width, topPad);
    final logo = logoSize(width);
    const radius = Radius.circular(30);

    return SizedBox(
      height: imageH + logo / 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: imageH,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(bottom: radius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: radius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      kHeaderAsset,
                      fit: BoxFit.cover,
                      // الوجه والورقة في النصف الاعلى: حين تقص الشاشات
                      // العريضة من الطول يبقيان ظاهرين
                      alignment: const Alignment(0, -0.3),
                      gaplessPlayback: true,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) =>
                          const CustomPaint(painter: _HeaderStandInPainter()),
                    ),
                    // ظلمة شريط الحالة في الاعلى وظلمة القاع تحت الشعار
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            kInk.withValues(alpha: 0.55),
                            kInk.withValues(alpha: 0),
                            kInk.withValues(alpha: 0),
                            kInk.withValues(alpha: 0.75),
                          ],
                          stops: const [0, 0.25, 0.55, 1],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // حافة فضية رفيعة على قوس القاع
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: imageH,
            child: const IgnorePointer(
              child: CustomPaint(painter: _HeaderRimPainter(radius: 30)),
            ),
          ),
          if (badge)
            PositionedDirectional(
              end: 16,
              bottom: logo / 2 + 14,
              child: const _NameBadge(),
            ),
          Positioned(
            top: imageH - logo / 2,
            left: 0,
            right: 0,
            child: Center(child: LogoRing(size: logo)),
          ),
        ],
      ),
    );
  }
}

/// الشعار في دائرة: قلب اسود، حلقة زمردية متدرجة، ووهج اخضر خفيف حولها
class LogoRing extends StatelessWidget {
  final double size;
  const LogoRing({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2.2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kEmeraldPale, kEmeraldDeep, kEmeraldInk],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(color: kEmerald.withValues(alpha: 0.28), blurRadius: 22),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: kInk),
        padding: EdgeInsets.all(size * 0.05),
        child: ClipOval(child: BrandLogo(size: size)),
      ),
    );
  }
}

/// شارة الاسم على الصورة: كبسولة داكنة شفافة بحافة رفيعة وشعلة صغيرة
class _NameBadge extends StatelessWidget {
  const _NameBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
      decoration: BoxDecoration(
        color: kInk.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: kEmerald.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.ltr,
        children: [
          Text(
            'JoeX PRO',
            textDirection: TextDirection.ltr,
            style: markText(kWhite, 11.5, weight: FontWeight.w700, spacing: 1),
          ),
          const SizedBox(width: 5),
          Icon(Icons.local_fire_department_rounded, size: 14, color: kEmerald),
        ],
      ),
    );
  }
}

/// بديل الصورة لو تعذر تحميلها: اسود مخضر بضوء من الاعلى وخطوط مائلة خافتة
class _HeaderStandInPainter extends CustomPainter {
  const _HeaderStandInPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A2A21), Color(0xFF0E1712), Color(0xFF070B09)],
          stops: [0, 0.6, 1],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.4),
          radius: 0.9,
          colors: [
            kEmerald.withValues(alpha: 0.12),
            kEmerald.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    final line = Paint()
      ..strokeWidth = 1
      ..color = kEmerald.withValues(alpha: 0.05);
    for (var x = -size.height; x < size.width; x += 18) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
    }
  }

  @override
  bool shouldRepaint(covariant _HeaderStandInPainter old) => false;
}

/// خط اخضر رفيع على قاع الصورة وقوسيها، يلمع في الوسط
class _HeaderRimPainter extends CustomPainter {
  final double radius;
  const _HeaderRimPainter({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width, h = size.height - 0.6;
    final path = Path()
      ..moveTo(0, h - radius)
      ..arcToPoint(
        Offset(radius, h),
        radius: Radius.circular(radius),
        clockwise: false,
      )
      ..lineTo(w - radius, h)
      ..arcToPoint(
        Offset(w, h - radius),
        radius: Radius.circular(radius),
        clockwise: false,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          colors: [
            kEmerald.withValues(alpha: 0.08),
            kEmerald.withValues(alpha: 0.6),
            kEmerald.withValues(alpha: 0.08),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _HeaderRimPainter old) => old.radius != radius;
}

// ── التذكرة ────────────────────────────────────────────────────

/// اي حافة من اللوح تلتقي بلوح آخر وتنقطع عندها فتحتان نصف دائريتين
enum TicketCut { none, top, bottom }

/// لوح اسود مخضر بحافة خضراء رفيعة. اذا التقى لوحان عند [TicketCut] صنعا معا تذكرة:
/// فتحتان نصف دائريتين على الجانبين وخط متقطع بينهما. [glint] خط ضوء قصير
/// على منتصف الحافة العليا.
class TicketPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final TicketCut cut;
  final bool glint;

  const TicketPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.cut = TicketCut.none,
    this.glint = false,
  });

  static const double radius = 24;
  static const double notch = 11;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TicketPainter(cut: cut, glint: glint),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _TicketPainter extends CustomPainter {
  final TicketCut cut;
  final bool glint;
  const _TicketPainter({required this.cut, required this.glint});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const r = TicketPanel.radius, n = TicketPanel.notch;
    final rect = Offset.zero & size;
    final l = rect.left, t = rect.top, rt = rect.right, b = rect.bottom;
    final top = cut == TicketCut.top, bottom = cut == TicketCut.bottom;

    void corner(Path p, Offset c, double rad, double from, double sweep) =>
        p.arcTo(Rect.fromCircle(center: c, radius: rad), from, sweep, false);

    // الحافة كاملة للتعبئة، ومفتوحة عند الالتقاء للرسم
    Path outline({required bool closed}) {
      final p = Path();
      final start = top ? Offset(l + n, t) : Offset(l + r, t);
      if (top) {
        p.moveTo(l + n, t);
        corner(p, Offset(l, t), n, 0, math.pi / 2);
      } else {
        p.moveTo(l + r, t);
        corner(p, Offset(l + r, t + r), r, -math.pi / 2, -math.pi / 2);
      }
      if (bottom) {
        p.lineTo(l, b - n);
        corner(p, Offset(l, b), n, -math.pi / 2, math.pi / 2);
      } else {
        p.lineTo(l, b - r);
        corner(p, Offset(l + r, b - r), r, math.pi, -math.pi / 2);
      }
      if (bottom) {
        if (closed) {
          p.lineTo(rt - n, b);
        } else {
          p.moveTo(rt - n, b);
        }
        corner(p, Offset(rt, b), n, math.pi, math.pi / 2);
      } else {
        p.lineTo(rt - r, b);
        corner(p, Offset(rt - r, b - r), r, math.pi / 2, -math.pi / 2);
      }
      if (top) {
        p.lineTo(rt, t + n);
        corner(p, Offset(rt, t), n, math.pi / 2, math.pi / 2);
      } else {
        p.lineTo(rt, t + r);
        corner(p, Offset(rt - r, t + r), r, 0, -math.pi / 2);
      }
      // المفتوح لا يُغلق: الخط من آخره الى اوله يمر على حافة الالتقاء
      if (closed) {
        p.close();
      } else if (!top) {
        p.lineTo(start.dx, start.dy);
      }
      return p;
    }

    canvas.drawPath(
      outline(closed: true),
      Paint()..color = kCoal.withValues(alpha: 0.94),
    );
    canvas.drawPath(
      outline(closed: false),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = kEmerald.withValues(alpha: 0.18),
    );

    // الخط المتقطع على حافة الالتقاء العليا
    if (top) {
      final dash = Paint()
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = kEmerald.withValues(alpha: 0.4);
      for (var x = l + n + 8; x < rt - n - 8; x += 11) {
        canvas.drawLine(
          Offset(x, t),
          Offset(math.min(x + 5, rt - n - 8), t),
          dash,
        );
      }
    }

    if (glint) {
      final from = Offset(size.width * 0.3, t + 0.5);
      final to = Offset(size.width * 0.7, t + 0.5);
      final band = Rect.fromPoints(
        from - const Offset(0, 3),
        to + const Offset(0, 3),
      );
      final shade = LinearGradient(
        colors: [
          kEmerald.withValues(alpha: 0),
          kEmeraldPale.withValues(alpha: 0.9),
          kEmerald.withValues(alpha: 0),
        ],
      ).createShader(band);
      canvas.drawLine(
        from,
        to,
        Paint()
          ..strokeWidth = 4
          ..shader = shade
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawLine(
        from,
        to,
        Paint()
          ..strokeWidth = 1.4
          ..shader = shade,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TicketPainter old) =>
      old.cut != cut || old.glint != glint;
}

// ── زر اللغة ───────────────────────────────────────────────────

/// كبسولة اللغة مثل gpt: الكرة الارضية ثم اسم اللغة الحالية ثم سهم صغير.
/// اللغتان فقط، فالضغط يقلب التطبيق كله بينهما.
class LangToggle extends StatelessWidget {
  const LangToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final en = AppPrefs.instance.isEn;
    return Semantics(
      button: true,
      label: en ? 'Language: English' : 'اللغة: العربية',
      child: GestureDetector(
        key: const ValueKey('lang-toggle'),
        onTap: AppPrefs.instance.toggleLang,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 40,
          padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 10, 0),
          decoration: BoxDecoration(
            color: kInk.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: kWhite.withValues(alpha: 0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language_rounded, size: 17, color: kEmerald),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  en ? 'English' : 'العربية',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bodyText(
                    kWhite,
                    13,
                    weight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 17,
                color: kWhiteFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── زر ايقونة في الرأس ─────────────────────────────────────────

/// زر ايقونة دائري: الدعم او قناة، بلا نص. الاسم لقارئ الشاشة وللتلميح
class IconLink extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const IconLink({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  State<IconLink> createState() => _IconLinkState();
}

class _IconLinkState extends State<IconLink> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: Tooltip(
        message: widget.label,
        child: GestureDetector(
          onTapDown: (_) => _set(true),
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            duration: _down ? Motion.fast : Motion.medium,
            curve: _down ? Motion.standard : Motion.overshoot,
            scale: _down ? 0.9 : 1,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kInk.withValues(alpha: 0.6),
                border: Border.all(color: kWhite.withValues(alpha: 0.14)),
              ),
              child: Icon(widget.icon, size: 21, color: widget.color),
            ),
          ),
        ),
      ),
    );
  }
}
