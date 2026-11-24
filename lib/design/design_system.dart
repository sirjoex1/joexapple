import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'motion.dart';
import 'prefs.dart';

export 'motion.dart';
export 'prefs.dart';
export 'backdrop.dart';
export 'video_backdrop.dart';

// ═══════════════════════════════════════════════════════════════
// JoeX PRO — اسود واخضر
// الاستهلال وصفحة الصفوف فوق صورة واحدة ببلور خفيف جدا (backdrop.dart)،
// وصفحة الدخول فوق فيديو ببلور خفيف وغلالة خضراء (video_backdrop.dart).
// الاسطح سوداء مخضرة بحواف خضراء رفيعة، والزمردي للفعل والتقدم، واليشم للحالي.
// الاحمر للخطأ وحده.
// الخطوط: El Messiri للعناوين، Readex Pro للنص، Cinzel للاسم والارقام.
// ═══════════════════════════════════════════════════════════════

// ── الصور: كل صورة لها مكان واحد تتبدل منه ─────────────────────
/// شعار JoeX PRO: الرجل بالقبعة والتفاحة والتاج، مقصوص على دائرة
const String kLogoAsset = 'assets/joex_pro_logo.png';

/// صورة رأس صفحتي الدخول والصفوف: الرجل بالقبعة في مكتب اخضر واسم JoeX
/// على اليمين. لو تعذر تحميلها يظهر مكانها سطح فحمي.
const String kHeaderAsset = 'assets/joex_lounge_banner.jpg';

/// خلفية الاستهلال وصفحة الصفوف، والبلور الخفيف جدا مطبوع فيها نفسها
const String kBackdropAsset = 'assets/app_background.jpg';

/// فيديو خلفية صفحة الدخول: 540x960 بلا صوت، والبلور الخفيف مطبوع فيه
/// نفسه فلا يحسبه الجهاز كل اطار
const String kVideoAsset = 'assets/script_bg.mp4';

/// اول اطار من الفيديو: يظهر حتى يجهز الفيديو، ومكانه اذا قلت الحركة
const String kVideoPosterAsset = 'assets/script_bg_poster.jpg';

// ── لون المنصة ─────────────────────────────────────────────────
// كل منصة تلوّن التطبيق كله بلونها كما في مشروع gpt: 1xBet ازرق #1e90ff،
// MelBet ذهبي #ffb800، Linebet اخضر #00a84e. الاسماء kEmerald وkJade بقيت
// كما هي لكنها الآن "لون الفعل" و"لون الحالي والوهج" للمنصة المختارة، والاسود
// مائل قليلا الى لونها. القيم تُقرأ عند كل بناء من [AppPrefs].
class _Palette {
  final Color ink, coal, coalMid, coalHi, coalLine;
  final Color jade, jadeBright, jadeDeep, jadeInk, mist;
  final Color emerald, emeraldPale, emeraldDeep, emeraldInk, onEmerald;
  const _Palette({
    required this.ink,
    required this.coal,
    required this.coalMid,
    required this.coalHi,
    required this.coalLine,
    required this.jade,
    required this.jadeBright,
    required this.jadeDeep,
    required this.jadeInk,
    required this.mist,
    required this.emerald,
    required this.emeraldPale,
    required this.emeraldDeep,
    required this.emeraldInk,
    required this.onEmerald,
  });
}

const _Palette _blue = _Palette(
  ink: Color(0xFF05070B),
  coal: Color(0xFF0A0F17),
  coalMid: Color(0xFF0F1520),
  coalHi: Color(0xFF161F2C),
  coalLine: Color(0xFF26344A),
  jade: Color(0xFF1C6FD6),
  jadeBright: Color(0xFF7DB9FF),
  jadeDeep: Color(0xFF0D3F80),
  jadeInk: Color(0xFF081A33),
  mist: Color(0xFF9EAEC4),
  emerald: Color(0xFF1E90FF),
  emeraldPale: Color(0xFFA6D0FF),
  emeraldDeep: Color(0xFF0B63C7),
  emeraldInk: Color(0xFF0A2C55),
  onEmerald: Color(0xFF020A16),
);

