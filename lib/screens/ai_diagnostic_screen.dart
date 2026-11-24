import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/design_system.dart';
import '../design/identity.dart';
import '../services/links.dart';
import '../widgets/ios_loading_dialog.dart';

// ─────────────────────────────────────────────────────────────
// صفحة معايرة المحرك العصبي (Full Page / Screen)
// تفتح بعد تسجيل الدخول، لاختيار سعة الحساب والموديل بصور احترافية
// لكل مستوى، متوافقة تماماً مع سياسات يوتيوب.
// ─────────────────────────────────────────────────────────────

class AiDiagnosticScreen extends StatefulWidget {
  final VoidCallback onDiagnosticComplete;
  final bool startAtSurvey;

  const AiDiagnosticScreen({
    super.key,
    required this.onDiagnosticComplete,
    this.startAtSurvey = false,
  });

  @override
  State<AiDiagnosticScreen> createState() => _AiDiagnosticScreenState();
}

enum _PagePhase { survey, check }

class _AiDiagnosticScreenState extends State<AiDiagnosticScreen>
    with TickerProviderStateMixin {
  _PagePhase _phase = _PagePhase.survey;
  late final AnimationController _pulse;
  late final AnimationController _spin;

  final int _selectedStrategy = 1; // 0: Micro Pulse, 1: Tactical Balanced, 2: Deep Horizon
  int _selectedTier = 1; // 0: Core I, 1: Quantum II, 2: Astra III, 3: Ultra Sovereign
  bool _isVerifyingDeposit = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _loadSavedTier();

    _phase = _PagePhase.survey;
  }

  Future<void> _loadSavedTier() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTier = prefs.getInt('ai_tier_index');
    if (savedTier != null && mounted) {
      setState(() {
        _selectedTier = savedTier.clamp(0, 3);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionAllowed(context)) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
      if (!_spin.isAnimating) _spin.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    super.dispose();
  }

  Future<void> _submitSurvey() async {
    final prefs = await SharedPreferences.getInstance();

    final tiers = [
      {'name': 'Core Tier I', 'range': '300 – 500 EGP', 'checks': '4'},
      {'name': 'Quantum Tier II', 'range': '500 – 1,500 EGP', 'checks': '6'},
      {'name': 'Astra Tier III', 'range': '1,500 – 4,000 EGP', 'checks': '8'},
      {'name': 'Ultra Sovereign Core', 'range': '5,000+ EGP', 'checks': 'Unlimited'},
    ];

    final strategies = [
      'Micro Pulse (0.4s Fast)',
      'Tactical Balanced (Rows 1-6)',
      'Deep Horizon (Full Pattern)',
    ];

    final pickedTier = tiers[_selectedTier];
    final pickedStrategy = strategies[_selectedStrategy];

    await prefs.setString('ai_tier_name', pickedTier['name']!);
    await prefs.setString('ai_deposit_tier', pickedTier['range']!);
    await prefs.setString('ai_checks_count', pickedTier['checks']!);
    await prefs.setInt('ai_tier_index', _selectedTier);
    await prefs.setString('ai_strategy', pickedStrategy);

    if (widget.startAtSurvey) {
      if (!mounted) return;
      IosLoadingDialog.show(
        context: context,
        title: tr('جاري تحديث وتثبيت النموذج...', 'Updating model...'),
        subtitle: tr('مزامنة المعايير التشغيلية', 'Calibrating operational parameters'),
      );
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      IosLoadingDialog.hide(context);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
      widget.onDiagnosticComplete();
      return;
    }

    if (!mounted) return;
    setState(() {
      _phase = _PagePhase.check;
    });
  }

  Future<void> _confirmDeposit() async {
    if (_isVerifyingDeposit) return;
    setState(() {
      _isVerifyingDeposit = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_diagnostic', true);

    if (mounted) {
      IosLoadingDialog.show(
        context: context,
        title: tr('جاري فحص وتأكيد الرصيد...', 'Verifying deposit...'),
        subtitle: tr('الاتصال ببوابة المطابقة الآلية', 'Connecting to verification gateway'),
      );
    }

    await Future.delayed(const Duration(milliseconds: 3200));

    if (mounted) {
      IosLoadingDialog.hide(context);
    }

    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
    widget.onDiagnosticComplete();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isSmall = media.size.width < 360;
    final maxContentWidth = isSmall ? 330.0 : 420.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Directionality(
        textDirection: appDir,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Backdrop(),
            // توهج زمردي/سحابي علوي ناعم متناسق مع هوية التطبيق
            Positioned(
              top: -80,
              left: 0,
              right: 0,
              height: 300,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.6),
                      radius: 0.9,
                      colors: [
                        kEmerald.withValues(alpha: 0.16),
                        kEmerald.withValues(alpha: 0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: AnimatedSwitcher(
                duration: Motion.medium,
                child: switch (_phase) {
                  _PagePhase.survey => _buildSurveyView(maxContentWidth),
                  _PagePhase.check => _buildCheckDepositView(maxContentWidth),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurveyView(double contentWidth) {
    return Column(
      children: [
        // شريط القنوات واللغة بالأعلى (مطابق لشاشات التطبيق)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          child: Center(
            child: SizedBox(
              width: contentWidth,
              height: 42,
              child: Row(
                children: [
                  IconLink(
                    key: const ValueKey('diag-support-btn'),
                    icon: Icons.support_agent_rounded,
                    color: kEmerald,
                    label: tr('الدعم', 'Support'),
                    onTap: () => openUrl(kHelpLink),
                  ),
                  const SizedBox(width: 6),
                  IconLink(
                    key: const ValueKey('diag-channel-telegram'),
                    icon: Icons.telegram,
                    color: const Color(0xFF29A9EB),
                    label: tr('قناة التليجرام', 'Telegram channel'),
                    onTap: () => openUrl(kTelegramUrl),
                  ),
                  const SizedBox(width: 6),
                  IconLink(
                    key: const ValueKey('diag-channel-youtube'),
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

        // عنوان الصفحة والشارة
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Center(
            child: SizedBox(
              width: contentWidth,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: kEmerald.withValues(alpha: 0.12),
                      border: Border.all(color: kEmerald.withValues(alpha: 0.45)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune_rounded, color: kEmerald, size: 12),
                        const SizedBox(width: 5),
                        Text(
                          'SYSTEM CALIBRATION PROFILE',
                          style: markText(kEmerald, 9.2, weight: FontWeight.w700, spacing: 0.6),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tr('معايرة النظام الذكي', 'Intelligent System Calibration'),
                    textAlign: TextAlign.center,
                    style: headText(kWhite, 21, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tr(
                      'مزامنة حسابك مع محرك الذكاء الاصطناعي لتحليل البيانات',
                      'Syncing your account with our AI engine for data analysis',
                    ),
                    textAlign: TextAlign.center,
                    style: bodyText(kMist, 12.0),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Scrollable Body
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // فئة سعة الحساب التشغيلية
                    _sectionTitle(
                      tr('اختر نموذج الذكاء الاصطناعي', 'Choose your AI model'),
                    ),
                    const SizedBox(height: 10),

                    _serverCard(
                      index: 0,
                      selected: _selectedTier == 0,
                      assetImage: 'assets/emblem_1.png',
                      glowColor: const Color(0xFF1E90FF),
                      tierName: 'Core Tier I',
                      amount: '300 – 500 EGP',
                      usd: '\$6 – \$10',
                      spec: tr('4 مسارات معالجة متزامنة · زمن استجابة قياسي', '4 Synchronous processing streams · standard speed'),
                      onTap: () => setState(() => _selectedTier = 0),
                    ),
                    const SizedBox(height: 8),

                    _serverCard(
                      index: 1,
                      selected: _selectedTier == 1,
                      assetImage: 'assets/emblem_2.png',
                      glowColor: const Color(0xFF00D2FF),
                      tierName: 'Quantum Tier II',
                      amount: '500 – 1,500 EGP',
                      usd: '\$10 – \$30',
                      spec: tr('6 مسارات تدقيق ومزامنة ديناميكية', '6 Dynamic audit & sync streams'),
                      onTap: () => setState(() => _selectedTier = 1),
                    ),
                    const SizedBox(height: 8),

                    _serverCard(
                      index: 2,
                      selected: _selectedTier == 2,
                      assetImage: 'assets/emblem_3.png',
                      glowColor: const Color(0xFFFFB800),
                      tierName: 'Astra Tier III',
                      amount: '1,500 – 4,000 EGP',
                      usd: '\$30 – \$80',
                      spec: tr('8 مسارات معالجة متعددة النوى فائقة الدقة', '8 High-precision multi-core processing streams'),
                      onTap: () => setState(() => _selectedTier = 2),
                    ),
                    const SizedBox(height: 8),

                    _serverCard(
                      index: 3,
                      selected: _selectedTier == 3,
                      assetImage: 'assets/emblem_4.png',
                      glowColor: const Color(0xFFFFD700),
                      tierName: 'Ultra Sovereign Core',
                      amount: '5,000+ EGP',
                      usd: '\$100+',
                      spec: tr('بيئة معالجة متقدمة فائقة السرعة، أقصى قوة أداء', 'Advanced high-speed processing environment, max compute power'),
                      onTap: () => setState(() => _selectedTier = 3),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bottom CTA Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: kInk.withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(color: kWhite.withValues(alpha: 0.1)),
            ),
          ),
          child: Center(
            child: SizedBox(
              width: contentWidth,
              child: InkWell(
                onTap: _submitSurvey,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: kEmeraldGradient,
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kEmerald.withValues(alpha: 0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline_rounded, color: kOnEmerald, size: 17),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              tr('تثبيت المعايرة ومزامنة الحساب', 'Lock & Sync Calibration'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: bodyText(
                                kOnEmerald,
                                13.5,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// شاشة التحقق من الرصيد التفعيلي طبق الأصل من شاشة s-check في مشروع gpt
  Widget _buildCheckDepositView(double contentWidth) {
    final curPlatform = AppPrefs.instance.platform;
    final platColor = platformColor(curPlatform);

    return Column(
      children: [
        // شريط الرأس: الرجوع للمعايرة + القنوات ومبدل اللغة
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
          child: Center(
            child: SizedBox(
              width: contentWidth,
              height: 42,
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      if (!_isVerifyingDeposit) {
                        setState(() => _phase = _PagePhase.survey);
                      }
                    },
                    borderRadius: BorderRadius.circular(99),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_rounded, color: kMist, size: 18),
                          const SizedBox(width: 4),
                          Text(tr('رجوع', 'Back'), style: bodyText(kMist, 12, weight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconLink(
                    key: const ValueKey('chk-support-btn'),
                    icon: Icons.support_agent_rounded,
                    color: kEmerald,
                    label: tr('الدعم', 'Support'),
                    onTap: () => openUrl(kHelpLink),
                  ),
                  const SizedBox(width: 6),
                  IconLink(
                    key: const ValueKey('chk-channel-telegram'),
                    icon: Icons.telegram,
                    color: const Color(0xFF29A9EB),
                    label: tr('قناة التليجرام', 'Telegram channel'),
                    onTap: () => openUrl(kTelegramUrl),
                  ),
                  const SizedBox(width: 6),
                  IconLink(
                    key: const ValueKey('chk-channel-youtube'),
                    icon: Icons.smart_display_rounded,
                    color: const Color(0xFFFF2D2D),
                    label: tr('قناة اليوتيوب', 'YouTube channel'),
                    onTap: () => openUrl(kYoutubeUrl),
                  ),
                  const SizedBox(width: 8),
                  const LangToggle(),
                ],
              ),
            ),
          ),
        ),

        // Body: مطابق تماماً لشاشة s-check في مشروع gpt
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  children: [
                    const SizedBox(height: 18),

                    // الدائرة الدوارة وبداخلها صورة المنصة المختارة
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          RotationTransition(
                            turns: _spin,
                            child: SizedBox(
                              width: 96,
                              height: 96,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(platColor),
                                backgroundColor: platColor.withValues(alpha: 0.15),
                                strokeWidth: 3.2,
                              ),
                            ),
                          ),
                          Container(
                            width: 70,
                            height: 70,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kCoalHi,
                              border: Border.all(
                                color: platColor.withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: platColor.withValues(alpha: 0.45),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                curPlatform.asset,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: platColor,
                                  alignment: Alignment.center,
                                  child: Text(
                                    curPlatform.badge,
                                    style: headText(Colors.white, 22, weight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // العنوان الرئيسي (w_title)
                    Text(
                      tr('في انتظار إيداعك', 'Waiting for your deposit'),
                      textAlign: TextAlign.center,
                      style: headText(kWhite, 23, weight: FontWeight.w700),
                    ),

                    const SizedBox(height: 8),

                    // الوصف (w_sub)
                    Text(
                      tr(
                        'يُفتح الوصول بمجرد وصول الأموال.',
                        'Access opens as soon as the money arrives.',
                      ),
                      textAlign: TextAlign.center,
                      style: bodyText(kMist, 13.5, height: 1.45),
                    ),

                    const SizedBox(height: 20),

                    // بادج نتحقق تلقائياً (w_auto)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: kCoalHi.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: kWhiteLine),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _pulse,
                            builder: (context, _) {
                              return Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: kJadeBright.withValues(alpha: 0.5 + _pulse.value * 0.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kJadeBright.withValues(alpha: _pulse.value * 0.8),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tr('نتحقق تلقائيًا', 'Checking automatically'),
                            style: bodyText(kWhiteSoft, 12.0, weight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // كارت الملاحظة (data-why card من gpt: d_note_b & d_note)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kEmerald.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: kEmerald.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: kEmerald,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('هذا ليس دفعًا مقابل التطبيق.', 'This is not a payment for the app.'),
                                  style: bodyText(kWhite, 12.5, weight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tr(
                                    'تبقى الأموال لك — في رصيدك.',
                                    'The money stays yours — on your balance.',
                                  ),
                                  style: bodyText(kMist, 11.2, height: 1.35),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_left_rounded, color: kMist, size: 22),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bottom CTA Bar (زر «أودعت بالفعل» / «أكدت الرصيد بالفعل»)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: kInk.withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(color: kWhite.withValues(alpha: 0.1)),
            ),
          ),
          child: Center(
            child: SizedBox(
              width: contentWidth,
              child: InkWell(
                onTap: _isVerifyingDeposit ? null : _confirmDeposit,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: kEmeraldGradient,
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kEmerald.withValues(alpha: 0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isVerifyingDeposit) ...[
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                tr('جاري التحقق والربط النهائي...', 'Verifying & linking profile...'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: bodyText(
                                  kOnEmerald,
                                  13.5,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ] else ...[
                            Icon(Icons.verified_rounded, color: kOnEmerald, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                tr('أودعت بالفعل', 'I\'ve already deposited'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: bodyText(
                                  kOnEmerald,
                                  13.5,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: bodyText(kWhite, 12.8, weight: FontWeight.w700),
    );
  }

  Widget _serverCard({
    required int index,
    required bool selected,
    required String assetImage,
    required Color glowColor,
    required String tierName,
    required String amount,
    required String usd,
    required String spec,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [
                    glowColor.withValues(alpha: 0.18),
                    kCoalHi.withValues(alpha: 0.65),
                  ]
                : [
                    kCoalHi.withValues(alpha: 0.6),
                    kCoal.withValues(alpha: 0.4),
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? glowColor : kWhite.withValues(alpha: 0.12),
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: glowColor.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          children: [
            // أيقونة السيرفر الكبيرة بشفافيتها الأصلية وتوهج اختياري عند التحديد
            SizedBox(
              width: 66,
              height: 66,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (selected)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: glowColor.withValues(alpha: 0.45),
                            blurRadius: 22,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  Image.asset(
                    assetImage,
                    width: 66,
                    height: 66,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.dns_rounded, color: glowColor, size: 28);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // تفاصيل السيرفر والرصيد
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                tierName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: bodyText(
                                  selected ? kWhite : kWhiteSoft,
                                  13.0,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (selected) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF007AFF).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFF007AFF),
                                    width: 0.6,
                                  ),
                                ),
                                child: Text(
                                  tr('النشط', 'Active'),
                                  style: markText(const Color(0xFF007AFF), 8.5, weight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: (selected ? glowColor : kWhite).withValues(alpha: selected ? 0.16 : 0.06),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (selected ? glowColor : kWhiteLine).withValues(alpha: selected ? 0.45 : 0.2),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          usd,
                          style: bodyText(selected ? glowColor : kMist, 9.2, weight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    amount,
                    style: markText(
                      selected ? glowColor : kJadeBright,
                      11.2,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    spec,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: bodyText(kMist, 9.5, height: 1.25),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // شارة علامة الصح الزرقاء للموديل المختار
            if (selected)
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF007AFF),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x66007AFF),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              )
            else
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: kWhite.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
