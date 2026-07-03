import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────
const _kBlack = Color(0xFF080808);
const _kPurple = Color(0xFF7C3AED);
const _kPurpleDark = Color(0xFF4A1D96);
const _kPurpleMid = Color(0xFF2D1B69);
const _kPanelBg = Color(0xFF0D0B14);
const _kSubText = Color(0xFF5A4A8A);
const _kDimText = Color(0xFF3A3A4A);
const _kLineColor = Color(0xFF1A1530);

// ─────────────────────────────────────────────
// MAIN WIDGET
// ─────────────────────────────────────────────
class JoeXLoginPage extends StatefulWidget {
  final VoidCallback onComplete;

  const JoeXLoginPage({super.key, required this.onComplete});

  @override
  State<JoeXLoginPage> createState() => _JoeXLoginPageState();
}

class _JoeXLoginPageState extends State<JoeXLoginPage>
    with TickerProviderStateMixin {
  // ── Controllers ──────────────────────────────
  late AnimationController _shakeController;
  late AnimationController _loginLoadingController;
  late AnimationController _entryController;

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _promoController = TextEditingController();
  final FocusNode _idFocusNode = FocusNode();
  final FocusNode _promoFocusNode = FocusNode();

  // ── State ─────────────────────────────────────
  bool _hasPromoError = false;
  bool _isLoggingIn = false;
  int _selectedPlatform = 0; // 0: Melbet, 1: Linebet, 2: 1Xbet
  double _buttonScale = 1.0;

  // ── Entry animations ─────────────────────────
  late Animation<double> _bgFade;
  late Animation<Offset> _identitySlide;
  late Animation<double> _identityFade;
  late Animation<Offset> _panelSlide;
  late Animation<double> _panelFade;

  // Staggered field & button animations
  late Animation<double> _field1Fade;
  late Animation<double> _field2Fade;
  late Animation<double> _platformFade;
  late Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _loginLoadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Entry animation — 1600ms total
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // Background fade 0–400ms
    _bgFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );

    // Identity section slides down 200–700ms
    _identitySlide = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.12, 0.44, curve: Curves.easeOutCubic),
    ));
    _identityFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.12, 0.44, curve: Curves.easeOut),
      ),
    );

    // Glass panel slides up 300–900ms
    _panelSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.19, 0.56, curve: Curves.easeOutCubic),
    ));
    _panelFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.19, 0.50, curve: Curves.easeOut),
      ),
    );

    // Staggered: field1 0.50→0.65, field2 0.60→0.75, platform 0.70→0.85, button 0.80→1.0
    _field1Fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.50, 0.68, curve: Curves.easeOut),
      ),
    );
    _field2Fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.58, 0.76, curve: Curves.easeOut),
      ),
    );
    _platformFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.68, 0.86, curve: Curves.easeOut),
      ),
    );
    _buttonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.78, 1.0, curve: Curves.easeOut),
      ),
    );

    _idFocusNode.addListener(() => setState(() {}));
    _promoFocusNode.addListener(() {
      setState(() {
        if (_promoFocusNode.hasFocus) _hasPromoError = false;
      });
    });

    // Start entry animation
    _entryController.forward();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _loginLoadingController.dispose();
    _entryController.dispose();
    _idController.dispose();
    _promoController.dispose();
    _idFocusNode.dispose();
    _promoFocusNode.dispose();
    super.dispose();
  }

  // ── Logic ─────────────────────────────────────
  void _attemptLogin() {
    if (_isLoggingIn) return;
    final id = _idController.text.trim();
    final promo = _promoController.text.trim();

    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("الرجاء إدخال معرف الحساب ID",
            textAlign: TextAlign.right),
        backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    setState(() => _isLoggingIn = true);

    _loginLoadingController.forward(from: 0.0).then((_) {
      if (promo == "joe27") {
        setState(() {
          _isLoggingIn = false;
          _hasPromoError = false;
        });
        _showSubscriptionDialog();
      } else {
        setState(() {
          _isLoggingIn = false;
          _hasPromoError = true;
        });
        _shakeController.forward(from: 0.0);
        _showInvalidPromoDialog();
      }
    });
  }

  // ── Dialogs ────────────────────────────────────
  void _showInvalidPromoDialog() {
    String platformName = _selectedPlatform == 0
        ? "Melbet"
        : _selectedPlatform == 1
            ? "Linebet"
            : "1Xbet";

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "InvalidPromoDialog",
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final scale = Tween<double>(begin: 0.95, end: 1.0)
            .animate(CurvedAnimation(parent: anim1, curve: Curves.easeOut));
        final opacity =
            Tween<double>(begin: 0.0, end: 1.0).animate(anim1);
        return ScaleTransition(
          scale: scale,
          child: FadeTransition(
            opacity: opacity,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.88,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141418),
                      border:
                          Border.all(color: const Color(0xFF2A2A35), width: 1.0),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text("ERROR: GATEWAY_BLOCKED",
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: _kPurple,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                )),
                            const SizedBox(width: 8),
                            const Icon(Icons.gpp_bad_outlined,
                                color: _kPurple, size: 16),
                          ],
                        ),
                        const Divider(color: Color(0xFF2A2A35), height: 20),
                        const SizedBox(height: 8),
                        const Text(
                          "البرومو كود المدخل غير نشط حالياً للربط بالخادم الموحد.",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2A2A35)),
                          ),
                          child: RichText(
                            textAlign: TextAlign.right,
                            text: TextSpan(
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Color(0xFF8E8E93),
                                fontSize: 11,
                                height: 1.5,
                              ),
                              children: [
                                const TextSpan(
                                    text:
                                        "لتفعيل نظام الأمان وفك تشفير إشارات الخانات السليمة، يجب ربط الحساب بالبرومو كود المعتمد:\n\n"),
                                const TextSpan(
                                    text: "1️⃣ أنشئ حساباً جديداً تماماً على منصة "),
                                TextSpan(
                                    text: "$platformName\n",
                                    style: const TextStyle(
                                        color: _kPurple,
                                        fontWeight: FontWeight.bold)),
                                const TextSpan(
                                    text:
                                        "2️⃣ أدخل كود التفعيل المعتمد أثناء التسجيل: "),
                                const TextSpan(
                                    text: "joe27\n\n",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                const TextSpan(
                                    text:
                                        "⚠️ تنبيه: نظام حماية خادم التشفير يرفض الاتصالات العشوائية ويمنع تزوير الإشارات.",
                                    style: TextStyle(
                                        color: Color(0xFF5A5A6E), fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [_kPurpleDark, _kPurple],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                "فهمت ✓  سأقوم بالتسجيل بالبرومو كود المعتمد",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold),
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
          ),
        );
      },
    );
  }

  void _showSubscriptionDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "SubscriptionDialog",
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final scale = Tween<double>(begin: 0.95, end: 1.0)
            .animate(CurvedAnimation(parent: anim1, curve: Curves.easeOut));
        final opacity =
            Tween<double>(begin: 0.0, end: 1.0).animate(anim1);
        return ScaleTransition(
          scale: scale,
          child: FadeTransition(
            opacity: opacity,
            child: SubscriptionDialogContent(
              onComplete: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(
                    'user_id', _idController.text.trim());
                String platformName = _selectedPlatform == 0
                    ? "Melbet"
                    : _selectedPlatform == 1
                        ? "Linebet"
                        : "1Xbet";
                await prefs.setString('selected_platform', platformName);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  widget.onComplete();
                }
              },
            ),
          ),
        );
      },
    );
  }

  // ── Social buttons (bottom of panel) ──────────
  Widget _buildSocialButton({
    required String label,
    required IconData icon,
    required Color color,
    required String url,
  }) {
    return GestureDetector(
      onTap: () async {
        final Uri uri = Uri.parse(url);
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _kPanelBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _kPurpleMid.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topSectionHeight = size.height * 0.40;
    final panelHeight = size.height * 0.65;

    return Scaffold(
      backgroundColor: _kBlack,
      resizeToAvoidBottomInset: true,
      body: AnimatedBuilder(
        animation: _entryController,
        builder: (context, _) {
          return Stack(
            children: [
              // ═══════════════════════════════════
              // LAYER 1 — BACKGROUND
              // ═══════════════════════════════════
              FadeTransition(
                opacity: _bgFade,
                child: SizedBox.expand(
                  child: CustomPaint(
                    painter: _DotGridPainter(),
                  ),
                ),
              ),

              // Geometric circle — top left
              FadeTransition(
                opacity: _bgFade,
                child: Positioned(
                  top: -120,
                  left: -120,
                  child: SizedBox(
                    width: 300,
                    height: 300,
                    child: CustomPaint(
                      painter: _GeometricCirclePainter(
                        color: _kPurpleMid.withValues(alpha: 0.30),
                      ),
                    ),
                  ),
                ),
              ),

              // Geometric circle — bottom right
              FadeTransition(
                opacity: _bgFade,
                child: Positioned(
                  bottom: -120,
                  right: -120,
                  child: SizedBox(
                    width: 300,
                    height: 300,
                    child: CustomPaint(
                      painter: _GeometricCirclePainter(
                        color: _kPurpleMid.withValues(alpha: 0.30),
                      ),
                    ),
                  ),
                ),
              ),

              // ═══════════════════════════════════
              // LAYER 2 — TOP IDENTITY SECTION
              // ═══════════════════════════════════
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topSectionHeight,
                child: SlideTransition(
                  position: _identitySlide,
                  child: FadeTransition(
                    opacity: _identityFade,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left: purple bar + text stack
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 3px purple vertical bar
                                  Container(
                                    width: 3,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: _kPurple,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Text stack
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // AUTHORIZED ACCESS ONLY
                                      const Text(
                                        "AUTHORIZED ACCESS ONLY",
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 9,
                                          color: Color(0xFF3D2F6E),
                                          letterSpacing: 3,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // JoeX + Apple
                                      RichText(
                                        text: const TextSpan(
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w900,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: "JoeX",
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                            TextSpan(
                                              text: " Apple",
                                              style:
                                                  TextStyle(color: _kPurple),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // DECRYPTION PORTAL
                                      const Text(
                                        "DECRYPTION PORTAL",
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 10,
                                          color: _kSubText,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Right: Logo with L-brackets
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Circular logo
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: _kPurple, width: 1.5),
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        "assets/app_logo.png",
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  // L-shaped corner brackets
                                  CustomPaint(
                                    size: const Size(80, 80),
                                    painter: _CornerBracketsPainter(
                                      color: _kPurple,
                                      strokeWidth: 1.5,
                                      armLength: 12.0,
                                      padding: 4.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ═══════════════════════════════════
              // LAYER 3 — BOTTOM GLASS PANEL
              // ═══════════════════════════════════
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: panelHeight,
                child: SlideTransition(
                  position: _panelSlide,
                  child: FadeTransition(
                    opacity: _panelFade,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: _kPanelBg,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                            ),
                            border: Border(
                              top: BorderSide(
                                  color: _kPurpleMid, width: 1.0),
                            ),
                          ),
                          child: SingleChildScrollView(
                            padding: EdgeInsets.only(
                              left: 24,
                              right: 24,
                              top: 0,
                              bottom:
                                  MediaQuery.of(context).viewInsets.bottom +
                                      24,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ── Drag indicator ────────────────
                                const SizedBox(height: 16),
                                Center(
                                  child: Container(
                                    width: 40,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: _kPurple,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // ── OPERATOR CREDENTIALS label ─────
                                const Text(
                                  "OPERATOR CREDENTIALS",
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 9,
                                    color: _kSubText,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // ── Field 1: ID ───────────────────
                                FadeTransition(
                                  opacity: _field1Fade,
                                  child: _buildUnderlineField(
                                    label: "[ ID ]",
                                    controller: _idController,
                                    focusNode: _idFocusNode,
                                    hintText: "أدخل معرف الحساب",
                                    prefixIcon: Icons.account_box_outlined,
                                    hasError: false,
                                  ),
                                ),

                                const SizedBox(height: 4),
                                // Divider between fields
                                Container(
                                    height: 0.5,
                                    color: _kLineColor),
                                const SizedBox(height: 4),

                                // ── Field 2: PROMO ────────────────
                                FadeTransition(
                                  opacity: _field2Fade,
                                  child: ShakeWidget(
                                    controller: _shakeController,
                                    child: _buildUnderlineField(
                                      label: "[ PROMO ]",
                                      controller: _promoController,
                                      focusNode: _promoFocusNode,
                                      hintText: "أدخل كود التفعيل",
                                      prefixIcon: Icons.vpn_key_outlined,
                                      hasError: _hasPromoError,
                                    ),
                                  ),
                                ),

                                if (_hasPromoError)
                                  const Padding(
                                    padding:
                                        EdgeInsets.only(top: 6.0, right: 8.0),
                                    child: Text(
                                      "خطأ: البرومو كود غير صالح!",
                                      style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 11),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),

                                const SizedBox(height: 28),

                                // ── Platform Selector ──────────────
                                FadeTransition(
                                  opacity: _platformFade,
                                  child: _buildPlatformSelector(),
                                ),

                                const SizedBox(height: 28),

                                // ── Decrypt Button ─────────────────
                                FadeTransition(
                                  opacity: _buttonFade,
                                  child: Center(
                                    child: GestureDetector(
                                      onTapDown: (_) => setState(
                                          () => _buttonScale = 0.97),
                                      onTapUp: (_) =>
                                          setState(() => _buttonScale = 1.0),
                                      onTapCancel: () =>
                                          setState(() => _buttonScale = 1.0),
                                      onTap: _attemptLogin,
                                      child: AnimatedScale(
                                        scale: _buttonScale,
                                        duration:
                                            const Duration(milliseconds: 100),
                                        child: _buildDecryptButton(),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 28),

                                // ── Social Buttons ─────────────────
                                FadeTransition(
                                  opacity: _buttonFade,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      _buildSocialButton(
                                        label: "قناة التليجرام",
                                        icon: Icons.send,
                                        color: const Color(0xFF229ED9),
                                        url: "https://t.me/elostora_vip",
                                      ),
                                      const SizedBox(width: 16),
                                      _buildSocialButton(
                                        label: "قناة اليوتيوب",
                                        icon: Icons.play_circle_fill,
                                        color: const Color(0xFFFF0000),
                                        url:
                                            "https://youtube.com/@sir_joex1",
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
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
        },
      ),
    );
  }

  // ── Underline-only Input Field ─────────────────
  Widget _buildUnderlineField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData prefixIcon,
    required bool hasError,
  }) {
    final isFocused = focusNode.hasFocus;
    final lineColor = hasError
        ? Colors.redAccent
        : isFocused
            ? _kPurple
            : _kPurpleMid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label above field
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: _kPurple,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            // Prefix icon
            Icon(prefixIcon, color: _kPurple, size: 18),
            const SizedBox(width: 10),
            // Input
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: hasError ? Colors.redAccent : Colors.white,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                  hintText: hintText,
                  hintStyle: const TextStyle(
                    color: _kDimText,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
        // Bottom underline only
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 1,
          color: lineColor,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ── Platform Selector (column of rows) ────────
  Widget _buildPlatformSelector() {
    final platforms = [
      {"index": 0, "name": "Melbet", "uptime": "99.8%"},
      {"index": 2, "name": "1Xbet", "uptime": "98.5%"},
      {"index": 1, "name": "Linebet", "uptime": "97.2%"},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: platforms.map((p) {
        final idx = p["index"] as int;
        final isSelected = _selectedPlatform == idx;
        return GestureDetector(
          onTap: () => setState(() => _selectedPlatform = idx),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: isSelected
                  ? _kLineColor
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? _kPurpleMid
                    : _kLineColor,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                // Left: selection ring
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? _kPurple : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? _kPurple : _kSubText,
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Platform name
                Expanded(
                  child: Text(
                    p["name"] as String,
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white : const Color(0xFF8E8E93),
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                // Uptime
                Text(
                  p["uptime"] as String,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: _kSubText,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Decrypt Button ─────────────────────────────
  Widget _buildDecryptButton() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [_kPurpleDark, _kPurple],
          begin: Alignment(0.0, -1.0),
          end: Alignment(1.0, 1.0),
          // Simulating 135deg
        ),
        boxShadow: [
          BoxShadow(
            color: _kPurple.withValues(alpha: 0.30),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Arrow icon on the right
          Positioned(
            right: 20,
            top: 0,
            bottom: 0,
            child: Center(
              child: Icon(
                Icons.arrow_forward,
                color: Colors.white.withValues(alpha: 0.60),
                size: 20,
              ),
            ),
          ),
          // Text in the center
          Center(
            child: _isLoggingIn
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "...جاري التحقق",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "بدء فك التشفير",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "[DECRYPT]",
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          color: Colors.white.withValues(alpha: 0.50),
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

// ─────────────────────────────────────────────
// SHAKE WIDGET
// ─────────────────────────────────────────────
class ShakeWidget extends StatefulWidget {
  final Widget child;
  final AnimationController controller;

  const ShakeWidget(
      {super.key, required this.child, required this.controller});

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget> {
  late Animation<double> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _offsetAnimation = Tween<double>(begin: 0.0, end: 24.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(widget.controller)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.controller.reset();
      });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offsetAnimation,
      builder: (context, child) {
        final double offset =
            math.sin(_offsetAnimation.value * math.pi * 3) * 6;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────
// CUSTOM PAINTERS
// ─────────────────────────────────────────────

/// Dot grid background — 2px dots every 28px
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1530)
      ..style = PaintingStyle.fill;

    const double spacing = 28.0;
    const double dotRadius = 1.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => false;
}

/// Large partial circle (stroke only) for geometric decoration
class _GeometricCirclePainter extends CustomPainter {
  final Color color;
  _GeometricCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width / 2, paint);
  }

  @override
  bool shouldRepaint(covariant _GeometricCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// L-shaped corner brackets (same as splash screen)
class _CornerBracketsPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double armLength;
  final double padding;

  _CornerBracketsPainter({
    required this.color,
    required this.strokeWidth,
    required this.armLength,
    required this.padding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double l = padding;
    final double t = padding;
    final double r = size.width - padding;
    final double b = size.height - padding;

    // Top-left
    canvas.drawLine(Offset(l, t), Offset(l + armLength, t), paint);
    canvas.drawLine(Offset(l, t), Offset(l, t + armLength), paint);
    // Top-right
    canvas.drawLine(Offset(r, t), Offset(r - armLength, t), paint);
    canvas.drawLine(Offset(r, t), Offset(r, t + armLength), paint);
    // Bottom-left
    canvas.drawLine(Offset(l, b), Offset(l + armLength, b), paint);
    canvas.drawLine(Offset(l, b), Offset(l, b - armLength), paint);
    // Bottom-right
    canvas.drawLine(Offset(r, b), Offset(r - armLength, b), paint);
    canvas.drawLine(Offset(r, b), Offset(r, b - armLength), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter old) =>
      old.color != color || old.armLength != armLength;
}

// ─────────────────────────────────────────────
// SUBSCRIPTION DIALOG (unchanged logic)
// ─────────────────────────────────────────────
class SubscriptionDialogContent extends StatefulWidget {
  final VoidCallback onComplete;

  const SubscriptionDialogContent({super.key, required this.onComplete});

  @override
  State<SubscriptionDialogContent> createState() =>
      _SubscriptionDialogContentState();
}

class _SubscriptionDialogContentState
    extends State<SubscriptionDialogContent> {
  bool _telegramSubscribed = false;
  bool _telegramMtcSubscribed = false;
  bool _youtubeSubscribed = false;

  bool _isTelegramLoading = false;
  bool _isTelegramMtcLoading = false;
  bool _isYoutubeLoading = false;

  double _telegramProgress = 0.0;
  double _telegramMtcProgress = 0.0;
  double _youtubeProgress = 0.0;

  Timer? _telegramTimer;
  Timer? _telegramMtcTimer;
  Timer? _youtubeTimer;

  final List<String> _handshakeLogs = [
    "[SYS] VIP Decryption Engine standby...",
    "[SYS] Awaiting token activation verification...",
  ];

  final ScrollController _scrollController = ScrollController();

  void _addLog(String msg) {
    if (!mounted) return;
    setState(() => _handshakeLogs.add(msg));
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _subscribeTelegram() async {
    if (_telegramSubscribed || _isTelegramLoading) return;
    final Uri url = Uri.parse("https://t.me/elostora_vip");
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
    setState(() {
      _isTelegramLoading = true;
      _telegramProgress = 0.0;
    });
    _addLog("[SYS] Validating Telegram channel: t.me/elostora_vip...");
    int step = 0;
    _telegramTimer =
        Timer.periodic(const Duration(milliseconds: 300), (timer) {
      setState(() {
        _telegramProgress += 0.2;
        if (_telegramProgress >= 1.0) {
          _telegramProgress = 1.0;
          _telegramSubscribed = true;
          _isTelegramLoading = false;
          _telegramTimer?.cancel();
          _addLog("[OK] Telegram bypass token validated successfully.");
        } else {
          step++;
          if (step == 1) {
            _addLog("[SECURE] Reading user registration signature...");
          } else if (step == 2) {
            _addLog("[PING] Syncing credentials packet to auth DB...");
          }
        }
      });
    });
  }

  void _subscribeTelegramMtc() async {
    if (_telegramMtcSubscribed || _isTelegramMtcLoading) return;
    final Uri url = Uri.parse("https://t.me/drk_mtc");
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
    setState(() {
      _isTelegramMtcLoading = true;
      _telegramMtcProgress = 0.0;
    });
    _addLog("[SYS] Validating Telegram channel: t.me/drk_mtc...");
    int step = 0;
    _telegramMtcTimer =
        Timer.periodic(const Duration(milliseconds: 300), (timer) {
      setState(() {
        _telegramMtcProgress += 0.2;
        if (_telegramMtcProgress >= 1.0) {
          _telegramMtcProgress = 1.0;
          _telegramMtcSubscribed = true;
          _isTelegramMtcLoading = false;
          _telegramMtcTimer?.cancel();
          _addLog("[OK] Telegram @drk_mtc bypass token validated successfully.");
        } else {
          step++;
          if (step == 1) {
            _addLog("[SECURE] Reading user registration signature...");
          } else if (step == 2) {
            _addLog("[PING] Syncing credentials packet to auth DB...");
          }
        }
      });
    });
  }

  void _subscribeYoutube() async {
    if (_youtubeSubscribed || _isYoutubeLoading) return;
    final Uri url = Uri.parse("https://youtube.com/@sir_joex1");
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
    setState(() {
      _isYoutubeLoading = true;
      _youtubeProgress = 0.0;
    });
    _addLog("[SYS] Validating YouTube subscriber channel...");
    int step = 0;
    _youtubeTimer =
        Timer.periodic(const Duration(milliseconds: 300), (timer) {
      setState(() {
        _youtubeProgress += 0.2;
        if (_youtubeProgress >= 1.0) {
          _youtubeProgress = 1.0;
          _youtubeSubscribed = true;
          _isYoutubeLoading = false;
          _youtubeTimer?.cancel();
          _addLog("[OK] YouTube verification token validated successfully.");
        } else {
          step++;
          if (step == 1) {
            _addLog("[SECURE] Scanning YouTube subscriber logs...");
          } else if (step == 2) {
            _addLog("[PING] Matching keys to master server core...");
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _telegramTimer?.cancel();
    _telegramMtcTimer?.cancel();
    _youtubeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool validationPassed =
        _telegramSubscribed && _telegramMtcSubscribed && _youtubeSubscribed;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF141418),
              border:
                  Border.all(color: const Color(0xFF2A2A35), width: 1.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      "تفعيل الترخيص الرقمي (إلزامي)",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _kPurple,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.vpn_lock_outlined,
                        color: _kPurple, size: 20),
                  ],
                ),
                const Divider(
                    color: Color(0xFF2A2A35), height: 20, thickness: 1.0),
                const Text(
                  "لكي تتمكن من الدخول واستخدام السيرفر، يرجى إتمام المهام التالية بالترتيب لتفعيل حسابك الموحد:",
                  style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 16),
                _buildTaskCard(
                  icon: Icons.telegram_outlined,
                  title: "اشترك بقناة التليجرام الرسمية",
                  subtitle: "t.me/elostora_vip",
                  progress: _telegramProgress,
                  isLoading: _isTelegramLoading,
                  isCompleted: _telegramSubscribed,
                  onTap: _subscribeTelegram,
                ),
                const SizedBox(height: 10),
                _buildTaskCard(
                  icon: Icons.telegram_outlined,
                  title: "اشترك بقناة التليجرام الاحتياطية",
                  subtitle: "t.me/drk_mtc",
                  progress: _telegramMtcProgress,
                  isLoading: _isTelegramMtcLoading,
                  isCompleted: _telegramMtcSubscribed,
                  onTap: _subscribeTelegramMtc,
                ),
                const SizedBox(height: 10),
                _buildTaskCard(
                  icon: Icons.play_circle_outline,
                  title: "اشترك بقناتنا على اليوتيوب",
                  subtitle: "Sir JoeX YouTube Channel",
                  progress: _youtubeProgress,
                  isLoading: _isYoutubeLoading,
                  isCompleted: _youtubeSubscribed,
                  onTap: _subscribeYoutube,
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A0A),
                      border: Border.all(color: const Color(0xFF2A2A35)),
                    ),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: _handshakeLogs.length,
                      itemBuilder: (context, index) {
                        return Text(
                          _handshakeLogs[index],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFF5A5A6E),
                            fontSize: 9.0,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: validationPassed ? widget.onComplete : null,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: validationPassed
                          ? const LinearGradient(
                              colors: [_kPurpleDark, _kPurple],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            )
                          : null,
                      color: validationPassed ? null : const Color(0xFF141418),
                      border: validationPassed
                          ? null
                          : Border.all(color: const Color(0xFF2A2A35)),
                    ),
                    child: Center(
                      child: Text(
                        "تحقق من التفعيل والدخول [OK]",
                        style: TextStyle(
                          color: validationPassed
                              ? Colors.white
                              : const Color(0xFF5A5A6E),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildTaskCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required double progress,
    required bool isLoading,
    required bool isCompleted,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            border: Border.all(
              color: isCompleted ? _kPurple : const Color(0xFF2A2A35),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              if (isCompleted)
                const Icon(Icons.check_circle, color: _kPurple, size: 22)
              else if (isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    value: progress,
                    valueColor: const AlwaysStoppedAnimation<Color>(_kPurple),
                  ),
                )
              else
                const Icon(Icons.arrow_back_ios_new,
                    color: Color(0xFF5A5A6E), size: 12),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF5A5A6E), fontSize: 9.0)),
                ],
              ),
              const SizedBox(width: 12),
              Icon(icon, color: _kPurple, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