const _Palette _gold = _Palette(
  ink: Color(0xFF080705),
  coal: Color(0xFF120F08),
  coalMid: Color(0xFF19150C),
  coalHi: Color(0xFF231D11),
  coalLine: Color(0xFF3B3220),
  jade: Color(0xFFD49A00),
  jadeBright: Color(0xFFFFD766),
  jadeDeep: Color(0xFF7A5600),
  jadeInk: Color(0xFF261B00),
  mist: Color(0xFFBDB29A),
  emerald: Color(0xFFFFB800),
  emeraldPale: Color(0xFFFFE08F),
  emeraldDeep: Color(0xFFC98C00),
  emeraldInk: Color(0xFF3F2C00),
  onEmerald: Color(0xFF140D00),
);

const _Palette _green = _Palette(
  ink: Color(0xFF050807),
  coal: Color(0xFF0B110E),
  coalMid: Color(0xFF111914),
  coalHi: Color(0xFF18231C),
  coalLine: Color(0xFF26362C),
  jade: Color(0xFF0A8C47),
  jadeBright: Color(0xFF5FD995),
  jadeDeep: Color(0xFF07522A),
  jadeInk: Color(0xFF062314),
  mist: Color(0xFF9DB4A8),
  emerald: Color(0xFF00A84E),
  emeraldPale: Color(0xFF7FE0A8),
  emeraldDeep: Color(0xFF00733A),
  emeraldInk: Color(0xFF06321B),
  onEmerald: Color(0xFF00140A),
);

_Palette get _p => switch (AppPrefs.instance.platform) {
  Platform.oneXBet => _blue,
  Platform.melbet => _gold,
  Platform.linebet => _green,
};

/// لون المنصة نفسه كما في gpt
Color platformColor(Platform p) => switch (p) {
  Platform.oneXBet => _blue.emerald,
  Platform.melbet => _gold.emerald,
  Platform.linebet => _green.emerald,
};

// ── الاسود المائل للون المنصة: الخلفية والاسطح ──────────────────
Color get kInk => _p.ink;
Color get kCoal => _p.coal;
Color get kCoalMid => _p.coalMid;
Color get kCoalHi => _p.coalHi;
Color get kCoalLine => _p.coalLine;

// ── الحالي والوهج ──────────────────────────────────────────────
Color get kJade => _p.jade;
Color get kJadeBright => _p.jadeBright;
Color get kJadeDeep => _p.jadeDeep;
Color get kJadeInk => _p.jadeInk;

/// النص الثانوي: رمادي مائل للون المنصة
Color get kMist => _p.mist;

// ── الفعل والتقدم: لون المنصة ──────────────────────────────────
Color get kEmerald => _p.emerald;
Color get kEmeraldPale => _p.emeraldPale;
Color get kEmeraldDeep => _p.emeraldDeep;
Color get kEmeraldInk => _p.emeraldInk;

/// النص فوق لون المنصة
Color get kOnEmerald => _p.onEmerald;

// ── الابيض فوق الاسود ──────────────────────────────────────────
const Color kWhite = Color(0xFFFFFFFF);
const Color kWhiteSoft = Color(0xD1FFFFFF);
const Color kWhiteFaint = Color(0x8CFFFFFF);
const Color kWhiteLine = Color(0x1FFFFFFF);

// ── الخطأ ─────────────────────────────────────────────────────
const Color kRose = Color(0xFFF2545B);
const Color kRosePale = Color(0xFFFFC4C7);

List<Color> get kEmeraldGradient => [kEmeraldPale, kEmerald, kEmeraldDeep];
List<Color> get kJadeGradient => [kJadeBright, kJade, kJadeDeep];

// ═══════════════════════════════════════════════════════════════
// الخطوط
// ═══════════════════════════════════════════════════════════════

/// نص عربي عادي — Readex Pro
TextStyle bodyText(
  Color color,
  double size, {
  FontWeight weight = FontWeight.w400,
  double height = 1.5,
}) => GoogleFonts.readexPro(
  color: color,
  fontSize: size,
  fontWeight: weight,
  height: height,
);

/// عناوين عربية — El Messiri
TextStyle headText(
  Color color,
  double size, {
  FontWeight weight = FontWeight.w700,
  double height = 1.4,
}) => GoogleFonts.elMessiri(
  color: color,
  fontSize: size,
  fontWeight: weight,
  height: height,
);

/// الاسم والارقام — Cinzel، حروف ملكية
TextStyle markText(
  Color color,
  double size, {
  FontWeight weight = FontWeight.w700,
  double spacing = 0,
  double height = 1.15,
}) => GoogleFonts.cinzel(
  color: color,
  fontSize: size,
  fontWeight: weight,
  letterSpacing: spacing,
  height: height,
);

