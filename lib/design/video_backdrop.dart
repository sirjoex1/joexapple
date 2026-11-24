import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'design_system.dart';

// ═══════════════════════════════════════════════════════════════
// خلفية الفيديو لصفحة الدخول — فيديو يدور بلا صوت والبلور الخفيف مطبوع فيه
// نفسه، فوقه غلالة خضراء خفيفة شبه شفافة واطار معتم يحفظ قراءة ما فوقه.
// كل خلفية فيديو ظاهرة تعرض فيديو واحدا مشتركا، فلو استخدمتها صفحة اخرى
// يكمل الفيديو من مكانه بينهما بلا تحميل جديد ولا وميض.
// اول اطار منه صورة ثابتة تحته: تظهر حتى يبدأ، وتبقى وحدها اذا قلت الحركة
// او تعذر تشغيله. يقف حين يخرج المستخدم من التطبيق ويكمل حين يعود، ولا
// يقطع صوت تطبيق آخر يعمل.
// ═══════════════════════════════════════════════════════════════
class VideoBackdrop extends StatefulWidget {
  /// قوة الغلالة الخضراء فوق الفيديو، من 0 الى 1
  final double veil;

  const VideoBackdrop({super.key, this.veil = 0.22});

  @override
  State<VideoBackdrop> createState() => _VideoBackdropState();
}

class _VideoBackdropState extends State<VideoBackdrop> {
  final _SharedVideo _shared = _SharedVideo.instance;

  /// هذه الصفحة تسمح بالحركة: لو منعتها صفحة ظاهرة يقف الفيديو للكل
  bool moving = false;
  bool _joined = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    moving = motionAllowed(context);
    if (_joined) {
      _shared.changed();
    } else {
      _joined = true;
      _shared.join(this);
    }
  }

  @override
  void dispose() {
    _shared.leave(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: kInk),
          Image.asset(
            kVideoPosterAsset,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          ListenableBuilder(
            listenable: _shared,
            builder: (context, _) {
              final v = _shared.video;
              if (v == null) return const SizedBox.shrink();
              // صفحة تدخل والفيديو ظاهر من قبل: يظهر فيها فورا بلا تلاش
              return RepaintBoundary(
                child: AnimatedOpacity(
                  opacity: _shared.shown ? 1 : 0,
                  duration: const Duration(milliseconds: 700),
                  curve: Motion.standard,
                  child: ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: v.value.size.width,
                        height: v.value.size.height,
                        child: VideoPlayer(v),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          RepaintBoundary(
            child: CustomPaint(painter: _VeilPainter(veil: widget.veil)),
          ),
        ],
      ),
    );
  }
}

/// الفيديو الواحد الذي تتشاركه الخلفيات: يُفتح مع اول خلفية تظهر ويُغلق
/// بعد آخر خلفية تختفي. اثناء انتقال الصفحات تكون الخلفيتان معا فلا يُغلق.
class _SharedVideo extends ChangeNotifier with WidgetsBindingObserver {
  _SharedVideo._();
  static final _SharedVideo instance = _SharedVideo._();

  final Set<_VideoBackdropState> _users = {};
  VideoPlayerController? _opening;
  bool _foreground = true;
  bool _failed = false;

  /// الفيديو بعد ان يجهز، وقبلها null فتبقى الصورة الثابتة وحدها
  VideoPlayerController? video;

  /// وصل اول اطار فعلا: عندها فقط يظهر الفيديو فوق الصورة فلا يومض اسود
  bool shown = false;

  bool get _wanted => _users.isNotEmpty && _users.every((u) => u.moving);

  void join(_VideoBackdropState user) {
    if (_users.isEmpty) WidgetsBinding.instance.addObserver(this);
    _users.add(user);
    changed();
  }

  void leave(_VideoBackdropState user) {
    _users.remove(user);
    if (_users.isEmpty) WidgetsBinding.instance.removeObserver(this);
    changed();
  }

  /// الحساب بعد الاطار الجاري: تشغيل الفيديو يغير قيمته فيعيد بناء
  /// الخلفيات، وذلك لا يصح وسط بناء الشجرة او تفكيكها. وصفحة تخرج وأخرى
  /// تدخل في الاطار نفسه لا تغلق الفيديو بينهما.
  void changed() => scheduleMicrotask(_sync);

  void _sync() {
    if (_users.isEmpty) {
      _close();
      return;
    }
    final v = video;
    if (v == null) {
      if (_wanted && _opening == null && !_failed) _open();
      return;
    }
    if (_wanted && _foreground) {
      if (!v.value.isPlaying) v.play();
    } else if (v.value.isPlaying) {
      v.pause();
    }
  }

  Future<void> _open() async {
    final v = VideoPlayerController.asset(
      kVideoAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _opening = v;
    try {
      await v.initialize();
      await v.setLooping(true);
      await v.setVolume(0);
    } catch (_) {
      // تبقى الصورة الثابتة مكانه
      if (_opening == v) {
        _opening = null;
        _failed = true;
      }
      v.dispose();
      return;
    }
    // اختفت الخلفيات كلها اثناء التحميل
    if (_opening != v) {
      v.dispose();
      return;
    }
    _opening = null;
    video = v;
    v.addListener(_watch);
    notifyListeners();
    _sync();
  }

  void _watch() {
    final v = video;
    if (shown || v == null) return;
    if (v.value.isPlaying && v.value.position > Duration.zero) {
      shown = true;
      notifyListeners();
    }
  }

  void _close() {
    _opening = null;
    final v = video;
    if (v == null) return;
    video = null;
    shown = false;
    v.removeListener(_watch);
    v.dispose();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    changed();
  }
}

/// عتمة خفيفة ثم الغلالة الخضراء، واطار يغمق الحواف واعلى الشاشة وقاعها
class _VeilPainter extends CustomPainter {
  final double veil;
  const _VeilPainter({required this.veil});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = kInk.withValues(alpha: 0.24));
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            kJadeDeep.withValues(alpha: veil * 1.2),
            kJade.withValues(alpha: veil),
            kJadeDeep.withValues(alpha: veil * 1.3),
          ],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 1.05,
          colors: [
            kInk.withValues(alpha: 0),
            kInk.withValues(alpha: 0.22),
            kInk.withValues(alpha: 0.7),
          ],
          stops: const [0.45, 0.75, 1],
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
            kInk.withValues(alpha: 0.6),
          ],
          stops: const [0, 0.16, 0.72, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _VeilPainter old) => old.veil != veil;
}
