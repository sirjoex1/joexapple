import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JoeXLoginPage extends StatefulWidget {
  final VoidCallback onComplete;

  const JoeXLoginPage({super.key, required this.onComplete});

  @override
  State<JoeXLoginPage> createState() => _JoeXLoginPageState();
}

class _JoeXLoginPageState extends State<JoeXLoginPage>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _shakeController;
  late AnimationController _loginLoadingController;

  // Text controllers
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _promoController = TextEditingController();

  final FocusNode _idFocusNode = FocusNode();
  final FocusNode _promoFocusNode = FocusNode();

  bool _hasPromoError = false;
  bool _isLoggingIn = false;
  int _selectedPlatform = 0; // 0: Melbet, 1: Linebet, 2: 1Xbet

  double _buttonScale = 1.0;

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

    _idFocusNode.addListener(() {
      setState(() {});
    });

    _promoFocusNode.addListener(() {
      setState(() {
        if (_promoFocusNode.hasFocus) {
          _hasPromoError = false;
        }
      });
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _loginLoadingController.dispose();
    _idController.dispose();
    _promoController.dispose();
    _idFocusNode.dispose();
    _promoFocusNode.dispose();
    super.dispose();
  }

  void _attemptLogin() {
    if (_isLoggingIn) return;

    final id = _idController.text.trim();
    final promo = _promoController.text.trim();

    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "الرجاء إدخال معرف الحساب ID",
            textAlign: TextAlign.right,
          ),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoggingIn = true;
    });

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

  void _showInvalidPromoDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "InvalidPromoDialog",
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final scale = Tween<double>(begin: 0.95, end: 1.0).animate(
          CurvedAnimation(parent: anim1, curve: Curves.easeOut),
        );
        final opacity = Tween<double>(begin: 0.0, end: 1.0).animate(anim1);

        String platformName = "المنصة المختارة";
        if (_selectedPlatform == 0) {
          platformName = "Melbet";
        } else if (_selectedPlatform == 1) {
          platformName = "Linebet";
        } else if (_selectedPlatform == 2) {
          platformName = "1Xbet";
        }

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
                      border: Border.all(color: const Color(0xFF2A2A35), width: 1.0),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text(
                              "ERROR: GATEWAY_BLOCKED",
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: Color(0xFF6C9EFF),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.gpp_bad_outlined,
                              color: Color(0xFF6C9EFF),
                              size: 16,
                            ),
                          ],
                        ),
                        const Divider(color: Color(0xFF2A2A35), height: 20),
                        const SizedBox(height: 8),
                        const Text(
                          "البرومو كود المدخل غير نشط حالياً للربط بالخادم الموحد.",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
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
                                  text: "لتفعيل نظام الأمان وفك تشفير إشارات الخانات السليمة، يجب ربط الحساب بالبرومو كود المعتمد:\n\n",
                                ),
                                const TextSpan(
                                  text: "1️⃣ أنشئ حساباً جديداً تماماً على منصة ",
                                ),
                                TextSpan(
                                  text: "$platformName\n",
                                  style: const TextStyle(
                                    color: Color(0xFF6C9EFF),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const TextSpan(
                                  text: "2️⃣ أدخل كود التفعيل المعتمد أثناء التسجيل: ",
                                ),
                                const TextSpan(
                                  text: "joe27\n\n",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const TextSpan(
                                  text: "⚠️ تنبيه: نظام حماية خادم التشفير يرفض الاتصالات العشوائية ويمنع تزوير الإشارات.",
                                  style: TextStyle(
                                    color: Color(0xFF5A5A6E),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 48,
                              color: const Color(0xFF6C9EFF),
                              child: const Center(
                                child: Text(
                                  "فهمت ✓  سأقوم بالتسجيل بالبرومو كود المعتمد",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
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
        final scale = Tween<double>(begin: 0.95, end: 1.0).animate(
          CurvedAnimation(parent: anim1, curve: Curves.easeOut),
        );
        final opacity = Tween<double>(begin: 0.0, end: 1.0).animate(anim1);

        return ScaleTransition(
          scale: scale,
          child: FadeTransition(
            opacity: opacity,
            child: SubscriptionDialogContent(
              onComplete: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_id', _idController.text.trim());
                
                String platformName = "Melbet";
                if (_selectedPlatform == 1) {
                  platformName = "Linebet";
                } else if (_selectedPlatform == 2) {
                  platformName = "1Xbet";
                }
                await prefs.setString('selected_platform', platformName);

                if (context.mounted) {
                  Navigator.of(context).pop(); // Close dialog
                  widget.onComplete(); // Navigate to game page
                }
              },
            ),
          ),
        );
      },
    );
  }

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
          color: const Color(0xFF0F0F12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF1E1E28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF6C9EFF),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          "$label: $value",
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: Color(0xFF5A5A6E),
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformButton(int index, String label) {
    final isSelected = _selectedPlatform == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPlatform = index;
          });
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 48,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1A1A28) : const Color(0xFF141418),
              border: Border.all(
                color: isSelected ? const Color(0xFF6C9EFF) : const Color(0xFF2A2A35),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF5A5A6E),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF2A2A35), width: 1.0),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF6C9EFF), width: 1.0),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Subtle diagonal line texture overlay (3% opacity)
          Positioned.fill(
            child: CustomPaint(
              painter: DiagonalLineTexturePainter(),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 40, left: 24, right: 24, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo Area
                  Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF3A3A4A),
                            width: 2.0,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            "assets/app_logo.png",
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "JOEX TOOL",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 120,
                        height: 1,
                        color: const Color(0xFF2A2A35),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "DECRYPTION PORTAL v2.0",
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF5A5A6E),
                          letterSpacing: 2.5,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Status Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatusIndicator("CORE", "ONLINE"),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.0),
                        child: Text("·", style: TextStyle(color: Color(0xFF3A3A4A))),
                      ),
                      _buildStatusIndicator("PORT", "8443"),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.0),
                        child: Text("·", style: TextStyle(color: Color(0xFF3A3A4A))),
                      ),
                      _buildStatusIndicator("SYS", "STABLE"),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Account ID Input (No label above)
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF141418),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _idController,
                      focusNode: _idFocusNode,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        prefixIcon: const Icon(
                          Icons.account_box_outlined,
                          color: Color(0xFF5A5A6E),
                          size: 16,
                        ),
                        hintText: "أدخل معرف الحساب",
                        hintStyle: const TextStyle(
                          color: Color(0xFF3A3A4A),
                          fontSize: 14,
                        ),
                        border: baseBorder,
                        enabledBorder: baseBorder,
                        focusedBorder: focusedBorder,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Promo Code Input (No label above)
                  ShakeWidget(
                    controller: _shakeController,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141418),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _promoController,
                        focusNode: _promoFocusNode,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: _hasPromoError ? Colors.redAccent : Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          prefixIcon: const Icon(
                            Icons.vpn_key_outlined,
                            color: Color(0xFF5A5A6E),
                            size: 16,
                          ),
                          hintText: "أدخل كود التفعيل",
                          hintStyle: const TextStyle(
                            color: Color(0xFF3A3A4A),
                            fontSize: 14,
                          ),
                          border: baseBorder,
                          enabledBorder: baseBorder,
                          focusedBorder: focusedBorder,
                        ),
                      ),
                    ),
                  ),
                  if (_hasPromoError)
                    const Padding(
                      padding: EdgeInsets.only(top: 6.0, right: 8.0),
                      child: Text(
                        "خطأ: البرومو كود غير صالح!",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Platform Selector
                  Row(
                    children: [
                      _buildPlatformButton(0, "Melbet"),
                      const SizedBox(width: 12),
                      _buildPlatformButton(2, "1Xbet"),
                      const SizedBox(width: 12),
                      _buildPlatformButton(1, "Linebet"),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Decrypt Button
                  GestureDetector(
                    onTapDown: (_) => setState(() => _buttonScale = 0.97),
                    onTapUp: (_) => setState(() => _buttonScale = 1.0),
                    onTapCancel: () => setState(() => _buttonScale = 1.0),
                    onTap: _attemptLogin,
                    child: AnimatedScale(
                      scale: _buttonScale,
                      duration: const Duration(milliseconds: 100),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          color: const Color(0xFF6C9EFF),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isLoggingIn)
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "...جاري التحقق وتخطي الأمان",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.0,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                const Text(
                                  "بدء فك التشفير",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  "[DECRYPT]",
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    color: Color(0x80FFFFFF),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                        url: "https://youtube.com/@sir_joex1",
                      ),
                    ],
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

// Shake Animation Widget (to shake promo field on error)
class ShakeWidget extends StatefulWidget {
  final Widget child;
  final AnimationController controller;

  const ShakeWidget({
    super.key,
    required this.child,
    required this.controller,
  });

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
        if (status == AnimationStatus.completed) {
          widget.controller.reset();
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offsetAnimation,
      builder: (context, child) {
        final double value = _offsetAnimation.value;
        final double offset = math.sin(value * math.pi * 3) * 6;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: widget.child,
        );
      },
    );
  }
}

// Diagonal line pattern overlay (3% opacity)
class DiagonalLineTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6C9EFF).withValues(alpha: 0.03)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double spacing = 18.0;
    for (double i = -size.height; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DiagonalLineTexturePainter oldDelegate) => false;
}

