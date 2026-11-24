import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/design_system.dart';
import '../design/identity.dart';
import '../services/links.dart';
import '../widgets/neural_study_tiles.dart';
import 'ai_diagnostic_screen.dart';

// ─────────────────────────────────────────────────────────────
// صفحة السكريبت — صفحة الاختيار من مشروع gpt، الصفحة وحدها
// فوق: نفس رأس صفحة الدخول (الدعم وقناتانا ايقونات، واللغة).
// ثم كارت الصف كما في gpt: دائرة بلون الحالة تتنفس ويدور عليها لمعان،
// وكلمة الحالة، وخانات الصف الخمس بقلب ينبض ولمعة تمر عليها. عند الاختيار
// يُرسم خط نور من الدائرة الى الخانة، ووميض، وثلاث حلقات تتسع، وشرارات،
// ونقطة على رأس الخانة. الخاطئة تهز الكارت.
// ثم عشرة اشرطة للصفوف، وزر «اختر خانة» يمتلئ والضوء يجري على الخانات ويقف
// على خانة عشوائية، ثم «هل كانت صحيحة؟».
// الاختيار عشوائي والصفحة تقول ذلك. لا «فحوصات تحليلية» ولا اسماء نماذج، ولا
// تبويبات حسابي وتعلّم والسجل.
// ─────────────────────────────────────────────────────────────

const int _kRows = 10;
const int _kCells = 5;

/// زمن الاختيار كله: الزر يمتلئ خلاله
const int _kPickMs = 2400;

/// زمن مؤثرات الكارت كلها
const int _kFxMs = 2000;

const Color _okC = Color(0xFF2FBF5A);
const Color _okC2 = Color(0xFF1C7F3B);
const Color _badC = Color(0xFFEF4444);
const Color _badC2 = Color(0xFF991B1B);

/// صف أُجيب عنه: رقمه والخانة وهل كانت صحيحة
typedef _Done = ({int row, int cell, bool ok});

/// حالة الكارت
enum _Look { ready, busy, pick, ok, won, lost }

enum _FxKind { pick, ok, bad }

/// مؤثر واحد على الكارت: من الدائرة الى الخانة، بمقاسات الكارت
class _Fx {
  final _FxKind kind;
  final Offset from;
  final Offset to;
  final double cellTop;
  final Size card;
  final Color color;
  final List<Offset> sparks;
  const _Fx({
    required this.kind,
    required this.from,
    required this.to,
    required this.cellTop,
    required this.card,
    required this.color,
    required this.sparks,
  });
}

class JoeXApplePage extends StatefulWidget {
  final VoidCallback? onLogout;
  const JoeXApplePage({super.key, this.onLogout});

  @override
  State<JoeXApplePage> createState() => _JoeXApplePageState();
}

