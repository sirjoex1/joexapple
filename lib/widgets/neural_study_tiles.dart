import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../design/design_system.dart';

/// مؤشر تحليلي عصبي ذكي
class StudyMetricItem {
  final String titleAr;
  final String titleEn;
  final String Function(int row) valueBuilder;
  final IconData icon;
  final bool isPositive;

  const StudyMetricItem({
    required this.titleAr,
    required this.titleEn,
    required this.valueBuilder,
    required this.icon,
    this.isPositive = true,
  });
}

/// شبكة المؤشرات التحليلية الثمانية بتصميم زجاجي (Glassmorphism)
/// وانيميشن مسح ضوئي نيون متقدم عند قراءة الخانة
class NeuralStudyTiles extends StatelessWidget {
  final int activeRow;
  final int activeTileStep; // -1: none / ready, 0..7: currently scanning step, 8: all done
  final bool isBusy;
  final Color? themeColor;

  const NeuralStudyTiles({
    super.key,
    required this.activeRow,
    required this.activeTileStep,
    required this.isBusy,
    this.themeColor,
  });

  static final List<StudyMetricItem> metrics = [
    StudyMetricItem(
      titleAr: 'مصفوفة الأنماط',
      titleEn: 'Pattern Matrix',
      valueBuilder: (r) => '${(97.4 + ((r * 3) % 5) * 0.4).toStringAsFixed(1)}%',
      icon: Icons.insights_rounded,
    ),
    StudyMetricItem(
      titleAr: 'المسار العصبي',
      titleEn: 'Neural Pathway',
      valueBuilder: (r) => tr('نشط · 0.9${(r % 4) + 6}', 'Active · 0.9${(r % 4) + 6}'),
      icon: Icons.timeline_rounded,
    ),
    StudyMetricItem(
      titleAr: 'التوزيع الاحتمالي',
      titleEn: 'Probability Spread',
      valueBuilder: (r) => '0.9${(r % 3) + 7} P',
      icon: Icons.bolt_rounded,
    ),
    StudyMetricItem(
      titleAr: 'مؤشر الكثافة',
      titleEn: 'Density Index',
      valueBuilder: (r) => tr('مستقر · ${40 + (r % 7)}', 'Stable · ${40 + (r % 7)}'),
      icon: Icons.radar_rounded,
    ),
    StudyMetricItem(
      titleAr: 'معامل التوافق',
      titleEn: 'Sync Ratio',
      valueBuilder: (r) => '±0.0${(r % 4) + 2}',
      icon: Icons.tune_rounded,
    ),
    StudyMetricItem(
      titleAr: 'مستويات الأمان',
      titleEn: 'Safety Level',
      valueBuilder: (r) => 'Tier A+',
      icon: Icons.security_rounded,
    ),
    StudyMetricItem(
      titleAr: 'زمن الاستجابة',
      titleEn: 'Response Time',
      valueBuilder: (r) => '${11 + (r % 5)}ms',
      icon: Icons.speed_rounded,
    ),
    StudyMetricItem(
      titleAr: 'نسبة التأكيد',
      titleEn: 'Validation Rate',
      valueBuilder: (r) => '${(98.2 + ((r * 2) % 4) * 0.3).toStringAsFixed(1)}%',
      icon: Icons.verified_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tc = themeColor ?? kEmerald;
    final completedCount = isBusy
        ? (activeTileStep >= 0 ? math.min(8, activeTileStep + 1) : 0)
        : 8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // شريط العنوان العلوي وعداد المؤشرات
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isBusy ? const Color(0xFF00D2FF) : tc,
                  boxShadow: [
                    BoxShadow(
                      color: (isBusy ? const Color(0xFF00D2FF) : tc).withValues(alpha: 0.8),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('الفحوصات التحليلية للمصفوفة', 'Neural Analytical Matrix'),
                  style: bodyText(kWhite, 12.5, weight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: (isBusy ? const Color(0xFF00D2FF) : tc).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: (isBusy ? const Color(0xFF00D2FF) : tc).withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  tr('$completedCount من 8 نشط', '$completedCount of 8 Active'),
                  style: markText(
                    isBusy ? const Color(0xFF00D2FF) : tc,
                    10.2,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // شبكة 2x4 للبطاقات الزجاجية
        LayoutBuilder(
          builder: (context, constraints) {
            final colWidth = (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < metrics.length; i++)
                  SizedBox(
                    width: colWidth,
                    child: _buildTile(
                      index: i,
                      metric: metrics[i],
                      isScanned: isBusy ? (i <= activeTileStep) : true,
                      isScanningNow: isBusy && (i == activeTileStep),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTile({
    required int index,
    required StudyMetricItem metric,
    required bool isScanned,
    required bool isScanningNow,
  }) {
    final title = tr(metric.titleAr, metric.titleEn);
    final value = metric.valueBuilder(activeRow);
    final isGlowing = isScanningNow;

    final accent = isScanningNow
        ? const Color(0xFF00D2FF)
        : (isScanned ? const Color(0xFF34D399) : kMist);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      height: 60,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF070D1E).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGlowing
              ? const Color(0xFF00D2FF).withValues(alpha: 0.85)
              : (isScanned
                  ? const Color(0xFF34D399).withValues(alpha: 0.28)
                  : kWhite.withValues(alpha: 0.08)),
          width: isGlowing ? 1.4 : 0.9,
        ),
        boxShadow: [
          if (isGlowing) ...[
            BoxShadow(
              color: const Color(0xFF00D2FF).withValues(alpha: 0.38),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ] else if (isScanned) ...[
            BoxShadow(
              color: const Color(0xFF34D399).withValues(alpha: 0.08),
              blurRadius: 8,
            ),
          ],
        ],
      ),
      child: Stack(
        children: [
          // خلفية الرسم البياني المصغر (Sparkline Graph)
          if (isScanned)
            Positioned(
              right: 0,
              bottom: 0,
              width: 65,
              height: 38,
              child: Opacity(
                opacity: isGlowing ? 0.95 : 0.45,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    color: isGlowing ? const Color(0xFF00D2FF) : const Color(0xFF34D399),
                    seed: index * 19 + activeRow * 7,
                  ),
                ),
              ),
            ),

          // المحتوى
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            child: Row(
              children: [
                // مربع الأيقونة المتوهج
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isGlowing ? 0.28 : 0.12),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: accent.withValues(alpha: isGlowing ? 0.75 : 0.25),
                      width: 0.8,
                    ),
                    boxShadow: [
                      if (isGlowing)
                        BoxShadow(
                          color: accent.withValues(alpha: 0.6),
                          blurRadius: 10,
                        ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      metric.icon,
                      size: 16,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // النصوص (العنوان والقيمة)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: bodyText(
                          isScanned ? kMist : kMist.withValues(alpha: 0.6),
                          10.5,
                          weight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 1),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          isScanningNow
                              ? '• • •'
                              : (isScanned ? value : '—'),
                          key: ValueKey('$value-$isScanningNow-$isScanned'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: markText(
                            isScanningNow
                                ? const Color(0xFF00D2FF)
                                : (isScanned ? const Color(0xFF34D399) : kMist),
                            12.0,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // شارة صح خفيفة عند اكتمال الفحص
                if (isScanned && !isScanningNow)
                  const Padding(
                    padding: EdgeInsetsDirectional.only(start: 2),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color: Color(0xFF34D399),
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

/// رسم منحنى الـ Sparkline البياني في زاوية كل بطاقة
class _SparklinePainter extends CustomPainter {
  final Color color;
  final int seed;

  const _SparklinePainter({required this.color, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path();
    final fillPath = Path();

    final points = <Offset>[];
    const n = 6;
    for (var i = 0; i < n; i++) {
      final x = (i / (n - 1)) * w;
      final wave = math.sin((i + seed) * 1.3) * 0.45;
      final y = h * 0.45 + wave * (h * 0.35);
      points.add(Offset(x, y.clamp(4.0, h - 3.0)));
    }

    path.moveTo(points.first.dx, points.first.dy);
    fillPath.moveTo(0, h);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (var i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final cx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(w, h);
    fillPath.close();

    // Fill gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.25),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, fillPaint);

    // Stroke
    final strokePaint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.color != color || old.seed != seed;
}