// Verification Dialog content
class SubscriptionDialogContent extends StatefulWidget {
  final VoidCallback onComplete;

  const SubscriptionDialogContent({super.key, required this.onComplete});

  @override
  State<SubscriptionDialogContent> createState() =>
      _SubscriptionDialogContentState();
}

class _SubscriptionDialogContentState extends State<SubscriptionDialogContent> {
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
    setState(() {
      _handshakeLogs.add(msg);
    });
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
    _telegramTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
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
    _telegramMtcTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
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
    _youtubeTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
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
    final bool validationPassed = _telegramSubscribed && _telegramMtcSubscribed && _youtubeSubscribed;

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
              border: Border.all(color: const Color(0xFF2A2A35), width: 1.0),
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
                        color: Color(0xFF6C9EFF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.vpn_lock_outlined,
                      color: Color(0xFF6C9EFF),
                      size: 20,
                    ),
                  ],
                ),
                const Divider(
                  color: Color(0xFF2A2A35),
                  height: 20,
                  thickness: 1.0,
                ),
                const Text(
                  "لكي تتمكن من الدخول واستخدام السيرفر، يرجى إتمام المهام التالية بالترتيب لتفعيل حسابك الموحد:",
                  style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 16),

                // 1. Telegram Task
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

                // 2. Telegram Task (drk_mtc)
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

                // 3. YouTube Task
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

                // Diagnostics printout
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

                // Confirm/Submit
                GestureDetector(
                  onTap: validationPassed ? widget.onComplete : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: validationPassed ? const Color(0xFF6C9EFF) : const Color(0xFF141418),
                        borderRadius: BorderRadius.circular(12),
                        border: validationPassed
                            ? null
                            : Border.all(color: const Color(0xFF2A2A35)),
                      ),
                      child: Center(
                        child: Text(
                          "تحقق من التفعيل والدخول [OK]",
                          style: TextStyle(
                            color: validationPassed ? Colors.white : const Color(0xFF5A5A6E),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
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
              color: isCompleted ? const Color(0xFF6C9EFF) : const Color(0xFF2A2A35),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              if (isCompleted)
                const Icon(Icons.check_circle, color: Color(0xFF6C9EFF), size: 22)
              else if (isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    value: progress,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF6C9EFF),
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.arrow_back_ios_new,
                  color: Color(0xFF5A5A6E),
                  size: 12,
                ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF5A5A6E), fontSize: 9.0),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Icon(icon, color: const Color(0xFF6C9EFF), size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
