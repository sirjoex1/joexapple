import 'dart:math' as math;

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// الحركة — لغة واحدة لكل الشاشات
// ما يدخل يتباطأ حتى يستقر، وما يخرج يتسارع حتى يختفي، والعناصر
// تدخل واحدا بعد الآخر. لا شيء يظهر فجأة ولا شيء يقفز.
// ═══════════════════════════════════════════════════════════════
class Motion {
  Motion._();

  /// الدخول: سريع في اوله ويهدأ طويلا قبل ان يستقر
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);

  /// الخروج: يبدأ ببطء ويغادر مسرعا
  static const Curve accelerate = Cubic(0.5, 0, 0.9, 0.3);

  /// انتقال بين حالتين داخل نفس المكان
  static const Curve standard = Cubic(0.4, 0, 0.2, 1);

  /// تجاوز خفيف ثم استقرار، للعناصر الصغيرة فقط
  static const Curve overshoot = Cubic(0.34, 1.45, 0.64, 1);

  /// فتحة الانتقال: تتجمع ثم تنطلق ثم تهدأ
  static const Curve iris = Cubic(0.6, 0, 0.16, 1);

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 520);

  /// تبديل نص في مكانه: اقصر من زمن قراءته
  static const Duration swap = Duration(milliseconds: 260);
}

/// لمعاينة الحركة داخل الاختبارات فقط
bool debugForceMotion = false;

bool get isWidgetTest =>
    WidgetsBinding.instance.runtimeType.toString().contains('Test');

/// يحترم خيار تقليل الحركة في النظام، ويوقف الحركة المتكررة في الاختبارات
bool motionAllowed(BuildContext context) =>
    (debugForceMotion || !isWidgetTest) &&
    !MediaQuery.disableAnimationsOf(context);

/// موضع [t] داخل مقطع زمني من الخط الزمني للشاشة، بعد المنحنى
double phase(
  double t,
  double begin,
  double end, [
  Curve curve = Curves.linear,
]) => curve.transform(((t - begin) / (end - begin)).clamp(0.0, 1.0));

double lerp(double a, double b, double t) => a + (b - a) * t;

// ═══════════════════════════════════════════════════════════════
// الدخول على خط زمني مشترك
// الغلاف ثابت دائما حتى لا يفقد ما بداخله حالته (كالحقل والكيبورد).
// ═══════════════════════════════════════════════════════════════
class Entrance extends StatelessWidget {
  final Animation<double> parent;
  final double begin;
  final double end;
  final double dy;
  final Widget child;

  const Entrance({
    super.key,
    required this.parent,
    required this.begin,
    required this.end,
    required this.child,
    this.dy = 16,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: parent,
    child: child,
    builder: (context, c) {
      final v = phase(parent.value, begin, end, Motion.emphasized);
      return Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, dy * (1 - v)), child: c),
      );
    },
  );
}

/// نص يصعد من خلف حافة مقصوصة
class MaskedRise extends StatelessWidget {
  final Animation<double> parent;
  final double begin;
  final double end;
  final Widget child;

  const MaskedRise({
    super.key,
    required this.parent,
    required this.begin,
    required this.end,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedBuilder(
      animation: parent,
      child: child,
      builder: (context, c) {
        final v = phase(parent.value, begin, end, Motion.emphasized);
        return FractionalTranslation(translation: Offset(0, 1 - v), child: c);
      },
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
// عناصر تدخل واحدا بعد الآخر عند ظهورها
// ═══════════════════════════════════════════════════════════════
class StaggerIn extends StatefulWidget {
  final List<Widget> children;
  final double dy;
  final Duration duration;

  const StaggerIn({
    super.key,
    required this.children,
    this.dy = 14,
    this.duration = const Duration(milliseconds: 640),
  });

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (motionAllowed(context)) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.children.length;
    final step = n > 1 ? math.min(0.14, 0.5 / (n - 1)) : 0.0;
    final span = 1 - step * (n - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < n; i++)
          Entrance(
            parent: _c,
            begin: i * step,
            end: i * step + span,
            dy: widget.dy,
            child: widget.children[i],
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// اهتزاز الرفض — يعيد نفسه كلما تغير [trigger]
// ═══════════════════════════════════════════════════════════════
class Shake extends StatefulWidget {
  final int trigger;
  final Widget child;
  const Shake({super.key, required this.trigger, required this.child});

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(covariant Shake old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && motionAllowed(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, c) {
      final v = _c.value;
      final dx = math.sin(v * math.pi * 5) * (1 - v) * 7;
      return Transform.translate(offset: Offset(dx, 0), child: c);
    },
  );
}

// ═══════════════════════════════════════════════════════════════
// عدّاد تتدحرج خاناته صعودا عند التغير
// ═══════════════════════════════════════════════════════════════
class RollingDigits extends StatelessWidget {
  final String value;
  final TextStyle style;

  const RollingDigits({super.key, required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 20;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < value.length; i++)
            ClipRect(
              child: SizedBox(
                width: size * 0.92,
                height: size * 1.3,
                child: AnimatedSwitcher(
                  duration: Motion.medium,
                  switchInCurve: Motion.emphasized,
                  switchOutCurve: Motion.emphasized,
                  transitionBuilder: (child, a) {
                    final incoming = child.key == ValueKey(value[i]);
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0, incoming ? 1 : -1),
                        end: Offset.zero,
                      ).animate(a),
                      child: child,
                    );
                  },
                  child: Center(
                    key: ValueKey(value[i]),
                    child: Text(value[i], style: style),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// انتقال موحّد للنص الذي يتبدل في مكانه: القديم يصعد ويختفي ثم يأتي الجديد
/// من تحته. المنحنى داخله، فالمبدّل يبقى على منحناه الخطي الافتراضي.
Widget slideSwapTransition(Widget child, Animation<double> a) =>
    _SwapSlide(animation: a, child: child);

class _SwapSlide extends AnimatedWidget {
  final Widget child;

  const _SwapSlide({required Animation<double> animation, required this.child})
    : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final a = listenable as Animation<double>;
    // القديم يغادر في النصف الاول، والجديد لا يبدأ الا بعد ان يبتعد
    final leaving = a.status == AnimationStatus.reverse;
    final t = leaving
        ? phase(1 - a.value, 0, 0.5, Motion.accelerate)
        : phase(a.value, 0.42, 1, Motion.emphasized);
    return Opacity(
      opacity: (leaving ? 1 - t : t).clamp(0.0, 1.0),
      child: FractionalTranslation(
        translation: Offset(0, leaving ? -t : 1 - t),
        child: child,
      ),
    );
  }
}

/// تخطيط يبقي النص القديم والجديد على بداية السطر اثناء التبدل
Widget startAlignedSwitcherLayout(Widget? current, List<Widget> previous) {
  return Stack(
    alignment: AlignmentDirectional.centerStart,
    children: [...previous, ?current],
  );
}