/// يجهّز الخطوط قبل اول اطار حتى لا يظهر خط بديل ولو للحظة
Future<void> preloadBrandFonts() async {
  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.readexPro(),
      GoogleFonts.readexPro(fontWeight: FontWeight.w500),
      GoogleFonts.readexPro(fontWeight: FontWeight.w600),
      GoogleFonts.readexPro(fontWeight: FontWeight.w700),
      GoogleFonts.elMessiri(fontWeight: FontWeight.w500),
      GoogleFonts.elMessiri(fontWeight: FontWeight.w600),
      GoogleFonts.elMessiri(fontWeight: FontWeight.w700),
      GoogleFonts.cinzel(fontWeight: FontWeight.w500),
      GoogleFonts.cinzel(fontWeight: FontWeight.w600),
      GoogleFonts.cinzel(fontWeight: FontWeight.w700),
      GoogleFonts.cinzel(fontWeight: FontWeight.w800),
    ]).timeout(const Duration(seconds: 2));
  } catch (_) {
    // الخط المتأخر لا يوقف فتح التطبيق
  }
}

// ═══════════════════════════════════════════════════════════════
// الشعار
// ═══════════════════════════════════════════════════════════════
class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Image.asset(
      kLogoAsset,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) =>
          Icon(Icons.diamond_rounded, color: kEmerald, size: size * 0.6),
    ),
  );
}

/// الشعار مع لمعة ذهبية تعبر سطحه: [sheen] من 0 الى 1، وخارجها لا تكلفة
class SheenLogo extends StatelessWidget {
  final double size;
  final double sheen;
  const SheenLogo({super.key, required this.size, this.sheen = 0});

