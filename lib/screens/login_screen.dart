import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/design_system.dart';
import '../design/identity.dart';
import '../services/dynamic_link_service.dart';
import '../services/links.dart';
import '../widgets/ios_loading_dialog.dart';

/// شاشات الدخول: الحساب، وطريقة فتح الحساب (الموقع او التطبيق)، ثم التفعيل
enum _Ob { account, register, activate }

/// طريقة فتح الحساب في المنصة
enum _Method { web, app }

// ─────────────────────────────────────────────────────────────
// تسجيل الدخول — هيكل مشروع gpt على خلفية سوداء سادة
// فوق رأس ثابت: الرجوع، و«مساعدة» واللغة، ثم شريط الخطوات: الحساب ثم
// التفعيل ثم الوصول الى الاداة. بلا صورة ولا شعار.
//   الحساب: المنصات اولا (كل منصة تلوّن التطبيق بلونها)، ثم كارت افتح حسابك،
//           ثم رسمة فورم التسجيل وخطواتها الاربع، واتفاقية المستخدم. تحت: الازرق
//           «بالفعل سجّلت» يذهب الى التفعيل مباشرة، و«افتح حسابًا برمز الترويج»
//           بالاطار ينسخ الرمز ويفتح التسجيل ثم يصير «سجّلت».
//   التفعيل: معرّف الحساب والكود والقناتان، ورسمة مكان رقم الحساب، ثم
//            «تسجيل الدخول» كما كان: الكود joe27 ثم الاشتراك الاجباري.
// ─────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginComplete;

  /// الاستهلال ما زال فوقها: الدخول ينتظر ذهابه
  final bool heroVisible;

  const LoginScreen({
    super.key,
    required this.onLoginComplete,
    this.heroVisible = true,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _codeController = TextEditingController(); // kept for saved data
  final FocusNode _idFocusNode = FocusNode();
  final FocusNode _codeFocusNode = FocusNode();
  final ScrollController _scroll = ScrollController();

  _Ob _screen = _Ob.account;

  /// طريقة التسجيل المختارة في صفحة «افتح حسابك»
  _Method _method = _Method.web;

  /// نُسخ الرمز في طريقة التطبيق: الزر صار «سجّلت»
  bool _appCopied = false;

  /// فُتح رابط التسجيل: الزر صار «سجّلت»
  bool _regOpened = false;

  /// الحساب مر من الخطوة الاولى
  bool _accountDone = false;

  String? _idError;
  String? _codeError; // ignore: unused_field
  bool _isSubmitting = false;
  bool _started = false;

  int _idShake = 0;
  final int _codeShake = 0; // ignore: unused_field

  @override
  void initState() {
    super.initState();
    _idFocusNode.addListener(() => setState(() {}));
    _codeFocusNode.addListener(() => setState(() {}));
    _idController.addListener(() => setState(() {}));
    _codeController.addListener(() => setState(() {}));
    _loadSaved();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!motionAllowed(context)) {
      _enter.value = 1;
    } else if (widget.heroVisible) {
      _enter.forward();
    }
    // صور المنصات تُحمّل مبكرا حتى لا تظهر خاناتها فارغة لحظة الدخول
    if (!isWidgetTest) {
      for (final p in Platform.values) {
        precacheImage(AssetImage(p.asset), context);
      }
    }
  }

  @override
  void didUpdateWidget(covariant LoginScreen old) {
    super.didUpdateWidget(old);
    // ذهب الاستهلال: تدخل الصفحة
    if (!old.heroVisible && widget.heroVisible && _enter.value == 0) {
      motionAllowed(context) ? _enter.forward() : _enter.value = 1;
    }
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('user_id') ?? '';
    final savedCode = prefs.getString('app_code') ?? '';
    if (!mounted) return;
    setState(() {
      if (savedId.isNotEmpty) _idController.text = savedId;
      if (savedCode.isNotEmpty) _codeController.text = savedCode;
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _idController.dispose();
    _codeController.dispose();
    _idFocusNode.dispose();
    _codeFocusNode.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _s2 => _idController.text.trim().isNotEmpty;
  bool get _s3 => _codeController.text.trim().isNotEmpty; // ignore: unused_element

  _Ob? get _backTo => switch (_screen) {
    _Ob.account => null,
    _Ob.register => _Ob.account,
    _Ob.activate => _Ob.account,
  };

  void _go(_Ob s) {
    FocusScope.of(context).unfocus();
    setState(() {
      if (s == _Ob.activate) _accountDone = true;
      _screen = s;
      _idError = null;
      _codeError = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _back() {
    final to = _backTo;
    if (to != null) _go(to);
  }

  /// الموقع: ينسخ الرمز ويفتح موقع التسجيل، وبعدها «سجّلت» الى التفعيل
  Future<void> _openSite() async {
    if (_regOpened) {
      _go(_Ob.activate);
      return;
    }
    setState(() => _regOpened = true);
    await _copyPromo();
    await openUrl(kRegLink);
  }

  /// التطبيق: ينسخ الرمز ليلصقه في تطبيق المنصة، وبعدها «سجّلت» الى التفعيل
  Future<void> _copyForApp() async {
    if (_appCopied) {
      _go(_Ob.activate);
      return;
    }
    setState(() => _appCopied = true);
    await _copyPromo();
  }

  void _pickMethod(_Method m) {
    if (m == _method) return;
    setState(() => _method = m);
  }

  Future<void> _copyPromo() async {
    try {
      await Clipboard.setData(const ClipboardData(text: kPromoCode));
      _toast(tr('تم نسخ رمز الترويج', 'Promo code copied'));
    } catch (_) {
      _toast(tr('انسخ الرمز يدويًا: joe27', 'Copy the code by hand: joe27'));
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    final m = ScaffoldMessenger.maybeOf(context);
    if (m == null) return;
    m.hideCurrentSnackBar();
    // فوق تحت الرأس مثل gpt، لا تحت فتغطي الزرين
    final mq = MediaQuery.of(context);
    final bottom = math.max(
      16.0,
      mq.size.height - mq.viewInsets.bottom - mq.padding.top - 150,
    );
    m.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(28, 0, 28, bottom),
        backgroundColor: kCoalHi,
        duration: const Duration(milliseconds: 2200),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(99),
          side: BorderSide(color: kEmerald.withValues(alpha: 0.5)),
        ),
        content: Text(
          msg,
          textAlign: TextAlign.center,
          style: bodyText(kWhite, 13, weight: FontWeight.w600),
        ),
      ),
    );
  }

  void _submit() async {
    if (_isSubmitting) return;
    final id = _idController.text.trim();

    setState(() {
      _idError = null;
      _codeError = null;
    });

    if (id.isEmpty) {
      setState(() {
        _idError = tr('يرجى إدخال معرف الحساب', 'Please enter your account ID');
        _idShake++;
      });
      _idFocusNode.requestFocus();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    IosLoadingDialog.show(
      context: context,
    );
    await Future<void>.delayed(const Duration(milliseconds: 750));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('user_id', id);
    await prefs.setInt(AppPrefs.platformKey, AppPrefs.instance.platform.index);

    if (!mounted) return;
    IosLoadingDialog.hide(context);
    setState(() => _isSubmitting = false);

    final hasSub = prefs.getBool('has_completed_subscription') ?? false;

    if (!hasSub) {
      _showMandatorySubscriptionDialog(prefs);
    } else {
      widget.onLoginComplete();
    }
  }

  void _showMandatorySubscriptionDialog(SharedPreferences prefs) {
    MandatorySubscriptionDialog.show(
      context,
      onSubscriptionVerified: () async {
        await prefs.setBool('has_completed_subscription', true);
        if (!mounted) return;
        widget.onLoginComplete();
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final side = size.width < 360 ? 14.0 : 18.0;
    final content = math.min(size.width - side * 2, 460.0);
    final bar = _ctaBar(content);

    return PopScope(
      canPop: _backTo == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        // اسود سادة: بلا صورة ولا فيديو
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: Directionality(
          textDirection: appDir,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // رأس ثابت مثل gpt: الرجوع على البداية، والمساعدة واللغة على
                  // النهاية، وتحتها شريط الخطوات ثم خط فاصل. بلا صورة ولا شعار
                  Entrance(
                    parent: _enter,
                    begin: 0,
                    end: 0.5,
                    dy: -12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border(
                          bottom: BorderSide(
                            color: kWhite.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          14,
                          media.padding.top + 10,
                          14,
                          12,
                        ),
                        child: Center(
                          child: SizedBox(
                            width: content,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 42,
                                  child: Row(
                                    children: [
                                      AnimatedSwitcher(
                                        duration: Motion.medium,
                                        child: _backTo == null
                                            ? const SizedBox(
                                                key: ValueKey('none'),
                                              )
                                            : Padding(
                                                key: const ValueKey('back'),
                                                padding:
                                                    const EdgeInsetsDirectional.only(
                                                      end: 6,
                                                    ),
                                                child: _RoundIcon(
                                                  key: const ValueKey(
                                                    'login-back',
                                                  ),
                                                  icon:
                                                      Icons.arrow_back_rounded,
                                                  label: tr('رجوع', 'Back'),
                                                  onTap: _back,
                                                ),
                                              ),
                                      ),
                                      // على الجنب: الدعم ثم قناتانا، ايقونات فقط
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
                                        label: tr(
                                          'قناة التليجرام',
                                          'Telegram channel',
                                        ),
                                        onTap: () => openUrl(kTelegramUrl),
                                      ),
                                      const SizedBox(width: 6),
                                      IconLink(
                                        key: const ValueKey('channel-youtube'),
                                        icon: Icons.smart_display_rounded,
                                        color: const Color(0xFFFF2D2D),
                                        label: tr(
                                          'قناة اليوتيوب',
                                          'YouTube channel',
                                        ),
                                        onTap: () => openUrl(kYoutubeUrl),
                                      ),
                                      // اللغة على النهاية تاخذ ما بقي كله،
                                      // وتقص نصها بنقاط حين تضيق الشاشة
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Align(
                                          alignment:
                                              AlignmentDirectional.centerEnd,
                                          child: LangToggle(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: _StepsBar(
                                    current: _screen == _Ob.activate ? 1 : 0,
                                    accountDone: _accountDone,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.only(top: 16, bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: SizedBox(
                              width: content,
                              child: Entrance(
                                parent: _enter,
                                begin: 0.18,
                                end: 0.8,
                                dy: 36,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: Motion.slow,
                                      switchInCurve: Motion.emphasized,
                                      switchOutCurve: Motion.standard,
                                      transitionBuilder: (child, a) =>
                                          FadeTransition(
                                            opacity: a,
                                            child: SlideTransition(
                                              position: Tween<Offset>(
                                                begin: const Offset(0, 0.04),
                                                end: Offset.zero,
                                              ).animate(a),
                                              child: child,
                                            ),
                                          ),
                                      layoutBuilder: (current, previous) =>
                                          Stack(
                                            alignment: Alignment.topCenter,
                                            children: [...previous, ?current],
                                          ),
                                      child: KeyedSubtree(
                                        key: ValueKey(_screen),
                                        child: _panel(content),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  bar,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// الشاشة الحالية: الحساب بكروت gpt، والباقي في لوح التذكرة
  Widget _panel(double content) {
    if (_screen == _Ob.account) return _accountScreen(content);
    if (_screen == _Ob.register) return _registerScreen(content);
    return TicketPanel(
      glint: true,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      child: _activateScreen(),
    );
  }

  /// كارت داكن بحافة خافتة مثل كروت gpt
  Widget _card({required Widget child, EdgeInsets? padding, Key? key}) =>
      Container(
        key: key,
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCoal.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: kWhite.withValues(alpha: 0.1)),
        ),
        child: child,
      );

  // ── الحساب: «افتح حسابك» ثم رسمة الفورم ثم اختيار المنصات ─────────────
  Widget _accountScreen(double content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // افتح حسابك: الايقونة في دائرة على البداية والعنوان بجوارها
        _card(
          key: const ValueKey('account-card'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              Container(
                width: 66,
                height: 66,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: kEmerald.withValues(alpha: 0.45),
                    width: 1.4,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kEmerald,
                    boxShadow: [
                      BoxShadow(
                        color: kEmerald.withValues(alpha: 0.45),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person_add_alt_rounded,
                    color: kOnEmerald,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr('افتح حسابك', 'Open your account'),
                      style: headText(kWhite, 22, height: 1.25),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr(
                        'التسجيل يستغرق دقيقتين. يُنسخ الرمز $kPromoCode تلقائيًا.',
                        'Sign-up takes 2 minutes. Promo code $kPromoCode is copied for you.',
                      ),
                      style: bodyText(kMist, 13, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // رسمة الفورم على البداية وخطواته الاربع بجوارها
        LayoutBuilder(
          builder: (context, box) {
            final narrow = box.maxWidth < 330;
            const mock = _SignupMock();
            final steps = _SignupSteps(compact: narrow);
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [mock, const SizedBox(height: 14), steps],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(flex: 54, child: mock),
                const SizedBox(width: 12),
                Expanded(flex: 46, child: steps),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        // اختيار المنصة أسفل رسمة الفورم وخطوات التسجيل
        _platformCard(content),
        const SizedBox(height: 18),
        Center(
          child: GestureDetector(
            key: const ValueKey('agreement-open'),
            onTap: () => _AgreementSheet.show(context),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                tr('اتفاقية المستخدم', 'User Agreement'),
                style: bodyText(kEmeraldPale, 12.5, weight: FontWeight.w600)
                    .copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: kEmeraldPale.withValues(alpha: 0.6),
                    ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          tr(
            'بالضغط على «افتح حساب من خلالنا»، فإنك توافق على اتفاقية المستخدم.',
            'By tapping “Open account through us”, you agree to the User Agreement.',
          ),
          textAlign: TextAlign.center,
          style: bodyText(kWhiteFaint, 11, height: 1.45),
        ),
      ],
    );
  }

  /// كارت المنصات: العنوان ثم ثلاث خانات مربعة فيها ايقونة المنصة وحدها،
  /// والمختارة بحافة لونها وعلامة صح في ركنها، وتلوّن التطبيق كله
  Widget _platformCard(double content) {
    final cur = AppPrefs.instance.platform;
    return _card(
      key: const ValueKey('platform-card'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('اختر المنصة', 'Select platform'),
            style: headText(kWhite, 17, height: 1.3),
          ),
          const SizedBox(height: 2),
          Text(
            tr(
              'حدد منصتك ليأخذ التطبيق لونها',
              'Pick your platform — the app takes its colour',
            ),
            style: bodyText(kMist, 12.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final p in Platform.values) ...[
                if (p.index > 0) const SizedBox(width: 10),
                Expanded(
                  child: _PlatformTile(
                    key: ValueKey('platform-${p.index}'),
                    index: p.index,
                    asset: p.asset,
                    badge: p.badge,
                    name: p.label,
                    glow: platformColor(p),
                    selected: cur == p,
                    onTap: () => AppPrefs.instance.setPlatform(p),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── افتح حسابك: الموقع او التطبيق ────────────────────────────────
  /// نفس الهوية بتقسيم جديد: كارت العنوان، ثم اختيار الطريقة في خانتين،
  /// ثم كارت رمز الترويج، ثم خطوات الطريقة المختارة. الموقع خطوات على خط
  /// زمني، والتطبيق نفس رسمة الفورم وخطواتها الاربع بعد فتح تطبيق المنصة.
  Widget _registerScreen(double content) {
    final web = _method == _Method.web;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          key: const ValueKey('register-card'),
          child: Row(
            children: [
              _IconDisc(icon: Icons.how_to_reg_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr('اختر طريقة التسجيل', 'Choose how to sign up'),
                      style: headText(kWhite, 21, height: 1.25),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr(
                        'افتح حسابك برمز الترويج $kPromoCode في دقيقتين، من الموقع أو من تطبيق المنصة.',
                        'Open your account with promo code $kPromoCode in 2 minutes, on the website or in the platform’s app.',
                      ),
                      style: bodyText(kMist, 13, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // اختيار الطريقة: خانتان متجاورتان
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MethodTile(
                  key: const ValueKey('method-web'),
                  icon: Icons.language_rounded,
                  title: tr('عبر الموقع', 'On the website'),
                  subtitle: tr(
                    'يفتح في المتصفح مباشرة',
                    'Opens right in your browser',
                  ),
                  tag: tr('الأسرع', 'Fastest'),
                  selected: web,
                  onTap: () => _pickMethod(_Method.web),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MethodTile(
                  key: const ValueKey('method-app'),
                  icon: Icons.phone_android_rounded,
                  title: tr('عبر التطبيق', 'In the app'),
                  subtitle: tr(
                    'من تطبيق المنصة على موبايلك',
                    'From the platform’s app on your phone',
                  ),
                  tag: tr('لو التطبيق عندك', 'If you have the app'),
                  selected: !web,
                  onTap: () => _pickMethod(_Method.app),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _PromoChip(onCopy: _copyPromo),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: Motion.medium,
          switchInCurve: Motion.emphasized,
          transitionBuilder: (child, a) =>
              FadeTransition(opacity: a, child: child),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          child: web
              ? _card(
                  key: const ValueKey('steps-web'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _stepsHeader(
                        Icons.language_rounded,
                        tr('التسجيل عبر الموقع', 'Signing up on the website'),
                        tr(
                          '5 خطوات · نحو دقيقتين',
                          '5 steps · about 2 minutes',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Timeline(
                        items: [
                          (
                            tr(
                              'اضغط «افتح موقع التسجيل»',
                              'Tap “Open the sign-up site”',
                            ),
                            tr(
                              'يُنسخ رمز الترويج $kPromoCode تلقائيًا ويفتح الموقع.',
                              'Promo code $kPromoCode is copied for you and the site opens.',
                            ),
                          ),
                          (
                            tr(
                              'اضغط «التسجيل» واختر الطريقة',
                              'Tap “Registration” and pick a method',
                            ),
                            tr(
                              'بنقرة واحدة، أو برقم الهاتف، أو بالبريد الإلكتروني.',
                              'One-click, phone number or e-mail.',
                            ),
                          ),
                          (
                            tr('أدخل البيانات المطلوبة', 'Fill in the details'),
                            tr(
                              'الدولة والعملة، والصق الرمز $kPromoCode في خانة رمز الترويج.',
                              'Country and currency, and paste $kPromoCode in the promo code field.',
                            ),
                          ),
                          (
                            tr(
                              'اضغط «تسجيل» واحفظ بياناتك',
                              'Tap “Register” and save your details',
                            ),
                            tr(
                              'احتفظ برقم الحساب وكلمة المرور في مكان آمن.',
                              'Keep your account number and password somewhere safe.',
                            ),
                          ),
                          (
                            tr('ارجع هنا وكمّل', 'Come back and continue'),
                            tr(
                              'اضغط «سجّلت» وأدخل رقم حسابك.',
                              'Tap “I’ve registered” and enter your account number.',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : _card(
                  key: const ValueKey('steps-app'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _stepsHeader(
                        Icons.phone_android_rounded,
                        tr('التسجيل عبر التطبيق', 'Signing up in the app'),
                        tr(
                          'نفس خطوات الفورم · نحو دقيقتين',
                          'The same form steps · about 2 minutes',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        tr('قبل ما تبدأ', 'Before you start'),
                        style: bodyText(
                          kEmeraldPale,
                          12.5,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _Timeline(
                        icons: const [
                          Icons.phone_android_rounded,
                          Icons.copy_rounded,
                        ],
                        items: [
                          (
                            tr('افتح تطبيق المنصة', 'Open the platform’s app'),
                            tr(
                              'لو مش متثبّت عندك، سجّل من الموقع بدلًا منه.',
                              'If it isn’t installed, sign up on the website instead.',
                            ),
                          ),
                          (
                            tr(
                              'انسخ رمز الترويج من هنا',
                              'Copy the promo code here',
                            ),
                            tr(
                              'الزر تحت ينسخ $kPromoCode لتلصقه في التطبيق.',
                              'The button below copies $kPromoCode for you to paste in the app.',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr('في التطبيق', 'In the app'),
                        style: bodyText(
                          kEmeraldPale,
                          12.5,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, box) {
                          final narrow = box.maxWidth < 330;
                          const mock = _SignupMock();
                          final steps = _SignupSteps(compact: narrow);
                          if (narrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                mock,
                                const SizedBox(height: 14),
                                steps,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              const Expanded(flex: 54, child: mock),
                              const SizedBox(width: 12),
                              Expanded(flex: 46, child: steps),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  /// عنوان كارت الخطوات: ايقونة الطريقة واسمها والمدة
  /// العنوان في سطره، والمدة في كبسولة تحته حتى لا يضيق السطر على الشاشات الصغيرة
  Widget _stepsHeader(IconData icon, String title, String sub) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(icon, size: 20, color: kEmerald),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: headText(kWhite, 16, height: 1.3)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kEmerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: kEmerald.withValues(alpha: 0.4)),
              ),
              child: Text(
                sub,
                style: bodyText(
                  kEmeraldPale,
                  11,
                  weight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  // ── التفعيل: المعرّف والكود ───────────────────────────────────
  Widget _activateScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            'هل سجّلت حسابًا من خلالنا؟',
            'Did you register an account through us?',
          ),
          style: headText(kWhite, 20, height: 1.3),
        ),
        const SizedBox(height: 4),
        Text(
          tr(
            'أدخل معرّف حسابك للدخول.',
            'Enter your account ID to sign in.',
          ),
          style: bodyText(kMist, 13),
        ),
        const SizedBox(height: 14),
        _BoxField(
          key: const ValueKey('field-id'),
          label: tr('معرّف الحساب', 'Account ID'),
          icon: Icons.badge_outlined,
          controller: _idController,
          focusNode: _idFocusNode,
          hint: tr('أدخل معرف الحساب', 'Enter your account ID'),
          error: _idError,
          done: _s2 && _idError == null,
          shake: _idShake,
          action: TextInputAction.done,
          keyboard: TextInputType.number,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        // السهم ايقونة لا حرف: خط العناوين ليس فيه رمز السهم
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: tr(
                  'أين أجده؟ الملف الشخصي ',
                  'Where to find it? Personal profile ',
                ),
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 15,
                  color: kEmeraldPale,
                ),
              ),
              TextSpan(text: tr(' رقم الحساب', ' Account number')),
            ],
          ),
          style: headText(kWhite, 13.5, height: 1.35),
        ),
        const SizedBox(height: 8),
        const _ProfileMock(),
      ],
    );
  }

  // ── الازرار المثبتة تحت ───────────────────────────────────────
  Widget _ctaBar(double content) {
    final Widget body = switch (_screen) {
      _Ob.account => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // الازرق: «بالفعل سجّلت حسابًا من خلالكم» الى المعرّف والكود مباشرة
          PillButton(
            key: const ValueKey('cta-have'),
            label: tr(
              'بالفعل سجّلت حسابًا من خلالكم',
              'I already registered an account through you',
            ),
            height: 54,
            attention: true,
            onPressed: () => _go(_Ob.activate),
          ),
          const SizedBox(height: 10),
          // بالاطار: يفتح صفحة اختيار طريقة التسجيل (الموقع او التطبيق)
          _OutlineBar(
            key: const ValueKey('cta-open'),
            label: tr(
              'افتح حساب من خلالنا',
              'Open account through us',
            ),
            onTap: () => _go(_Ob.register),
          ),
        ],
      ),
      _Ob.register =>
        _method == _Method.web
            ? PillButton(
                key: const ValueKey('reg-primary'),
                label: _regOpened
                    ? tr(
                        'سجّلت — أدخل رقم الحساب',
                        'I’ve registered — enter my ID',
                      )
                    : tr('افتح موقع التسجيل', 'Open the sign-up site'),
                // السهم يتبع اتجاه اللغة
                icon: _regOpened
                    ? Icons.arrow_forward_rounded
                    : Icons.open_in_new_rounded,
                height: 54,
                attention: true,
                onPressed: _openSite,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PillButton(
                    key: const ValueKey('reg-primary'),
                    label: _appCopied
                        ? tr(
                            'سجّلت — أدخل رقم الحساب',
                            'I’ve registered — enter my ID',
                          )
                        : tr('انسخ رمز الترويج', 'Copy the promo code'),
                    icon: _appCopied
                        ? Icons.arrow_forward_rounded
                        : Icons.copy_rounded,
                    height: 54,
                    attention: true,
                    onPressed: _copyForApp,
                  ),
                  const SizedBox(height: 10),
                  _OutlineBar(
                    key: const ValueKey('reg-secondary'),
                    label: tr(
                      'التطبيق مش عندك؟ سجّل من الموقع',
                      'No app? Sign up on the website',
                    ),
                    onTap: () => _pickMethod(_Method.web),
                  ),
                ],
              ),
      _Ob.activate => PillButton(
        key: const ValueKey('cta-primary'),
        label: tr('تسجيل الدخول', 'Sign in'),
        icon: AppPrefs.instance.isEn
            ? Icons.arrow_forward_rounded
            : Icons.arrow_back_rounded,
        loading: _isSubmitting,
        height: 54,
        attention: _s2 && _idError == null,
        onPressed: _submit,
      ),
    };
    final bottom = MediaQuery.of(context).padding.bottom;
    return Entrance(
      parent: _enter,
      begin: 0.35,
      end: 1,
      dy: 24,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0),
              Colors.black.withValues(alpha: 0.96),
            ],
            stops: const [0, 0.35],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, 14, 0, 10 + bottom),
          child: Center(
            child: SizedBox(width: content, child: body),
          ),
        ),
      ),
    );
  }
}

// ── شريط الخطوات: الحساب ثم التفعيل ثم الوصول الى الاداة ────────
class _StepsBar extends StatelessWidget {
  final int current;
  final bool accountDone;
  const _StepsBar({required this.current, required this.accountDone});

  @override
  Widget build(BuildContext context) {
    final labels = [
      tr('الحساب', 'Account'),
      tr('التفعيل', 'Activation'),
      tr('الوصول إلى الأداة', 'Tool access'),
    ];
    String state(int i) {
      if (i == 2) return 'lock';
      if (i == current) return 'cur';
      if (i == 0 && (accountDone || current > 0)) return 'done';
      return i < current ? 'done' : 'todo';
    }

    final items = <Widget>[];
    for (var i = 0; i < 3; i++) {
      final st = state(i);
      items.add(
        SizedBox(
          width: 78,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                key: ValueKey('login-step-$i'),
                duration: Motion.medium,
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: switch (st) {
                    'cur' => kEmerald,
                    'done' => kEmerald.withValues(alpha: 0.16),
                    _ => kInk.withValues(alpha: 0.6),
                  },
                  border: Border.all(
                    color: st == 'todo' || st == 'lock'
                        ? kWhite.withValues(alpha: 0.2)
                        : kEmerald.withValues(alpha: 0.8),
                  ),
                  boxShadow: st == 'cur'
                      ? [
                          BoxShadow(
                            color: kEmerald.withValues(alpha: 0.45),
                            blurRadius: 14,
                          ),
                        ]
                      : null,
                ),
                child: switch (st) {
                  'done' => Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: kEmerald,
                  ),
                  'lock' => Icon(
                    Icons.lock_rounded,
                    size: 14,
                    color: kWhiteFaint,
                  ),
                  _ => Text(
                    '${i + 1}',
                    textDirection: TextDirection.ltr,
                    style: markText(
                      st == 'cur' ? kOnEmerald : kWhiteSoft,
                      13,
                      weight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                },
              ),
              const SizedBox(height: 5),
              Text(
                labels[i],
                maxLines: 2,
                textAlign: TextAlign.center,
                style: bodyText(
                  st == 'cur'
                      ? kEmeraldPale
                      : (st == 'done' ? kWhite : kWhiteFaint),
                  10.5,
                  weight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      );
      if (i < 2) {
        items.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 15),
              child: AnimatedContainer(
                duration: Motion.slow,
                height: 1.4,
                color: state(i) == 'done'
                    ? kEmerald.withValues(alpha: 0.8)
                    : kWhite.withValues(alpha: 0.16),
              ),
            ),
          ),
        );
      }
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: items);
  }
}

// ── رسمة فورم التسجيل في موقع المنصة ───────────────────────────
/// فورم فاتح مثل موقع المنصة كما في gpt: ارقام الخطوات في دوائر فاتحة على
/// البداية بينها خط رأسي، ثم «تسجيل الدخول» ازرق و«التسجيل» اخضر بحلقة حمراء
/// حوله، ثم «بنقرة واحدة»، ثم رمز الترويج مكتوبا وتحته خط، ثم زر التسجيل.
class _SignupMock extends StatelessWidget {
  const _SignupMock();

  static const Color _paper = Color(0xFFF7F9FC);
  static const Color _ink = Color(0xFF1B2A4A);
  static const Color _line = Color(0xFFDCE3EE);
  static const Color _green = Color(0xFF3DB35A);
  static const Color _blue = Color(0xFF4A90E2);

  static const double _rowH = 46;
  static const double _gap = 12;

  Widget _box(Widget child, {Color? fill, Color? edge, double? h}) => Container(
    height: h ?? _rowH,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: fill ?? Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: edge ?? _line, width: 1.2),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final bold = bodyText(_ink, 12.5, weight: FontWeight.w700, height: 1.2);
    final rows = <Widget>[
      // 1: تسجيل الدخول | التسجيل وحوله حلقة حمراء
      Row(
        children: [
          Expanded(
            child: _box(
              Text(
                tr('تسجيل الدخول', 'Log in'),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: bodyText(
                  Colors.white,
                  11.5,
                  weight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              fill: _blue,
              edge: _blue,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFE53935), width: 2),
              ),
              child: Container(
                height: _rowH - 5,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(24),
                ),
                // الكلمة كاملة دائما: تصغر بدل ان تُقص
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tr('التسجيل', 'Registration'),
                    maxLines: 1,
                    style: bodyText(
                      Colors.white,
                      11.5,
                      weight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // 2: بنقرة واحدة
      _box(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE6F0FC),
              ),
              child: const Icon(Icons.bolt_rounded, size: 16, color: _blue),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                tr('بنقرة واحدة', 'One-click'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bold,
              ),
            ),
          ],
        ),
      ),
      // 3: رمز الترويج مكتوبا وتحته خط
      Container(
        height: _rowH + 12,
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              tr('رمز الترويج (إن وُجد)', 'Promo code (if you have one)'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bodyText(const Color(0xFF7A8699), 9.5, height: 1.2),
            ),
            Text(
              kPromoCode,
              textDirection: TextDirection.ltr,
              textAlign: AppPrefs.instance.isEn
                  ? TextAlign.left
                  : TextAlign.right,
              style: bodyText(_ink, 16, weight: FontWeight.w800, height: 1.2),
            ),
            Container(height: 1.4, color: _blue.withValues(alpha: 0.7)),
          ],
        ),
      ),
      // 4: زر التسجيل داخل صندوق
      Container(
        height: _rowH + 4,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line, width: 1.2),
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            tr('تسجيل', 'Register'),
            style: bodyText(
              Colors.white,
              12.5,
              weight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: kEmerald.withValues(alpha: 0.16),
            blurRadius: 24,
            spreadRadius: -8,
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // عمود الارقام وبينها خط رأسي
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0)
                      Expanded(
                        child: Center(
                          child: Container(width: 1.4, color: _line),
                        ),
                      ),
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEEF3FA),
                        border: Border.all(color: const Color(0xFFC9D6EA)),
                      ),
                      child: Text(
                        '${i + 1}',
                        textDirection: TextDirection.ltr,
                        style: bodyText(
                          _ink,
                          12.5,
                          weight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const SizedBox(height: _gap),
                    rows[i],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// خطوات التسجيل الاربع بجوار الرسمة: رقم في دائرة بحلقة لون المنصة،
/// والكلمة المهمة عريضة
class _SignupSteps extends StatelessWidget {
  final bool compact;
  const _SignupSteps({required this.compact});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (tr('اضغط زر ', 'Tap '), tr('التسجيل', 'Registration')),
      (tr('اختر ', 'Choose '), tr('بنقرة واحدة', 'One-click')),
      (tr('أدخل رمز الترويج ', 'Enter promo code '), kPromoCode),
      (tr('اضغط ', 'Tap '), tr('تسجيل', 'Register')),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kInk.withValues(alpha: 0.6),
                    border: Border.all(
                      color: kEmerald.withValues(alpha: 0.75),
                      width: 1.6,
                    ),
                  ),
                  child: Text(
                    '${i + 1}',
                    textDirection: TextDirection.ltr,
                    style: bodyText(
                      kEmeraldPale,
                      14,
                      weight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: steps[i].$1),
                        TextSpan(
                          text: steps[i].$2,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    style: bodyText(kWhite, compact ? 14 : 15, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── رسمة الملف الشخصي: مكان رقم الحساب ─────────────────────────
/// صفحة «الملف الشخصي» في موقع المنصة: رقم الحساب في صندوق متقطع، واسم
/// مستخدم مموّه
class _ProfileMock extends StatelessWidget {
  const _ProfileMock();

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1B2433);
    const mute = Color(0xFF6B7686);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F7),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFF1A4F8B),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                const Icon(Icons.person_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  tr('الملف الشخصي', 'Personal profile'),
                  style: bodyText(
                    Colors.white,
                    12,
                    weight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr('الحساب', 'Account'),
                  style: bodyText(
                    mute,
                    10.5,
                    weight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                CustomPaint(
                  painter: _DashedRRectPainter(color: kEmerald),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          tr('رقم الحساب', 'Account number'),
                          style: bodyText(
                            ink,
                            11.5,
                            weight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'id: 12345678',
                          textDirection: TextDirection.ltr,
                          style: bodyText(
                            ink,
                            13,
                            weight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        tr('اسم المستخدم', 'Username'),
                        style: bodyText(mute, 11, height: 1.2),
                      ),
                      const Spacer(),
                      ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                        child: Text(
                          'ahmed.m_88',
                          textDirection: TextDirection.ltr,
                          style: bodyText(
                            ink,
                            12,
                            weight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
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

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  const _DashedRRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1),
      const Radius.circular(9),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = color;
    final path = Path()..addRRect(rrect);
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 6, m.length)), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) => old.color != color;
}

/// زر دائري صغير فوق الصورة
class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RoundIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: _PressScale(
        onTap: onTap,
        down: 0.9,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kInk.withValues(alpha: 0.6),
            border: Border.all(color: kEmerald.withValues(alpha: 0.5)),
          ),
          child: Icon(icon, size: 20, color: kWhite),
        ),
      ),
    );
  }
}

// ── اتفاقية المستخدم ───────────────────────────────────────────
class _AgreementSheet extends StatelessWidget {
  const _AgreementSheet();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: kInk.withValues(alpha: 0.7),
      builder: (_) => const _AgreementSheet(),
    );
  }

  static List<(String, String)> get _sections => [
    (
      tr('1. ما هي الخدمة', '1. What the service is'),
      tr(
        '1.1. JoeX PRO («الخدمة») أداة ترفيهية على أندرويد.\n'
            '1.2. الخانة التي تظهر في كل صف تختارها الخدمة عشوائيًا. وهي ليست توقعًا لنتيجة أي لعبة وليست نصيحة بالمراهنة.\n'
            '1.3. «المنصة» هي الموقع المستقل التابع لطرف ثالث الذي تسجّل فيه عبر رابطنا. JoeX PRO ليس المنصة، ولا يحتفظ بأموالك، ولا يدير ألعابها.',
        '1.1. JoeX PRO (“the Service”) is an entertainment tool for Android.\n'
            '1.2. The cell shown in each row is picked by the Service at random. It is not a prediction of any game’s result and not betting advice.\n'
            '1.3. The “Platform” is the independent third-party site you register on through our link. JoeX PRO is not the Platform, does not hold your money and does not run its games.',
      ),
    ),
    (
      tr('2. الشراكة', '2. Partnership'),
      tr(
        '2.1. يشارك JoeX PRO في برنامج الشركاء الخاص بالمنصة وقد يحصل منها على عمولة عن الحسابات المفتوحة عبر روابطنا. ولا يغيّر ذلك سعر أي شيء تدفعه.',
        '2.1. JoeX PRO takes part in the Platform’s partner programme and may receive a commission for accounts opened through our links. This does not change the price of anything you pay.',
      ),
    ),
    (
      tr('3. المخاطر', '3. Risks'),
      tr(
        '3.1. ألعاب الحظ تحمل مستوى عاليًا من المخاطر وقد تؤدي إلى خسارة كل المال الذي تضعه. العب فقط بمال تستطيع تحمّل خسارته.\n'
            '3.2. الاختيارات عشوائية. النتائج السابقة لا تضمن النتائج المستقبلية، ولا يوجد اختيار مضمون الصحة.\n'
            '3.3. أنت وحدك تقرر هل تلعب وبكم، وأنت وحدك تتحمل النتيجة.',
        '3.1. Games of chance carry a high risk and can lose you all the money you put in. Play only with money you can afford to lose.\n'
            '3.2. The picks are random. Past results do not guarantee future ones, and no pick is guaranteed to be right.\n'
            '3.3. You alone decide whether to play and how much, and you alone bear the result.',
      ),
    ),
    (
      tr('4. حسابك وبياناتك', '4. Your account and data'),
      tr(
        '4.1. رقم حسابك والكود محفوظان على جهازك فقط. لا نطلب أبدًا كلمة مرور حسابك على المنصة.\n'
            '4.2. لا تشارك وصولك مع الآخرين.',
        '4.1. Your account number and code are kept on your device only. We never ask for your Platform password.\n'
            '4.2. Do not share your access with others.',
      ),
    ),
    (
      tr('5. الأهلية', '5. Eligibility'),
      tr(
        '5.1. يجب أن يكون عمرك 18 عامًا على الأقل وأن يسمح لك قانون بلدك بالمشاركة في ألعاب الحظ.',
        '5.1. You must be at least 18 and allowed by the law of your country to take part in games of chance.',
      ),
    ),
    (
      tr('6. المسؤولية', '6. Liability'),
      tr(
        '6.1. تُقدَّم الخدمة «كما هي». وفي الحدود التي يسمح بها القانون، لا يتحمل JoeX PRO مسؤولية الخسائر أو تصرفات المنصة.',
        '6.1. The Service is provided “as is”. To the extent the law allows, JoeX PRO is not liable for losses or for the Platform’s actions.',
      ),
    ),
    (
      tr('7. التواصل', '7. Contact'),
      tr(
        '7.1. الدعم على تليجرام: t.me/joe27',
        '7.1. Support on Telegram: t.me/joe27',
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Directionality(
      textDirection: appDir,
      child: Container(
        constraints: BoxConstraints(maxHeight: h * 0.86),
        decoration: BoxDecoration(
          color: kCoal,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: kEmerald.withValues(alpha: 0.6)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kWhite.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Text(
                  tr(
                    'JoeX PRO — اتفاقية المستخدم',
                    'JoeX PRO — User Agreement',
                  ),
                  style: headText(kWhite, 18, height: 1.3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  tr('الإصدار: 24 نوفمبر 2026', 'Version: 24 November 2026'),
                  style: bodyText(kMist, 11.5),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final s in _sections) ...[
                        Text(
                          s.$1,
                          style: headText(kEmeraldPale, 14, height: 1.4),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.$2,
                          style: bodyText(kWhiteSoft, 12.5, height: 1.6),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: PillButton(
                  key: const ValueKey('agreement-done'),
                  label: tr('العودة للتسجيل', 'Back to sign-up'),
                  height: 50,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// حقل في صندوق: وسمه وايقونته في سطر صغير اعلاه، والقيمة تحته. الحافة
/// تبيضّ مع التركيز وتحمر مع الخطأ، وعلامة صح فضية حين يكتمل
class _BoxField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final String? error;
  final bool done;
  final int shake;
  final TextInputAction action;
  final TextInputType? keyboard;
  final ValueChanged<String> onSubmitted;

  const _BoxField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.error,
    required this.done,
    required this.shake,
    required this.action,
    required this.onSubmitted,
    this.keyboard,
  });

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;
    final bad = error != null;
    final edge = bad
        ? kRose.withValues(alpha: 0.8)
        : focused
        ? kEmerald.withValues(alpha: 0.7)
        : kWhite.withValues(alpha: 0.09);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Shake(
          trigger: shake,
          child: AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.standard,
            padding: const EdgeInsetsDirectional.fromSTEB(12, 9, 12, 2),
            decoration: BoxDecoration(
              color: kInk.withValues(alpha: focused ? 0.6 : 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: edge, width: focused || bad ? 1.3 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color: bad ? kRose : (focused ? kEmerald : kWhiteFaint),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: bodyText(
                        focused ? kEmerald : kWhiteFaint,
                        11,
                        weight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: Motion.medium,
                      switchInCurve: Motion.overshoot,
                      transitionBuilder: (child, a) =>
                          ScaleTransition(scale: a, child: child),
                      child: done && !bad
                          ? Container(
                              key: const ValueKey('ok'),
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: kEmeraldGradient,
                                ),
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                size: 12,
                                color: kOnEmerald,
                              ),
                            )
                          : const SizedBox(key: ValueKey('no'), height: 18),
                    ),
                  ],
                ),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: action,
                  keyboardType: keyboard,
                  onSubmitted: onSubmitted,
                  cursorColor: kEmerald,
                  scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
                  style: bodyText(
                    kWhite,
                    16,
                    weight: FontWeight.w500,
                    height: 1.3,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: bodyText(kWhiteFaint, 14, height: 1.3),
                    contentPadding: const EdgeInsets.only(top: 6, bottom: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: Motion.medium,
          curve: Motion.emphasized,
          alignment: Alignment.topCenter,
          child: error == null
              ? const SizedBox(width: double.infinity)
              : FaultLine(error!),
        ),
      ],
    );
  }
}

/// منصة في خانة مربعة داكنة: ايقونتها وحدها في الوسط. المختارة بحافة لونها
/// ووهجه وعلامة صح في ركن البداية العلوي، كما في gpt
class _PlatformTile extends StatelessWidget {
  final int index;
  final String asset;
  final String badge;
  final String name;

  /// لون المنصة نفسها: حافتها ووهجها حين تُختار
  final Color glow;
  final bool selected;
  final VoidCallback onTap;

  const _PlatformTile({
    super.key,
    required this.index,
    required this.asset,
    required this.badge,
    required this.name,
    required this.glow,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // الاسم لقارئ الشاشة فقط: على الشاشة الايقونة وحدها
    return Semantics(
      label: name,
      button: true,
      selected: selected,
      child: _PressScale(
        onTap: onTap,
        down: 0.94,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: Motion.medium,
              curve: Motion.standard,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? glow.withValues(alpha: 0.12)
                    : kWhite.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? glow : kWhite.withValues(alpha: 0.1),
                  width: selected ? 2 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: glow.withValues(alpha: 0.4),
                          blurRadius: 18,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      asset,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => Center(
                        child: Text(
                          badge,
                          textDirection: TextDirection.ltr,
                          style: markText(kWhiteSoft, 14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 4,
              start: 4,
              child: AnimatedScale(
                duration: Motion.medium,
                curve: Motion.overshoot,
                scale: selected ? 1 : 0,
                child: Container(
                  key: selected ? ValueKey('platform-$index-on') : null,
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: glow,
                    border: Border.all(color: kWhite, width: 1.4),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ايقونة في دائرة بلون المنصة داخل حلقة، مثل كارت «افتح حسابك»
class _IconDisc extends StatelessWidget {
  final IconData icon;
  const _IconDisc({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kEmerald.withValues(alpha: 0.45), width: 1.4),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kEmerald,
          boxShadow: [
            BoxShadow(color: kEmerald.withValues(alpha: 0.45), blurRadius: 16),
          ],
        ),
        child: Icon(icon, color: kOnEmerald, size: 26),
      ),
    );
  }
}

/// خانة طريقة التسجيل: ايقونة في دائرة، الاسم والوصف، ووسم صغير. المختارة
/// بحافة لون المنصة ووهجه وعلامة صح
class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String tag;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: _PressScale(
        onTap: onTap,
        down: 0.96,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.standard,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: selected
                ? kEmerald.withValues(alpha: 0.12)
                : kCoal.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? kEmerald : kWhite.withValues(alpha: 0.1),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: kEmerald.withValues(alpha: 0.3),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? kEmerald
                          : kEmerald.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      icon,
                      size: 21,
                      color: selected ? kOnEmerald : kEmerald,
                    ),
                  ),
                  const Spacer(),
                  AnimatedScale(
                    duration: Motion.medium,
                    curve: Motion.overshoot,
                    scale: selected ? 1 : 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kEmerald,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: kOnEmerald,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(title, style: headText(kWhite, 16, height: 1.3)),
              const SizedBox(height: 2),
              Text(subtitle, style: bodyText(kMist, 12, height: 1.4)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kWhite.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  tag,
                  style: bodyText(
                    selected ? kEmeraldPale : kWhiteFaint,
                    10.5,
                    weight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// كارت رمز الترويج: الرمز كبير وبجواره زر نسخ
class _PromoChip extends StatelessWidget {
  final Future<void> Function() onCopy;
  const _PromoChip({required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 10, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [
            kEmerald.withValues(alpha: 0.16),
            kEmerald.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: kEmerald.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.local_offer_rounded, size: 20, color: kEmerald),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('رمز الترويج', 'Promo code'),
                  style: bodyText(kMist, 11.5, height: 1.2),
                ),
                Text(
                  kPromoCode,
                  textDirection: TextDirection.ltr,
                  // بخط عادي: خط الاسم يكتب الصغيرة كبيرة فيُكتب الرمز خطأ
                  style: bodyText(
                    kWhite,
                    22,
                    weight: FontWeight.w700,
                    height: 1.25,
                  ).copyWith(letterSpacing: 1.2),
                ),
              ],
            ),
          ),
          _PressScale(
            key: const ValueKey('promo-copy'),
            onTap: onCopy,
            down: 0.94,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: kEmerald,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded, size: 16, color: kOnEmerald),
                  const SizedBox(width: 6),
                  Text(
                    tr('نسخ', 'Copy'),
                    style: bodyText(
                      kOnEmerald,
                      13,
                      weight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// خطوات على خط زمني: رقم في دائرة بحلقة لون المنصة، وخط ينزل منه الى
/// التالي، وبجواره العنوان ووصف قصير
class _Timeline extends StatelessWidget {
  final List<(String, String)> items;

  /// ايقونات بدل الارقام: لخطوات تمهيدية لا تُعد مع خطوات الفورم
  final List<IconData>? icons;
  const _Timeline({required this.items, this.icons});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 34,
                  child: Column(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kInk.withValues(alpha: 0.6),
                          border: Border.all(
                            color: kEmerald.withValues(alpha: 0.75),
                            width: 1.6,
                          ),
                        ),
                        child: icons != null
                            ? Icon(icons![i], size: 17, color: kEmeraldPale)
                            : Text(
                                '${i + 1}',
                                textDirection: TextDirection.ltr,
                                style: bodyText(
                                  kEmeraldPale,
                                  14,
                                  weight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                      ),
                      if (i < items.length - 1)
                        Expanded(
                          child: Container(
                            width: 1.6,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: kEmerald.withValues(alpha: 0.3),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 5,
                      bottom: i < items.length - 1 ? 16 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].$1,
                          style: headText(kWhite, 14.5, height: 1.35),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].$2,
                          style: bodyText(kMist, 12.5, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// زر ثانوي بعرض كامل: حافة لون المنصة ونصه بلونها على خلفية داكنة
class _OutlineBar extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBar({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: onTap,
      down: 0.98,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: kInk.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: kEmerald.withValues(alpha: 0.6),
            width: 1.4,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: bodyText(kEmeraldPale, 15, weight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// ضغطة تنكمش ثم تعود بارتداد خفيف
class _PressScale extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final double down;
  const _PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.down = 0.96,
  });

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: widget.onTap == null ? null : (_) => _set(true),
    onTapUp: widget.onTap == null ? null : (_) => _set(false),
    onTapCancel: () => _set(false),
    onTap: widget.onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedScale(
      duration: _pressed ? Motion.fast : Motion.medium,
      curve: _pressed ? Motion.standard : Motion.overshoot,
      scale: _pressed ? widget.down : 1,
      child: widget.child,
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
// الاشتراك الاجباري — بطاقة مخملية يعلوها وسام الشعار نصفه خارجها، وحلقته
// تمتلئ بالذهب مع كل شرط. الشروط الثلاثة على خيط عمودي من العملات، لكل منها
// اسمه ومعرّفه وزره، ثم التحقق.
// ═══════════════════════════════════════════════════════════════
class MandatorySubscriptionDialog extends StatefulWidget {
  final VoidCallback onSubscriptionVerified;

  const MandatorySubscriptionDialog({
    super.key,
    required this.onSubscriptionVerified,
  });

  /// تفتح النافذة في الوسط: تظهر وتكبر قليلا بينما تغيم الشاشة خلفها
  static Future<void> show(
    BuildContext context, {
    required VoidCallback onSubscriptionVerified,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'SubscriptionDialog',
      barrierColor: kInk.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (c, _, _) => MandatorySubscriptionDialog(
        onSubscriptionVerified: onSubscriptionVerified,
      ),
      transitionBuilder: (c, a, _, child) {
        final v = CurvedAnimation(
          parent: a,
          curve: Motion.emphasized,
          reverseCurve: Motion.accelerate,
        );
        return AnimatedBuilder(
          animation: v,
          builder: (context, inner) => BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: 10 * v.value,
              sigmaY: 10 * v.value,
            ),
            child: inner,
          ),
          child: FadeTransition(
            opacity: v,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(v),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  State<MandatorySubscriptionDialog> createState() =>
      _MandatorySubscriptionDialogState();
}

class _MandatorySubscriptionDialogState
    extends State<MandatorySubscriptionDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  bool _clickedYoutube = false;
  bool _clickedTelegram = false;
  bool _clickedVideo = false;
  bool _isCheckingVideo = false;
  DynamicActionConfig _actionConfig = DynamicActionConfig.defaultConfig();
  String? _errorMsg;
  int _errorShake = 0;

  @override
  void initState() {
    super.initState();
    _loadDynamicConfig();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionAllowed(context) && !_spin.isAnimating) _spin.repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _loadDynamicConfig() async {
    final cached = await DynamicLinkService.getCachedConfig();
    if (mounted) setState(() => _actionConfig = cached);
    final latest = await DynamicLinkService.fetchLatestConfig();
    if (mounted) setState(() => _actionConfig = latest);
  }

  Future<void> _openChannelUrl(String url, String key) async {
    setState(() {
      if (key == 'yt') _clickedYoutube = true;
      if (key == 'tg') _clickedTelegram = true;
      _errorMsg = null;
    });
    await openUrl(url);
  }

  Future<void> _handleThirdAction(String url) async {
    if (_isCheckingVideo) return;
    if (_clickedVideo) {
      await openUrl(url);
      return;
    }

    setState(() {
      _isCheckingVideo = true;
      _errorMsg = null;
    });

    await openUrl(url);
    await Future.delayed(const Duration(seconds: 5));

    if (mounted) {
      setState(() {
        _isCheckingVideo = false;
        _clickedVideo = true;
        _errorMsg = null;
      });
    }
  }

  void _verify() {
    if (_isCheckingVideo) {
      setState(() {
        _errorMsg = tr(
          'جاري التحقق من التفاعل... يرجى الانتظار ⏳',
          'Checking your action... please wait ⏳',
        );
        _errorShake++;
      });
      return;
    }
    if (!_clickedYoutube || !_clickedTelegram || !_clickedVideo) {
      setState(() {
        _errorMsg = tr(
          'يرجى إكمال جميع الشروط الـ 3 أولاً',
          'Please complete all 3 steps first',
        );
        _errorShake++;
      });
      return;
    }
    Navigator.of(context).pop();
    widget.onSubscriptionVerified();
  }

  @override
  Widget build(BuildContext context) {
    final steps = [_clickedYoutube, _clickedTelegram, _clickedVideo];
    final done = steps.where((s) => s).length;
    final complete = done == 3;
    final pending = steps.indexWhere((s) => !s);
    const medal = 108.0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            type: MaterialType.transparency,
            child: Directionality(
              textDirection: appDir,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: medal / 2),
                    child: VelvetCard(
                      glow: true,
                      padding: const EdgeInsets.fromLTRB(
                        18,
                        medal / 2 + 12,
                        18,
                        18,
                      ),
                      child: StaggerIn(
                        duration: const Duration(milliseconds: 820),
                        children: [
                          Text(
                            tr('اشتراك إجباري', 'Required subscription'),
                            textAlign: TextAlign.center,
                            style: headText(kWhite, 24, height: 1.25),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr(
                              'يشترط إكمال الشروط الـ 3 للمتابعة وتفعيل الأداة',
                              'Complete the 3 steps to continue and activate the tool',
                            ),
                            textAlign: TextAlign.center,
                            style: bodyText(kMist, 12),
                          ),
                          const SizedBox(height: 12),
                          const Center(child: GoldRule(width: 150)),
                          const SizedBox(height: 16),
                          _condition(
                            index: 0,
                            title: tr('قناة اليوتيوب', 'YouTube channel'),
                            subtitle: kYoutubeHandle,
                            icon: Icons.play_arrow_rounded,
                            isClicked: _clickedYoutube,
                            active: pending == 0,
                            onTap: () => _openChannelUrl(kYoutubeUrl, 'yt'),
                          ),
                          _condition(
                            index: 1,
                            title: tr('قناة التليجرام', 'Telegram channel'),
                            subtitle: kTelegramHandle,
                            icon: Icons.telegram,
                            isClicked: _clickedTelegram,
                            active: pending == 1,
                            onTap: () =>
                                _openChannelUrl(kTelegramUrl, 'tg'),
                          ),
                          _condition(
                            index: 2,
                            last: true,
                            title: _actionConfig.displayTitle,
                            subtitle: _actionConfig.displaySubtitle,
                            icon: _actionConfig.icon,
                            isClicked: _clickedVideo,
                            isLoading: _isCheckingVideo,
                            active: pending == 2,
                            defaultButtonText:
                                _actionConfig.actionType == 'comment'
                                ? tr('تعليق', 'Comment')
                                : _actionConfig.actionType == 'subscribe'
                                ? tr('اشتراك', 'Subscribe')
                                : tr('لايك', 'Like'),
                            completedButtonText: tr(
                              'تم التحقق ✓',
                              'Verified ✓',
                            ),
                            loadingButtonText: tr(
                              'جاري التحقق...',
                              'Checking...',
                            ),
                            onTap: () => _handleThirdAction(_actionConfig.url),
                          ),
                          AnimatedSize(
                            duration: Motion.medium,
                            curve: Motion.emphasized,
                            alignment: Alignment.topCenter,
                            child: _errorMsg == null
                                ? const SizedBox(width: double.infinity)
                                : Shake(
                                    trigger: _errorShake,
                                    child: FaultLine(_errorMsg!),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          PillButton(
                            label: tr('تحقق ومتابعة', 'Verify and continue'),
                            icon: complete
                                ? Icons.check_rounded
                                : Icons.done_all_rounded,
                            height: 54,
                            attention: complete,
                            onPressed: _verify,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // الوسام نصفه فوق البطاقة، وحلقته تمتلئ مع الشروط
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: SizedBox.square(
                        dimension: medal,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: done / 3),
                          duration: Motion.slow,
                          curve: Motion.emphasized,
                          builder: (context, v, child) => AnimatedBuilder(
                            animation: _spin,
                            builder: (context, c) => CustomPaint(
                              painter: MedallionPainter(
                                draw: 1,
                                spin: _spin.value,
                                progress: v,
                                inner: medal * 0.33,
                              ),
                              child: c,
                            ),
                            child: child,
                          ),
                          child: Center(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: kInk,
                                boxShadow: [
                                  BoxShadow(
                                    color: kJade.withValues(alpha: 0.5),
                                    blurRadius: 22,
                                  ),
                                ],
                              ),
                              child: const BrandLogo(size: medal * 0.66),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// شرط على الخيط: عملة على اليمين وخيط ينزل منها الى التالي، ثم شريحة
  /// فيها الاسم ومعرّفه وزر في كبسولة تذهب عند الاكتمال
  Widget _condition({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isClicked,
    required bool active,
    required VoidCallback onTap,
    bool last = false,
    bool isLoading = false,
    String? defaultButtonText,
    String? completedButtonText,
    String? loadingButtonText,
  }) {
    defaultButtonText ??= tr('انضمام', 'Join');
    completedButtonText ??= tr('تم الانضمام', 'Joined');
    loadingButtonText ??= tr('جاري التحقق...', 'Checking...');
    final isDone = isClicked && !isLoading;
    final handle = subtitle.startsWith('@');
    final actionLabel = isLoading
        ? loadingButtonText
        : isDone
        ? completedButtonText
        : defaultButtonText;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Coin(
                  size: 34,
                  active: active || isLoading,
                  done: isDone,
                  label: isLoading
                      ? SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: kEmerald,
                          ),
                        )
                      : Icon(
                          isDone ? Icons.check_rounded : icon,
                          size: 15,
                          color: Coin.ink(
                            active: active || isLoading,
                            done: isDone,
                          ),
                        ),
                ),
                if (!last)
                  Expanded(
                    child: AnimatedContainer(
                      duration: Motion.slow,
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1),
                        color: isDone
                            ? kEmerald.withValues(alpha: 0.8)
                            : kWhite.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 10),
              child: _PressScale(
                onTap: isLoading ? null : onTap,
                down: 0.975,
                child: AnimatedContainer(
                  duration: Motion.medium,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: isDone
                        ? kEmerald.withValues(alpha: 0.08)
                        : kInk.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDone
                          ? kEmerald.withValues(alpha: 0.6)
                          : (active
                                ? kJade.withValues(alpha: 0.7)
                                : kWhiteLine),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: headText(kWhite, 14, height: 1.35),
                            ),
                            if (subtitle.isNotEmpty)
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textDirection: handle
                                    ? TextDirection.ltr
                                    : appDir,
                                style: bodyText(
                                  kWhiteFaint,
                                  handle ? 11 : 10.5,
                                  weight: handle
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  height: 1.35,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: Motion.medium,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          gradient: isDone
                              ? LinearGradient(colors: kEmeraldGradient)
                              : null,
                          border: Border.all(
                            color: isLoading
                                ? kWhiteLine
                                : kEmerald.withValues(alpha: isDone ? 0 : 0.75),
                          ),
                        ),
                        child: ClipRect(
                          child: AnimatedSwitcher(
                            duration: Motion.swap,
                            transitionBuilder: slideSwapTransition,
                            child: Text(
                              actionLabel,
                              key: ValueKey(actionLabel),
                              style: bodyText(
                                isLoading
                                    ? kWhiteFaint
                                    : (isDone ? kOnEmerald : kEmerald),
                                11,
                                weight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