class _JoeXApplePageState extends State<JoeXApplePage>
    with TickerProviderStateMixin {
  static const String _key = 'pick_state';

  /// الدائرة: تنفس كل 4.5 ثانية ولمعان يدور كل 7 ثوان (31.5 تجمعهما)
  late final AnimationController _orbLoop;

  /// الخانات: قلب ينبض كل 2.4 ولمعة كل 3.6 ووهج المختارة كل 1.8 (7.2 تجمعها)
  late final AnimationController _idle;

  /// مؤثرات الاختيار والاجابة
  late final AnimationController _fx;

  final GlobalKey _cardKey = GlobalKey();
  final GlobalKey _orbKey = GlobalKey();
  final List<GlobalKey> _cellKeys = List.generate(_kCells, (_) => GlobalKey());

  final math.Random _rand = math.Random.secure();

  int _round = 1;
  int _row = 1;

  /// خانة هذا الصف المختارة (0..4)، و-1 قبل الاختيار
  int _cell = -1;

  /// '' اثناء اللعب، 'won' بعد الصفوف العشرة، 'lost' بعد خاطئة
  String _end = '';
  final List<_Done> _done = [];

  /// الصحيحة تبقى على صفها لحظة قبل ان يظهر الصف التالي
  _Done? _show;

  bool _busy = false;
  int _scan = -1;
  double _fill = 1;
  int _req = 0;
  int _shake = 0;
  int _pop = 0;
  _Fx? _fxNow;
  int _aiTierIndex = 1;
  String _aiTierName = 'Quantum Tier II';
  int _tileStep = -1;

  Color get _tierColor => switch (_aiTierIndex) {
    0 => const Color(0xFF1E90FF),
    1 => const Color(0xFF00D2FF),
    2 => const Color(0xFFFFB800),
    3 => const Color(0xFFFFD700),
    _ => kEmerald,
  };

  String get _tierEmblem => switch (_aiTierIndex) {
    0 => 'assets/emblem_1.png',
    1 => 'assets/emblem_2.png',
    2 => 'assets/emblem_3.png',
    3 => 'assets/emblem_4.png',
    _ => 'assets/emblem_2.png',
  };

  String get _tierSpec => switch (_aiTierIndex) {
    0 => tr(
      '4 فحوصات · أفضل 3 · استجابة قياسية',
      '4 Checks · Top 3 · Standard Speed',
    ),
    1 => tr(
      '6 فحوصات · تفصيل متقدم · مزامنة فورية',
      '6 Checks · Detailed analysis · Instant sync',
    ),
    2 => tr(
      '8 فحوصات · تفصيل · مرشح السوق',
      '8 Checks · Breakdown · Market Filter',
    ),
    3 => tr(
      'أقصى فحص متعدد النوى · أولوية معالجة',
      'Full Multi-Core Scan · Dedicated Priority',
    ),
    _ => tr(
      '8 فحوصات · تفصيل · مرشح السوق',
      '8 Checks · Breakdown · Market Filter',
    ),
  };

  @override
  void initState() {
    super.initState();
    _orbLoop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 31500),
    );
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7200),
    );
    _fx = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kFxMs),
    );
    _load();
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (motionAllowed(context)) {
      _orbLoop.repeat();
      _idle.repeat();
    }
  }

  @override
  void dispose() {
    _req++;
    _orbLoop.dispose();
    _idle.dispose();
    _fx.dispose();
    super.dispose();
  }

  // ── محفوظ على الموبايل ─────────────────────────────────────────
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || !mounted) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final done = <_Done>[];
      for (final e in (m['done'] as List? ?? const [])) {
        final d = e as Map<String, dynamic>;
        final row = (d['row'] as num?)?.toInt() ?? 0;
        final cell = (d['cell'] as num?)?.toInt() ?? -1;
        if (row < 1 || row > _kRows || cell < 0 || cell >= _kCells) continue;
        done.add((row: row, cell: cell, ok: d['ok'] == true));
      }
      final cell = (m['cell'] as num?)?.toInt() ?? -1;
      final end = m['end'] == 'won' || m['end'] == 'lost'
          ? m['end'] as String
          : '';
      final aiTier = prefs.getString('ai_tier_name') ?? 'Quantum Tier II';
      final aiIdx = prefs.getInt('ai_tier_index') ?? 1;
      setState(() {
        _aiTierIndex = aiIdx;
        _aiTierName = aiTier;
        _round = math.max(1, (m['round'] as num?)?.toInt() ?? 1);
        _row = ((m['row'] as num?)?.toInt() ?? 1).clamp(1, _kRows);
        _cell = cell >= 0 && cell < _kCells ? cell : -1;
        _end = end;
        _done
          ..clear()
          ..addAll(done.take(_kRows));
      });
    } catch (_) {
      // يبدأ من جديد
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'round': _round,
          'row': _row,
          'cell': _cell,
          'end': _end,
          'done': [
            for (final d in _done) {'row': d.row, 'cell': d.cell, 'ok': d.ok},
          ],
        }),
      );
    } catch (_) {}
  }

  // ── المؤثرات: بعد رسم الاطار تُقاس الدائرة والخانة ثم يبدأ المؤثر ──
  void _fire(_FxKind kind, int cell) {
    if (!motionAllowed(context)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final card = _cardKey.currentContext?.findRenderObject() as RenderBox?;
      final orb = _orbKey.currentContext?.findRenderObject() as RenderBox?;
      final box =
          _cellKeys[cell].currentContext?.findRenderObject() as RenderBox?;
      if (card == null || orb == null || box == null) return;
      Offset local(RenderBox b, Offset p) =>
          card.globalToLocal(b.localToGlobal(p));
      final from = local(orb, orb.size.center(Offset.zero));
      final to = local(box, box.size.center(Offset.zero));
      final top = local(box, Offset(box.size.width / 2, 0)).dy;
      final color = switch (kind) {
        _FxKind.ok => const Color(0xFF34D399),
        _FxKind.bad => const Color(0xFFF87171),
        _FxKind.pick => kEmeraldPale,
      };
      final sparks = [
        for (var k = 0; k < 14; k++)
          () {
            final a = (k / 14) * math.pi * 2 + _rand.nextDouble() * 0.4;
            final r = 34 + _rand.nextDouble() * 46;
            return Offset(math.cos(a) * r, math.sin(a) * r);
          }(),
      ];
      setState(() {
        _fxNow = _Fx(
          kind: kind,
          from: from,
          to: to,
          cellTop: top,
          card: card.size,
          color: color,
          sparks: sparks,
        );
      });
      _fx.forward(from: 0);
    });
  }

  void _clearFx() {
    _fx.stop();
    _fxNow = null;
  }

  // ── اختيار: الزر يمتلئ والضوء يجري على الصف ويقف على خانة عشوائية ──
  Future<void> _pick() async {
    if (_busy) return;
    if (_end.isNotEmpty) {
      _round++;
      _row = 1;
      _cell = -1;
      _done.clear();
      _end = '';
    }
    final my = ++_req;
    final chosen = _rand.nextInt(_kCells);
    setState(() {
      _show = null;
      _busy = true;
      _fill = 0;
      _scan = -1;
      _clearFx();
    });

    // محطات الضوء: سريعة اولا ثم تبطئ، وآخرها الخانة المختارة
    final stops = <int>[];
    for (var k = 0, i = 0; k < 13; k++, i = (i + 1) % _kCells) {
      stops.add(i);
    }
    while (stops.last != chosen) {
      stops.add((stops.last + 1) % _kCells);
    }
    final clock = Stopwatch()..start();
    for (var k = 0; k < stops.length; k++) {
      if (!mounted || my != _req) return;
      final elapsed = clock.elapsedMilliseconds;
      final expectedStep = math.min(7, (elapsed / _kPickMs * 8).floor());
      setState(() {
        _scan = stops[k];
        _fill = math.min(1, elapsed / _kPickMs);
        _tileStep = expectedStep;
      });
      final left = stops.length - k;
      await Future<void>.delayed(
        Duration(milliseconds: left > 6 ? 90 : 90 + (7 - left) * 55),
      );
    }
    final rest = _kPickMs - clock.elapsedMilliseconds;
    if (rest > 0) {
      if (!mounted || my != _req) return;
      setState(() => _fill = 1);
      await Future<void>.delayed(Duration(milliseconds: math.min(rest, 400)));
    }
    if (!mounted || my != _req) return;
    setState(() {
      _busy = false;
      _scan = -1;
      _fill = 1;
      _cell = chosen;
      _tileStep = 7;
      _pop++;
    });
    _save();
    _fire(_FxKind.pick, chosen);
  }

  void _answer(bool ok) {
    if (_cell < 0 || _end.isNotEmpty) return;
    final d = (row: _row, cell: _cell, ok: ok);
    setState(() {
      _clearFx();
      _done.add(d);
      _cell = -1;
      _pop++;
      if (!ok) {
        _end = 'lost';
        _shake++;
      } else if (_row >= _kRows) {
        _end = 'won';
      } else {
        _row++;
        _show = d;
      }
    });
    _save();
    _fire(ok ? _FxKind.ok : _FxKind.bad, d.cell);
    if (_show == d) {
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _show == d) {
          setState(() {
            _show = null;
            _clearFx();
          });
        }
      });
    }
  }

  _Look get _look {
    if (_end == 'won') return _Look.won;
    if (_end == 'lost') return _Look.lost;
    if (_busy) return _Look.busy;
    if (_cell >= 0) return _Look.pick;
    if (_show != null) return _Look.ok;
    return _Look.ready;
  }

  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final side = size.width < 360 ? 14.0 : 18.0;
    final content = math.min(size.width - side * 2, 460.0);
    final asking = _cell >= 0 && _end.isEmpty && !_busy;

    return Scaffold(
      key: const ValueKey('script-page'),
      backgroundColor: Colors.black,
      body: Directionality(
        textDirection: appDir,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(media, content),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  0,
                  16,
                  0,
                  18 + media.padding.bottom,
                ),
                child: Center(
                  child: SizedBox(
                    width: content,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _aiEngineBar(),
                        Shake(trigger: _shake, child: _card()),
                        const SizedBox(height: 14),
                        _progress(),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: Motion.medium,
                          transitionBuilder: (child, a) =>
                              FadeTransition(opacity: a, child: child),
                          child: asking ? _ask() : _button(),
                        ),
                        const SizedBox(height: 18),
                        NeuralStudyTiles(
                          activeRow: _row,
                          activeTileStep: _tileStep,
                          isBusy: _busy,
                          themeColor: _tierColor,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// كارت المستوى المقتبس طبق الأصل من كارت gpt (#pro-tierbar.metal)
  Widget _aiEngineBar() {
    final tc = _tierColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF050C1C).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.withValues(alpha: 0.5), width: 1.0),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topEnd,
          end: AlignmentDirectional.bottomStart,
          colors: [
            tc.withValues(alpha: 0.32),
            const Color(0xFF050C1C).withValues(alpha: 0.88),
          ],
          stops: const [0.0, 0.65],
        ),
        boxShadow: [
          BoxShadow(
            color: tc.withValues(alpha: 0.38),
            blurRadius: 26,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          // كوكب / أيقونة المستوى (pro-tier-orb)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: tc.withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                _tierEmblem,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.stars_rounded, color: tc, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 11),

          // اسم المستوى وتفاصيله (pro-tier-name & pro-tier-sub)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('المستوى «$_aiTierName»', 'Level “$_aiTierName”'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bodyText(kWhite, 14.0, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _tierSpec,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bodyText(kMist, 11.2, weight: FontWeight.w400),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // زر الترقية (pro-up upbtn)
          InkWell(
            onTap: () async {
              await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (ctx) => AiDiagnosticScreen(
                    startAtSurvey: true,
                    onDiagnosticComplete: () {
                      if (Navigator.of(ctx).canPop()) {
                        Navigator.of(ctx).pop(true);
                      }
                    },
                  ),
                ),
              );
              if (mounted) {
                await _load();
              }
            },
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 7.5,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [tc, tc.withValues(alpha: 0.65)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: tc.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                tr('ترقية', 'Upgrade'),
                style: bodyText(Colors.white, 12.0, weight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// نفس رأس صفحة الدخول: الدعم وقناتانا ايقونات، واللغة على النهاية
  Widget _header(MediaQueryData media, double content) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(color: kWhite.withValues(alpha: 0.08)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, media.padding.top + 10, 14, 12),
        child: Center(
          child: SizedBox(
            width: content,
            height: 42,
            child: Row(
              children: [
                IconLink(
                  key: const ValueKey('support-btn'),
                  icon: Icons.support_agent_rounded,
                  color: kEmerald,
                  label: tr('الدعم', 'Support'),
                  onTap: () => openUrl(kHelpLink),
                ),
                const SizedBox(width: 6),
                IconLink(
                  key: const ValueKey('channel-telegram'),
                  icon: Icons.telegram,
                  color: const Color(0xFF29A9EB),
                  label: tr('قناة التليجرام', 'Telegram channel'),
                  onTap: () => openUrl(kTelegramUrl),
                ),
                const SizedBox(width: 6),
                IconLink(
                  key: const ValueKey('channel-youtube'),
                  icon: Icons.smart_display_rounded,
                  color: const Color(0xFFFF2D2D),
                  label: tr('قناة اليوتيوب', 'YouTube channel'),
                  onTap: () => openUrl(kYoutubeUrl),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: LangToggle(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── الكارت: تصميم هولوجرافي مستقبلي جديد تماماً (Cyber Neural Matrix HUD) ──
  Widget _card() {
    final look = _look;
    final (Color c, Color c2) = switch (look) {
      _Look.ok || _Look.won => (_okC, _okC2),
      _Look.lost => (_badC, _badC2),
      _ => (kEmerald, kEmeraldDeep),
    };
    final lastRow =
        _show?.row ??
        (_end.isNotEmpty && _done.isNotEmpty ? _done.last.row : _row);
    final word = switch (look) {
      _Look.ready => tr('جاهز', 'Ready'),
      _Look.busy => tr('$_aiTierName يفحص...', '$_aiTierName scanning...'),
      _Look.pick => tr('الخانة ${_cell + 1}', 'Cell ${_cell + 1}'),
      _Look.ok => tr('تحليل ناجح ✓', 'Successful scan ✓'),
      _Look.won => tr('اكتملت جميع الصفوف', 'All 10 rows completed'),
      _Look.lost => tr('انتهت الجولة', 'Cycle finished'),
    };
    final big = look == _Look.pick;
    final lost = look == _Look.lost;

    return AnimatedContainer(
      key: _cardKey,
      duration: Motion.slow,
      curve: Motion.standard,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: lost ? const Color(0xFF0C0707) : const Color(0xFF0A0E14),
        gradient: lost
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  c.withValues(alpha: 0.18),
                  const Color(0xFF0E131A).withValues(alpha: 0.95),
                  const Color(0xFF070A0E).withValues(alpha: 0.98),
                ],
                stops: const [0, 0.45, 1.0],
              ),
        border: Border.all(
          color: lost
              ? _badC.withValues(alpha: 0.8)
              : c.withValues(alpha: 0.42),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: (lost ? _badC : c).withValues(alpha: lost ? 0.35 : 0.22),
            blurRadius: 32,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        key: const ValueKey('pk-card'),
        children: [
          // إضاءة هولوجرافية علوية وسفلية
          Positioned(
            top: 0,
            left: 20,
            right: 20,
            height: 1.2,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    c.withValues(alpha: 0.8),
                    c.withValues(alpha: 0.9),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // خط النور والوميض تحت المحتوى
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _fx,
                builder: (context, _) => CustomPaint(
                  painter: _FxPainter(
                    fx: _fxNow,
                    ms: _fx.value * _kFxMs,
                    layer: 0,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── شريط HUD العلوي المستقبلي: حالة النظام ورقم الصف ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // شارة نظام الذكاء الاصطناعي مع نقطة نبضية
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: c.withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6.5,
                            height: 6.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c,
                              boxShadow: [
                                BoxShadow(
                                  color: c.withValues(alpha: 0.8),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _aiTierName.toUpperCase(),
                            style: markText(c, 10, weight: FontWeight.w700, spacing: 0.6),
                          ),
                        ],
                      ),
                    ),

                    // شارة الصف والتقدم
                    Container(
                      key: const ValueKey('pk-row'),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                      decoration: BoxDecoration(
                        color: kWhite.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: kWhite.withValues(alpha: 0.12),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.layers_outlined, color: kMist, size: 13),
                          const SizedBox(width: 5),
                          Text(
                            tr('الصف $lastRow / 10', 'ROW $lastRow / 10'),
                            style: markText(kWhiteSoft, 11, weight: FontWeight.w700, spacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── اللوح الأوسط: المركز العصبي ومؤشر الخانة المستهدفة ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: kWhite.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: c.withValues(alpha: 0.18),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      // دائرة الرادار الهولوجرافية
                      _Orb(
                        key: _orbKey,
                        look: look,
                        c: c,
                        c2: c2,
                        loop: _orbLoop,
                        pop: _pop,
                      ),
                      const SizedBox(width: 16),
                      // المؤشرات والكلمة الكبيرة
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tr('المسار التحليلي المستهدف', 'TARGET TELEMETRY PATH'),
                              style: markText(
                                c.withValues(alpha: 0.8),
                                9.5,
                                weight: FontWeight.w700,
                                spacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedSwitcher(
                              duration: Motion.medium,
                              transitionBuilder: slideSwapTransition,
                              child: Row(
                                key: ValueKey('$word-${look == _Look.busy}'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      word,
                                      maxLines: 2,
                                      style: headText(
                                        c,
                                        big ? 32 : 20,
                                        height: 1.15,
                                        weight: FontWeight.w800,
                                      ).copyWith(
                                        shadows: [
                                          Shadow(
                                            color: c.withValues(alpha: 0.65),
                                            blurRadius: 26,
                                          ),
                                          Shadow(
                                            color: c.withValues(alpha: 0.4),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (look == _Look.busy) ...[
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      width: 17,
                                      height: 17,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          c,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // فاصل تقني هولوجرافي
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              c.withValues(alpha: 0.35),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              c.withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── كبسولات الخانات الخمس (The 5 Quantum Sensor Pods) ──
                _board(),
              ],
            ),
          ),
          // الحلقات والشرارات والنقطة فوق المحتوى
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _fx,
                builder: (context, _) => CustomPaint(
                  painter: _FxPainter(
                    fx: _fxNow,
                    ms: _fx.value * _kFxMs,
                    layer: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// خانات الصف الخمس
  Widget _board() {
    final last =
        _show ?? (_end.isNotEmpty && _done.isNotEmpty ? _done.last : null);
    return AnimatedBuilder(
      animation: _idle,
      builder: (context, _) => Row(
        children: [
          for (var i = 0; i < _kCells; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            Expanded(
              child: _Cell(
                key: _cellKeys[i],
                testKey: ValueKey('pk-cell-$i'),
                index: i,
                state: last != null
                    ? (last.cell == i
                          ? (last.ok ? _CellState.ok : _CellState.bad)
                          : _CellState.idle)
                    : (_cell == i
                          ? _CellState.pick
                          : (_scan == i ? _CellState.scan : _CellState.idle)),
                pop: _pop,
                t: _idle.value * 7.2,
                moving: _idle.isAnimating,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// عشرة اشرطة للصفوف: الصحيحة خضراء، والحالي بلون المنصة، والخاطئة حمراء
  Widget _progress() {
    final current = _end.isEmpty ? _row : -1;
    return Row(
      key: const ValueKey('pk-progress'),
      children: [
        for (var r = 1; r <= _kRows; r++) ...[
          if (r > 1) const SizedBox(width: 5),
          Expanded(
            child: AnimatedContainer(
              duration: Motion.medium,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: () {
                  final d = _done.where((e) => e.row == r);
                  if (d.isNotEmpty) return d.last.ok ? _okC : _badC;
                  if (r == current) return kEmerald;
                  return kWhite.withValues(alpha: 0.1);
                }(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// الزر: يمتلئ بلون المنصة اثناء الاختيار، و«جولة جديدة» بعد نهايتها
  Widget _button() {
    final label = _busy
        ? tr('جاري التحليل عبر $_aiTierName...', 'Analyzing via $_aiTierName...')
        : _end.isNotEmpty
        ? tr('جولة جديدة', 'New round')
        : tr('اختر خانة', 'Pick a cell');
    final dark = _fill > 0.55;
    return Semantics(
      key: const ValueKey('pk-btn'),
      button: true,
      enabled: !_busy,
      child: GestureDetector(
        onTap: _busy ? null : _pick,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 58,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: kWhite.withValues(alpha: 0.07),
            border: Border.all(color: kWhite.withValues(alpha: 0.12)),
          ),
          child: Stack(
            children: [
              // الامتلاء من البداية
              Positioned.fill(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: _fill.clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [kEmeraldDeep, kEmerald],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // خط ضوء رفيع اعلى الزر
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 1,
                child: ColoredBox(color: kWhite.withValues(alpha: 0.2)),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: headText(
                            dark ? kOnEmerald : kWhite,
                            15.5,
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (_busy) ...[
                        const SizedBox(width: 8),
                        _Dots(color: dark ? kOnEmerald : kWhite),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// «هل كانت صحيحة؟» وزرّا صحيحة وخاطئة
  Widget _ask() {
    Widget answer(bool ok) => Expanded(
      child: GestureDetector(
        key: ValueKey(ok ? 'pk-yes' : 'pk-no'),
        onTap: () => _answer(ok),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: (ok ? _okC : _badC).withValues(alpha: 0.12),
            border: Border.all(
              color: (ok ? _okC : _badC).withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                ok ? Icons.check_rounded : Icons.close_rounded,
                size: 20,
                color: ok ? _okC : const Color(0xFFF87171),
              ),
              const SizedBox(width: 7),
              Text(
                ok ? tr('صحيحة', 'Right') : tr('خاطئة', 'Wrong'),
                style: headText(
                  ok ? _okC : const Color(0xFFF87171),
                  16,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      key: const ValueKey('pk-ask'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('هل كانت صحيحة؟', 'Was it right?'),
          textAlign: TextAlign.center,
          style: headText(kWhite, 16, height: 1.3),
        ),
        const SizedBox(height: 10),
        Row(children: [answer(true), const SizedBox(width: 10), answer(false)]),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// دائرة الحالة — sig-orb في gpt
// ═══════════════════════════════════════════════════════════════

/// لون الحالة بتدرج ولمعة في اعلاها، وحلقة خفيفة ووهج. يدور عليها لمعان كل 7
/// ثوان وتتنفس كل 4.5. ما فيها يظهر بارتداد حين تتغير الحالة.
class _Orb extends StatelessWidget {
  final _Look look;
  final Color c;
  final Color c2;
  final Animation<double> loop;
  final int pop;
  const _Orb({
    super.key,
    required this.look,
    required this.c,
    required this.c2,
    required this.loop,
    required this.pop,
  });

  @override
  Widget build(BuildContext context) {
    final Widget inner = switch (look) {
      _Look.lost => const Icon(
        Icons.close_rounded,
        color: Colors.white,
        size: 32,
      ),
      _ => ClipOval(
        child: Image.asset(
          'assets/cell_apple.png',
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.check_rounded, color: Colors.white, size: 30),
        ),
      ),
    };
    return AnimatedBuilder(
      animation: loop,
      builder: (context, child) {
        final s = loop.value * 31.5;
        final breath = 1 + 0.04 * (0.5 - 0.5 * math.cos(s / 4.5 * 2 * math.pi));
        final turn = (s / 7) % 1;
        return Transform.scale(
          scale: breath,
          child: SizedBox.square(
            dimension: 62,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: Motion.slow,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [c, c2],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: c.withValues(alpha: 0.16),
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: c.withValues(alpha: 0.75),
                        blurRadius: 28,
                      ),
                      BoxShadow(
                        color: c.withValues(alpha: 0.35),
                        blurRadius: 64,
                      ),
                    ],
                  ),
                ),
                // لمعة في اعلاها
                const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment(-0.36, -0.44),
                      radius: 0.6,
                      colors: [Color(0x61FFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                  child: SizedBox.expand(),
                ),
                // اللمعان الدائر
                Transform.rotate(
                  angle: turn * 2 * math.pi,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Color(0x00FFFFFF),
                          Color(0x00FFFFFF),
                          Color(0x66FFFFFF),
                          Color(0x00FFFFFF),
                        ],
                        stops: [0, 0.6, 0.8, 0.96],
                      ),
                    ),
                    child: SizedBox.expand(),
                  ),
                ),
                child!,
              ],
            ),
          ),
        );
      },
      child: TweenAnimationBuilder<double>(
        key: ValueKey('orb-$pop-${look.name}'),
        tween: Tween(begin: 0.7, end: 1),
        duration: Motion.slow,
        curve: Motion.overshoot,
        builder: (context, s, child) => Transform.scale(scale: s, child: child),
        child: inner,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// خانة الصف — pk-cell في gpt
// ═══════════════════════════════════════════════════════════════

enum _CellState { idle, scan, pick, ok, bad }

/// زجاج بعمق، وقلب صغير مضيء ينبض كل 2.4 ثانية، ولمعة تمر عليها كل 3.6،
/// كل خانة بعد اختها. الضوء يرفعها، والمختارة بلون المنصة يتوهج حولها
/// واطار تثبيت، والصحيحة خضراء والخاطئة حمراء.
class _Cell extends StatelessWidget {
  final Key testKey;
  final int index;
  final _CellState state;
  final int pop;

  /// الزمن بالثواني على دورة الخانات (7.2)
  final double t;
  final bool moving;
  const _Cell({
    super.key,
    required this.testKey,
    required this.index,
    required this.state,
    required this.pop,
    required this.t,
    required this.moving,
  });

  @override
  Widget build(BuildContext context) {
    final lit = state == _CellState.scan;
    final filled =
        state == _CellState.pick ||
        state == _CellState.ok ||
        state == _CellState.bad;
    final (Color a, Color b) = switch (state) {
      _CellState.ok => (_okC, _okC2),
      _CellState.bad => (_badC, _badC2),
      _ => (kEmerald, kEmeraldDeep),
    };
    // نبض القلب ووهج المختارة ولمعة المرور، كل خانة متأخرة عن اختها
    final heart = moving
        ? 0.5 - 0.5 * math.cos(((t - index * 0.16) / 2.4) * 2 * math.pi)
        : 0.0;
    final glow = moving ? 0.5 - 0.5 * math.cos((t / 1.8) * 2 * math.pi) : 0.0;
    final sw = moving ? ((t - index * 0.14) % 3.6) / 3.6 : 0.0;
    final sheen = sw < 0.55 ? null : 1.4 - 1.8 * ((sw - 0.55) / 0.45);

    final Widget? mark = switch (state) {
      _CellState.pick || _CellState.ok => const Icon(
        Icons.check_rounded,
        color: Colors.white,
        size: 28,
      ),
      _CellState.bad => const Icon(
        Icons.close_rounded,
        color: Colors.white,
        size: 22,
      ),
      _ => null,
    };

    final box = AnimatedContainer(
      key: testKey,
      duration: lit ? const Duration(milliseconds: 50) : Motion.slow,
      curve: Motion.standard,
      height: 58,
      clipBehavior: Clip.antiAlias,
      transform: Matrix4.translationValues(0, lit ? -3 : (filled ? -2 : 0), 0)
        ..scaleByDouble(lit ? 1.05 : 1, lit ? 1.05 : 1, 1, 1),
      transformAlignment: Alignment.center,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: filled
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [a, b],
              )
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: lit
                    ? [
                        kEmerald.withValues(alpha: 0.9),
                        kEmerald.withValues(alpha: 0.4),
                      ]
                    : [
                        kWhite.withValues(alpha: 0.1),
                        kWhite.withValues(alpha: 0.03),
                        kWhite.withValues(alpha: 0.05),
                      ],
              ),
        border: Border.all(
          color: filled
              ? (state == _CellState.bad ? _badC : a)
              : (lit ? kEmerald : kWhite.withValues(alpha: 0.16)),
          width: filled ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (lit) ...[
            BoxShadow(color: kEmerald.withValues(alpha: 0.85), blurRadius: 24),
            BoxShadow(color: Colors.white.withValues(alpha: 0.7), blurRadius: 6),
          ],
          if (state == _CellState.pick) ...[
            BoxShadow(
              color: a.withValues(alpha: lerp(0.35, 0.25, glow)),
              spreadRadius: lerp(2, 4, glow),
            ),
            BoxShadow(
              color: a.withValues(alpha: lerp(0.85, 1, glow)),
              blurRadius: lerp(24, 36, glow),
            ),
          ],
          if (state == _CellState.ok || state == _CellState.bad) ...[
            BoxShadow(color: a.withValues(alpha: 0.35), spreadRadius: 2),
            BoxShadow(color: a.withValues(alpha: 0.75), blurRadius: 24),
          ],
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // شريط إضاءة علوي على رأس الكبسولة
          Positioned(
            top: 3,
            left: 10,
            right: 10,
            height: 2,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: filled
                    ? Colors.white.withValues(alpha: 0.75)
                    : (lit ? Colors.white : kWhite.withValues(alpha: 0.2)),
                boxShadow: [
                  if (lit || filled)
                    BoxShadow(
                      color: (lit ? Colors.white : a).withValues(alpha: 0.9),
                      blurRadius: 4,
                    ),
                ],
              ),
            ),
          ),

          // لمعة تمر على الزجاج
          if (!filled && sheen != null)
            Positioned.fill(
              child: FractionalTranslation(
                translation: Offset(sheen - 0.5, 0),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1, -0.4),
                      end: Alignment(1, 0.4),
                      colors: [
                        Color(0x00FFFFFF),
                        Color(0x33FFFFFF),
                        Color(0x00FFFFFF),
                      ],
                      stops: [0.3, 0.5, 0.7],
                    ),
                  ),
                ),
              ),
            ),

          // علامة الصح الكبيرة أو رادار الاستشعار
          mark ??
              Transform.scale(
                  scale: lit ? 1 : 1 - 0.18 * heart,
                  child: Opacity(
                    opacity: lit ? 1 : 1 - 0.45 * heart,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: lit
                              ? Colors.white
                              : kEmerald.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (lit ? Colors.white : kEmerald).withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: lit ? 12 : 10,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: lit ? Colors.white : kEmerald,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

          // رقم الخانة الرقمي في أسفل الكبسولة
          Positioned(
            bottom: 4,
            child: Text(
              '0${index + 1}',
              style: markText(
                filled
                    ? Colors.white.withValues(alpha: 0.8)
                    : (lit ? Colors.white : kWhite.withValues(alpha: 0.28)),
                8.5,
                weight: FontWeight.w700,
                spacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );

    if (!filled) return box;
    // ظهور بارتداد حين تُختار او تُجاب، واطار التثبيت حول المختارة
    return TweenAnimationBuilder<double>(
      key: ValueKey('pop-$pop-${state.name}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (context, v, child) {
        final popV = Motion.overshoot.transform((v / 0.63).clamp(0.0, 1.0));
        final lockV = Motion.overshoot.transform(
          ((v - 0.17) / 0.83).clamp(0.0, 1.0),
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Transform.scale(scale: lerp(0.82, 1, popV), child: child),
            if (state == _CellState.pick)
              Positioned.fill(
                child: IgnorePointer(
                  child: Transform.scale(
                    scale: lerp(1.6, 1.12, lockV),
                    child: Opacity(
                      opacity: lockV.clamp(0.0, 1.0),
                      child: const CustomPaint(painter: _LockPainter()),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: box,
    );
  }
}

/// اطار التثبيت حول الخانة المختارة: اربع زوايا بيضاء
class _LockPainter extends CustomPainter {
  const _LockPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xF2FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const l = 9.0;
    final w = size.width, h = size.height;
    for (final c in [
      [Offset.zero, const Offset(1, 0), const Offset(0, 1)],
      [Offset(w, 0), const Offset(-1, 0), const Offset(0, 1)],
      [Offset(0, h), const Offset(1, 0), const Offset(0, -1)],
      [Offset(w, h), const Offset(-1, 0), const Offset(0, -1)],
    ]) {
      canvas.drawLine(c[0], c[0] + c[1] * l, p);
      canvas.drawLine(c[0], c[0] + c[2] * l, p);
    }
  }

  @override
  bool shouldRepaint(covariant _LockPainter old) => false;
}

// ═══════════════════════════════════════════════════════════════
// مؤثرات الكارت — pk-fx في gpt
// ═══════════════════════════════════════════════════════════════

/// الطبقة 0 تحت المحتوى: خط النور من الدائرة الى رأس الخانة (يُرسم في 0.6
/// ثانية ويبقى)، ووميض دائري عند الخانة. الطبقة 1 فوقه: ثلاث حلقات تتسع،
/// واربع عشرة شرارة، ونقطة مضيئة على رأس الخانة عند الاختيار.
class _FxPainter extends CustomPainter {
  final _Fx? fx;
  final double ms;
  final int layer;
  const _FxPainter({required this.fx, required this.ms, required this.layer});

  static double _seg(double ms, double start, double dur) =>
      ((ms - start) / dur).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final f = fx;
    if (f == null) return;
    final col = f.color;
    final pick = f.kind == _FxKind.pick;
    final late = pick ? 550.0 : 0.0;
    final x2 = f.to.dx, y2 = f.to.dy, top = f.cellTop;

    if (layer == 0) {
      if (pick) {
        final p = const Cubic(0.3, 0.7, 0.2, 1).transform(_seg(ms, 0, 600));
        if (p > 0) {
          final x1 = f.from.dx, y1 = f.from.dy;
          final path = Path()
            ..moveTo(x1, y1)
            ..cubicTo(x1 + (x2 - x1) * 0.55, y1 - 18, x2, top - 60, x2, top);
          for (final m in path.computeMetrics()) {
            final part = m.extractPath(0, m.length * p);
            canvas.drawPath(
              part,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 6
                ..color = col.withValues(alpha: 0.5)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.4),
            );
            canvas.drawPath(
              part,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.8
                ..strokeCap = StrokeCap.round
                ..color = col,
            );
          }
        }
      }
      // الوميض
      final fl = _seg(ms, late, 1300);
      if (fl > 0 && fl < 1) {
        final o = fl < 0.25 ? fl / 0.25 : 1 - (fl - 0.25) / 0.75;
        final r = math.max(f.card.width, f.card.height) * 0.6;
        canvas.drawCircle(
          Offset(x2, y2),
          r,
          Paint()
            ..shader = RadialGradient(
              colors: [
                col.withValues(alpha: 0.5 * o),
                col.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: Offset(x2, y2), radius: r)),
        );
      }
      return;
    }

    // الحلقات
    for (var k = 0; k < 3; k++) {
      final v = _seg(ms, late + k * 180, 1100);
      if (v <= 0 || v >= 1) continue;
      final e = const Cubic(0.2, 0.7, 0.3, 1).transform(v);
      canvas.drawCircle(
        Offset(x2, y2),
        23 * lerp(0.35, 3.4, e),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = col.withValues(alpha: 0.95 * (1 - e)),
      );
    }
    // الشرارات
    final sv = _seg(ms, late + 50, 750);
    if (sv > 0 && sv < 1) {
      final e = const Cubic(0.15, 0.7, 0.3, 1).transform(sv);
      for (final d in f.sparks) {
        final c = Offset(x2, y2) + d * e;
        final r = 2.5 * lerp(1.2, 0.2, e);
        canvas.drawCircle(
          c,
          r * 2.4,
          Paint()
            ..color = col.withValues(alpha: 0.5 * (1 - e))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawCircle(c, r, Paint()..color = col.withValues(alpha: 1 - e));
      }
    }
    // النقطة على رأس الخانة
    if (pick && ms >= 550) {
      final inV = _seg(ms, 550, 200);
      final blip = ms < 750
          ? 1.0
          : 1 -
                0.45 *
                    (0.5 - 0.5 * math.cos(((ms - 750) / 1800) * 2 * math.pi));
      canvas.drawCircle(
        Offset(x2, top),
        8,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6 * inV)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(
        Offset(x2, top),
        3.5 * inV,
        Paint()..color = col.withValues(alpha: blip),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FxPainter old) =>
      old.fx != fx || old.ms != ms || old.layer != layer;
}

/// ثلاث نقاط تنبض اثناء الاختيار
class _Dots extends StatefulWidget {
  final Color color;
  const _Dots({required this.color});

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (motionAllowed(context)) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity:
                    0.35 +
                    0.65 *
                        (0.5 +
                            0.5 * math.sin((_c.value - i / 3) * 2 * math.pi)),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