  @override
  Widget build(BuildContext context) {
    final on = sheen > 0 && sheen < 1;
    return Stack(
      children: [
        BrandLogo(size: size),
        if (on)
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (rect) {
              final p = lerp(-0.2, 1.2, sheen);
              return LinearGradient(
                begin: const Alignment(-1, -0.45),
                end: const Alignment(1, 0.45),
                colors: [
                  kEmeraldPale.withValues(alpha: 0),
                  kEmeraldPale.withValues(alpha: 0.6),
                  kEmeraldPale.withValues(alpha: 0),
                ],
                stops: [
                  (p - 0.14).clamp(0.0, 1.0),
                  p.clamp(0.0, 1.0),
                  (p + 0.14).clamp(0.0, 1.0),
                ],
              ).createShader(rect);
            },
            child: BrandLogo(size: size),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// الورقة الصاعدة — مخمل بنفسجي بحافة ذهبية رفيعة في اعلاها
// ═══════════════════════════════════════════════════════════════
class RisingSheet extends StatelessWidget {
  final Widget child;
  const RisingSheet({super.key, required this.child});

  static const double radius = 32;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(radius),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kCoalMid, kCoal],
          ),
          boxShadow: [
            BoxShadow(
              color: kJade.withValues(alpha: 0.28),
              blurRadius: 40,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: CustomPaint(
            foregroundPainter: const _RimPainter(),
            child: SafeArea(
              top: false,
              child: Directionality(
                textDirection: appDir,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 30, 22, 20),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// خيط ذهب على القوس العلوي، يلمع في وسطه ويذوب نحو الطرفين، ومقبض صغير
class _RimPainter extends CustomPainter {
  const _RimPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const r = RisingSheet.radius;
    final w = size.width;
    final edge = Path()
      ..moveTo(0.5, r)
      ..arcToPoint(const Offset(r, 0.5), radius: const Radius.circular(r))
      ..lineTo(w - r, 0.5)
      ..arcToPoint(Offset(w - 0.5, r), radius: const Radius.circular(r));
    canvas.drawPath(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          colors: [
            kEmerald.withValues(alpha: 0.05),
            kEmerald.withValues(alpha: 0.85),
            kEmerald.withValues(alpha: 0.05),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, r)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w / 2, 12), width: 40, height: 4),
        const Radius.circular(2),
      ),
      Paint()..color = kWhite.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant _RimPainter old) => false;
}

/// يفتح [RisingSheet] صاعدا من القاع بينما تعتم الشاشة خلفه
Future<T?> showRisingSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required String label,
  bool dismissible = false,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: label,
    barrierColor: kInk.withValues(alpha: 0.7),
    transitionDuration: const Duration(milliseconds: 460),
    pageBuilder: (c, _, _) => builder(c),
    transitionBuilder: (c, a1, _, child) {
      final curve = CurvedAnimation(
        parent: a1,
        curve: Motion.emphasized,
        reverseCurve: Motion.accelerate,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      );
    },
  );
}

// ═══════════════════════════════════════════════════════════════
// الزر الرئيسي — سبيكة ذهب تنكمش الى دائرة اثناء التحميل
// ═══════════════════════════════════════════════════════════════
class PillButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;

  /// تمر عليه لمعة عندما يصبح جاهزا
  final bool attention;

  const PillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.height = 56,
    this.attention = false,
  });

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  void didUpdateWidget(covariant PillButton old) {
    super.didUpdateWidget(old);
    if (!old.attention && widget.attention && motionAllowed(context)) {
      _shine.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.onPressed != null && !widget.loading;
    final h = widget.height;
    final idle = !on && !widget.loading;

    return Semantics(
      button: true,
      enabled: on,
      child: GestureDetector(
        onTapDown: on ? (_) => _set(true) : null,
        onTapUp: on ? (_) => _set(false) : null,
        onTapCancel: () => _set(false),
        onTap: on ? widget.onPressed : null,
        child: AnimatedScale(
          duration: _down ? Motion.fast : Motion.medium,
          curve: _down ? Motion.standard : Motion.overshoot,
          scale: _down ? 0.965 : 1,
          child: LayoutBuilder(
            builder: (context, box) {
              final full = box.maxWidth.isFinite ? box.maxWidth : 260.0;
              return Center(
                heightFactor: 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 380),
                  curve: Motion.emphasized,
                  width: widget.loading ? h : full,
                  height: h,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: idle ? kCoalHi : null,
                    gradient: idle
                        ? null
                        : LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: _down
                                ? [kEmerald, kEmeraldDeep]
                                : kEmeraldGradient,
                          ),
                    borderRadius: BorderRadius.circular(h / 2),
                    border: Border.all(
                      color: idle
                          ? kWhiteLine
                          : kEmeraldPale.withValues(alpha: 0.7),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kEmerald.withValues(
                          alpha: idle ? 0 : (_down ? 0.16 : 0.34),
                        ),
                        blurRadius: _down ? 10 : 22,
                        offset: Offset(0, _down ? 3 : 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedOpacity(
                        duration: Motion.fast,
                        opacity: widget.loading ? 0 : 1,
                        // عرض ثابت: النص لا يعاد ترتيبه والسبيكة تنكمش حوله
                        child: OverflowBox(
                          minWidth: math.max(full - 44, 0),
                          maxWidth: math.max(full - 44, 0),
                          child: _label(on),
                        ),
                      ),
                      if (widget.loading)
                        SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              kOnEmerald,
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _shine,
                            builder: (context, _) {
                              final v = _shine.value;
                              if (v <= 0 || v >= 1) {
                                return const SizedBox.shrink();
                              }
                              return FractionalTranslation(
                                translation: Offset(
                                  lerp(1.1, -1.1, Motion.standard.transform(v)),
                                  0,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        kWhite.withValues(alpha: 0),
                                        kWhite.withValues(alpha: 0.5),
                                        kWhite.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _label(bool on) {
    final color = on || widget.loading ? kOnEmerald : kWhiteFaint;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: headText(color, 16, height: 1.3),
          ),
        ),
        if (widget.icon != null) ...[
          const SizedBox(width: 10),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? kOnEmerald.withValues(alpha: 0.12) : kWhiteLine,
            ),
            child: Icon(widget.icon, size: 17, color: color),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// سطر الخطأ — شريحة وردية بايقونة، تدخل منزلقة
// ═══════════════════════════════════════════════════════════════
class FaultLine extends StatelessWidget {
  final String message;
  const FaultLine(this.message, {super.key});

  @override
  Widget build(BuildContext context) => StaggerIn(
    key: ValueKey(message),
    dy: 8,
    duration: const Duration(milliseconds: 380),
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: kRose.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kRose.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_rounded, size: 16, color: kRose),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: bodyText(
                    kRosePale,
                    12.5,
                    weight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
