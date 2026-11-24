import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design_system.dart';

// ═══════════════════════════════════════════════════════════════
// الخلفية — صورة واحدة لكل الصفحات ([kBackdropAsset]): الرجل والتفاحة في
// ضوء اخضر، والبلور الخفيف جدا مطبوع في الصورة نفسها فلا يحسبه الجهاز.
// فوقها عتمة خفيفة واطار يغمق الحواف واعلى الشاشة وقاعها حتى يبقى ما
// فوقها مقروءا. الصورة بطول الشاشة كله دائما: اذا تقلصت الصفحة مع
// الكيبورد لا يتحرك قصها.
// ═══════════════════════════════════════════════════════════════
class Backdrop extends StatelessWidget {
  const Backdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final h = box.hasBoundedHeight
              ? math.max(box.maxHeight, screen.height)
              : screen.height;
          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: h,
              maxHeight: h,
              child: RepaintBoundary(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: kInk),
                    Image.asset(
                      kBackdropAsset,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                    const CustomPaint(painter: _VeilPainter()),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// عتمة خفيفة على الصورة كلها، واطار يغمق الحواف واعلى الشاشة وقاعها
class _VeilPainter extends CustomPainter {
  const _VeilPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = kInk.withValues(alpha: 0.2));
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 1.05,
          colors: [
            kInk.withValues(alpha: 0),
            kInk.withValues(alpha: 0.18),
            kInk.withValues(alpha: 0.6),
          ],
          stops: const [0.5, 0.78, 1],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            kInk.withValues(alpha: 0.5),
            kInk.withValues(alpha: 0),
            kInk.withValues(alpha: 0),
            kInk.withValues(alpha: 0.55),
          ],
          stops: const [0, 0.16, 0.72, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _VeilPainter old) => false;
}
