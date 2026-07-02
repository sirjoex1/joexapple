import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class JoeXApplePage extends StatefulWidget {
  const JoeXApplePage({super.key});

  @override
  State<JoeXApplePage> createState() => _JoeXApplePageState();
}

class _JoeXApplePageState extends State<JoeXApplePage>
    with TickerProviderStateMixin {
  // Session / Storage data
  late SharedPreferences _prefs;
  String _userId = "JOE_VIP_USER";
  int _totalWins = 0;
  String _selectedPlatformName = "Melbet";

  // Server Mode state variables
  int _selectedServerMode = 1; // 0: Balanced, 1: Secure, 2: Risky
  double _balancedServerSuccess = 98.5;
  double _secureServerSuccess = 99.3;
  double _riskyServerSuccess = 96.6;

  Timer? _fluctuationTimer;

  // Grid representation (10 rows, 5 columns)
  final int _rows = 10;
  final int _cols = 5;
  late List<List<CellState>> _grid;

  // Odds list
  final List<String> _odds = [
    "x349.68",
    "x69.93",
    "x27.97",
    "x11.18",
    "x6.71",
    "x4.02",
    "x2.41",
    "x1.93",
    "x1.54",
    "x1.23",
  ];

  // Prediction Grid States
  int _activeRow = -1;
  bool _isPredicting = false;
  bool _isRestoring = false;

  // Button scale animations
  double _predictScale = 1.0;
  double _restoreScale = 1.0;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _initPreferences();
    _initGrid();

    // Fluctuating server uptime metrics
    _fluctuationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          final random = math.Random();
          _balancedServerSuccess = (98.0 + random.nextDouble() * 1.0).clamp(95.0, 100.0);
          _secureServerSuccess = (99.0 + random.nextDouble() * 0.8).clamp(95.0, 100.0);
          _riskyServerSuccess = (95.5 + random.nextDouble() * 2.0).clamp(95.0, 100.0);
        });
      }
    });
  }

  void _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = _prefs.getString('user_id') ?? "JOE_VIP_USER";
      _totalWins = _prefs.getInt('total_wins') ?? 245;
      _selectedPlatformName = _prefs.getString('selected_platform') ?? "Melbet";
    });
  }

  void _initGrid() {
    _grid = List.generate(
      _rows,
      (r) => List.generate(_cols, (c) => CellState(type: 0)),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _fluctuationTimer?.cancel();
    super.dispose();
  }

  void _showNotification(String message, bool isError) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isError ? Colors.redAccent.withValues(alpha: 0.9) : const Color(0xFF1C1C28),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isError ? Colors.redAccent : const Color(0xFF6C9EFF),
            width: 1.0,
          ),
        ),
      ),
    );
  }

  // Session Logout
  void _logout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F0F12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1E1E28), width: 1.0),
          ),
          title: const Text(
            "تسجيل الخروج",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
          content: const Text(
            "هل أنت متأكد من رغبتك في تسجيل الخروج؟ سيتم مسح الجلسة الحالية.",
            style: TextStyle(color: Color(0xFF8888AA)),
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "إلغاء",
                style: TextStyle(color: Color(0xFF5A5A6E)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "خروج",
                style: TextStyle(
                  color: Color(0xFF6C9EFF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _prefs.setBool('is_logged_in', false);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, anim1, anim2) =>
                JoeXLoginPage(onComplete: () {}),
            transitionsBuilder: (context, anim1, anim2, child) {
              return FadeTransition(opacity: anim1, child: child);
            },
          ),
        );
      }
    }
  }

  // Next prediction round
  void _startNextRound() async {
    if (_isPredicting || _isRestoring) return;

    bool hasApples = _grid.any((row) => row.any((cell) => cell.type == 1));
    if (hasApples) {
      _showNotification("قم باستعادة السيرفر أولاً لتنظيف النتائج السابقة", true);
      return;
    }

    setState(() {
      _isPredicting = true;
    });

    // 1. Show Connecting server Dialog
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "ServerConnection",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(anim1),
            child: HackerTerminalDialog(
              title: "CONNECTION_SECURE_TUNNEL: PORT_8443",
              commands: const [
                "INITIALIZING BYPASS ENGINE PROTOCOL v5.0...",
                "ESTABLISHING SECURE UDP CONNECTION TO HOST: srv-09.joex.net",
                "PING LATENCY: 11ms // PACKET INTEGRITY: 100%",
                "BYPASSING INTEGRITY ANTI-CHEAT SUBSYSTEMS...",
                "WARNING: ENCRYPTED FIREWALL DETECTED. ENABLING AES BYPASS...",
                "STATUS: EXPLOIT INJECTED SUCCESSFUL [OK]",
                "FETCHING CELL MATRIX COORDINATES FROM MAIN DATABASE...",
                "READING SEED DECRYPTION ENTROPY...",
                "DECRYPTING SAFE APPLE CELL LOCATIONS...",
                "MAPPING TARGET MATRIX (10x5)...",
                "LOCATING ROW DECRYPTION VECTOR VALS...",
                "SYNCING LOCAL TELEMETRY BUFFER WITH CLIENT...",
                "BYPASS AND DECRYPTION COMPLETED SUCCESSFULLY.",
                "STATUS: SYSTEM STABLE. ENCRYPTED HOOKS ARMED.",
              ],
            ),
          ),
        );
      },
    );

    // 2. Play prediction animations sequentially from bottom (Row 9) to top (Row 0)
    final random = math.Random();
    for (int r = _rows - 1; r >= 0; r--) {
      if (!mounted) return;
      setState(() {
        _activeRow = r;
      });

      await Future.delayed(const Duration(milliseconds: 250));

      final int chosenCol = random.nextInt(_cols);

      setState(() {
        _grid[r][chosenCol].type = 1;
        _grid[r][chosenCol].isFlipped = true;
      });

      await Future.delayed(const Duration(milliseconds: 200));
    }

    setState(() {
      _activeRow = -1;
      _isPredicting = false;
      _totalWins += 1;
    });

    await _prefs.setInt('total_wins', _totalWins);
    _showNotification("تم فك تشفير مصفوفة الخانات بنجاح", false);
  }

  // Restore server grid
  void _restoreServer() async {
    if (_isPredicting || _isRestoring) return;

    bool hasApples = _grid.any((row) => row.any((cell) => cell.type == 1));
    if (!hasApples) {
      _showNotification("السيرفر مستعاد بالفعل ولا يوجد نتائج سابقة", true);
      return;
    }

    setState(() {
      _isRestoring = true;
    });

    // 1. Show Restoring Dialog
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "ServerRestore",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(anim1),
            child: HackerTerminalDialog(
              title: "RECOVERY_SYSTEM: STATE_RESET",
              commands: const [
                "RECOVERY INITIATED...",
                "DISCONNECTING SYSTEM HOOKS FROM SRV-09...",
                "FLUSHING CELL STATE BUFFERS...",
                "RE-ESTABLISHING ANTICHEAT CHECK INTEGRITY...",
                "PURGING PREVIOUS SCAN RESULTS...",
                "GRID CALIBRATION: SUCCESSFUL [OK]",
                "SYSTEM RESTORED TO DEFAULT ACTIVE STATE.",
              ],
            ),
          ),
        );
      },
    );

    // 2. Play reverse clean animation
    for (int r = 0; r < _rows; r++) {
      if (!mounted) return;
      setState(() {
        _activeRow = r;
      });

      for (int c = 0; c < _cols; c++) {
        if (_grid[r][c].type == 1) {
          setState(() {
            _grid[r][c].type = 0;
            _grid[r][c].isFlipped = false;
          });
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    }

    setState(() {
      _activeRow = -1;
      _isRestoring = false;
    });

    _showNotification("تمت استعادة حالة الاتصال الافتراضية", false);
  }

  Widget _buildTopChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2A2A35)),
      ),
      child: Text(
        "$label: $value",
        style: const TextStyle(
          color: Color(0xFF8888AA),
          fontSize: 10,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildServerCard(int index, String name, String uptime, String port, bool isActive) {
    final isSelected = _selectedServerMode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedServerMode = index;
          });
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0D0D1A) : const Color(0xFF0F0F12),
              border: Border.all(
                color: isSelected ? const Color(0xFF6C9EFF) : const Color(0xFF1E1E28),
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? const Color(0xFF4ADE80) : const Color(0xFF5A5A6E),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  uptime,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Colors.white,
                    fontFamily: 'Rajdhani',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  port,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Color(0xFF5A5A6E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridSlot(bool isFilled) {
    return SizedBox(
      width: 36,
      height: 36,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: isFilled
            ? Image.asset(
                "assets/cell_apple.png",
                key: const ValueKey("apple"),
                width: 36,
                height: 36,
                fit: BoxFit.contain,
              )
            : Image.asset(
                "assets/cell_default.png",
                key: const ValueKey("default"),
                width: 36,
                height: 36,
                fit: BoxFit.contain,
              ),
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Stack(
        children: [
          // Diagonal texture overlay
          Positioned.fill(
            child: CustomPaint(
              painter: DiagonalLineTexturePainter(),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Bar (operator ID & logout)
                Container(
                  color: const Color(0xFF0F0F12),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left: Logout minimal button
                          GestureDetector(
                            onTap: _logout,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF1E1E28)),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.logout,
                                color: Color(0xFF5A5A6E),
                                size: 16,
                              ),
                            ),
                          ),
                          // Center: App title
                          const Text(
                            "JOEX TOOL",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontFamily: 'Inter',
                            ),
                          ),
                          // Right: Circular Avatar
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF2A2A35),
                                width: 1.5,
                              ),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                "assets/app_logo.png",
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Chips list
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTopChip("TUNNEL", "11MS"),
                          const SizedBox(width: 8),
                          _buildTopChip("BYPASS", "STABLE"),
                          const SizedBox(width: 8),
                          _buildTopChip("SECURITY", "HIGH"),
                        ],
                      ),
                    ],
                  ),
                ),

                // Main Scrollable Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Operator Card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F0F12),
                              border: Border.all(color: const Color(0xFF1E1E28)),
                            ),
                            child: Row(
                              children: [
                                // Left: Custom rotating server icon
                                SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: RotationTransition(
                                    turns: _rotationController,
                                    child: CustomPaint(
                                      painter: RotatingServerPainter(
                                        color: const Color(0xFF6C9EFF),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Right: Text details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "OPERATOR ID",
                                        style: TextStyle(
                                          color: Color(0xFF5A5A6E),
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _userId,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1A1A28),
                                          border: Border.all(color: const Color(0xFF6C9EFF)),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          "${_selectedPlatformName.toUpperCase()} VIP",
                                          style: const TextStyle(
                                            color: Color(0xFF6C9EFF),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Multiplier Grid Title Section
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "PREDICTION MATRIX",
                              style: TextStyle(
                                color: Color(0xFF5A5A6E),
                                fontSize: 11,
                                fontFamily: 'monospace',
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(height: 6),
                            Divider(color: Color(0xFF1E1E28), height: 1, thickness: 1),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Multiplier Grid Matrix Container using individual cards with blue glow
                        Column(
                          children: List.generate(_rows, (rowIndex) {
                            final isRowActive = _activeRow == rowIndex;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F0F12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isRowActive ? const Color(0xFF6C9EFF) : const Color(0xFF1E1E28),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6C9EFF).withValues(
                                      alpha: isRowActive ? 0.20 : 0.08,
                                    ),
                                    blurRadius: isRowActive ? 10 : 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Multiplier Odds Card Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF141418),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF1E1E28)),
                                    ),
                                    child: Text(
                                      _odds[rowIndex],
                                      style: const TextStyle(
                                        color: Color(0xFF6C9EFF),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        fontFamily: 'Rajdhani',
                                      ),
                                    ),
                                  ),
                                  // 5 Icon Slots (RTL layout)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(_cols, (colIndex) {
                                      final cell = _grid[rowIndex][colIndex];
                                      final isFilled = cell.type == 1;
                                      return Padding(
                                        padding: const EdgeInsets.only(left: 8.0),
                                        child: _buildGridSlot(isFilled),
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 16),

                        // Server Selector Title
                        const Text(
                          "SELECT NODE",
                          style: TextStyle(
                            color: Color(0xFF5A5A6E),
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Server Selector Grid
                        Row(
                          children: [
                            _buildServerCard(0, "سيرفر متوازن", "${_balancedServerSuccess.toStringAsFixed(1)}%", "PORT-810", true),
                            const SizedBox(width: 10),
                            _buildServerCard(1, "سيرفر آمن", "${_secureServerSuccess.toStringAsFixed(1)}%", "PORT-8443", true),
                            const SizedBox(width: 10),
                            _buildServerCard(2, "سيرفر مخاطرة", "${_riskyServerSuccess.toStringAsFixed(1)}%", "PORT-902", false),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Action Buttons Row
                        Row(
                          children: [
                            // Secondary Button: استعادة السيرفر
                            Expanded(
                              child: GestureDetector(
                                onTapDown: (_) => setState(() => _restoreScale = 0.97),
                                onTapUp: (_) => setState(() => _restoreScale = 1.0),
                                onTapCancel: () => setState(() => _restoreScale = 1.0),
                                onTap: _restoreServer,
                                child: AnimatedScale(
                                  scale: _restoreScale,
                                  duration: const Duration(milliseconds: 100),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      height: 54,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF141418),
                                        border: Border.all(color: const Color(0xFF2A2A35)),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Text(
                                        "استعادة السيرفر",
                                        style: TextStyle(
                                          color: Color(0xFF8888AA),
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Primary Button: الدور القادم
                            Expanded(
                              child: GestureDetector(
                                onTapDown: (_) => setState(() => _predictScale = 0.97),
                                onTapUp: (_) => setState(() => _predictScale = 1.0),
                                onTapCancel: () => setState(() => _predictScale = 1.0),
                                onTap: _startNextRound,
                                child: AnimatedScale(
                                  scale: _predictScale,
                                  duration: const Duration(milliseconds: 100),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      height: 54,
                                      color: const Color(0xFF6C9EFF),
                                      alignment: Alignment.center,
                                      child: const Text(
                                        "الدور القادم",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
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
          ),
        ],
      ),
    );
  }
}

// Custom paint rotating server icon (circular outline + horizontal slots + status dots)
class RotatingServerPainter extends CustomPainter {
  final Color color;

  RotatingServerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double cy = h / 2;
    final double r = math.min(w, h) / 2;

    // Draw faint outer circle
    final paintRing = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(cx, cy), r, paintRing);

    // Draw 3 bold arcs to clearly showcase rotation
    final paintArcs = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (int i = 0; i < 3; i++) {
      final double startAngle = i * (2 * math.pi / 3);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle,
        math.pi / 4,
        false,
        paintArcs,
      );
    }

    // Draw a distributed network server topology in the center
    final paintCoreNode = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final paintPeripheralNode = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final paintLinkLine = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final paintPulseDot = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Center Core Server
    canvas.drawCircle(Offset(cx, cy), 3.5, paintCoreNode);

    // 3 Linked Peripheral Nodes
    final double nodeDistance = r * 0.55;
    for (int i = 0; i < 3; i++) {
      final double angle = i * (2 * math.pi / 3) - math.pi / 2;
      final double nx = cx + nodeDistance * math.cos(angle);
      final double ny = cy + nodeDistance * math.sin(angle);

      // Draw link line
      canvas.drawLine(Offset(cx, cy), Offset(nx, ny), paintLinkLine);

      // Draw peripheral node server box/circle
      canvas.drawCircle(Offset(nx, ny), 2.5, paintPeripheralNode);

      // Draw data transmission pulse dot at 50% along the link path
      final double px = cx + (nodeDistance * 0.5) * math.cos(angle);
      final double py = cy + (nodeDistance * 0.5) * math.sin(angle);
      canvas.drawCircle(Offset(px, py), 1.0, paintPulseDot);
    }
  }

  @override
  bool shouldRepaint(covariant RotatingServerPainter oldDelegate) => oldDelegate.color != color;
}

// Background diagonal lines pattern overlay (3% opacity)
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

// Cell state tracking
class CellState {
  int type; // 0: empty, 1: apple
  bool isFlipped;

  CellState({
    required this.type,
    this.isFlipped = false,
  });
}

// Blinking console cursor for dialog logs
class BlinkingConsoleCursor extends StatefulWidget {
  const BlinkingConsoleCursor({super.key});

  @override
  State<BlinkingConsoleCursor> createState() => _BlinkingConsoleCursorState();
}

class _BlinkingConsoleCursorState extends State<BlinkingConsoleCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value > 0.5 ? 1.0 : 0.0,
          child: Container(
            width: 6,
            height: 10,
            color: const Color(0xFF6C9EFF),
          ),
        );
      },
    );
  }
}

// Hacker terminal console simulator dialog
class HackerTerminalDialog extends StatefulWidget {
  final String title;
  final List<String> commands;

  const HackerTerminalDialog({
    super.key,
    required this.title,
    required this.commands,
  });

  @override
  State<HackerTerminalDialog> createState() => _HackerTerminalDialogState();
}

class _HackerTerminalDialogState extends State<HackerTerminalDialog> {
  final List<String> _visibleCommands = [];
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  int _currentIndex = 0;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _printNextCommand();
  }

  void _printNextCommand() {
    if (_currentIndex < widget.commands.length) {
      if (mounted) {
        setState(() {
          _visibleCommands.add(widget.commands[_currentIndex]);
          _currentIndex++;
        });
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });

      _timer = Timer(const Duration(milliseconds: 150), _printNextCommand);
    } else {
      if (mounted) {
        setState(() {
          _isComplete = true;
        });
      }
      _timer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: size.width * 0.88,
            height: size.height * 0.42,
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F12),
              border: Border.all(color: const Color(0xFF1E1E28), width: 1.0),
            ),
            child: Column(
              children: [
                // Title Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFF141418),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF6C9EFF), shape: BoxShape.circle)),
                        ],
                      ),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Color(0xFF6C9EFF),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                // Terminal output body
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _visibleCommands.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _visibleCommands.length) {
                          return _isComplete
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text(
                                    "ALL SYSTEMS STABLE. COORDINATES DECRYPTED.",
                                    style: TextStyle(
                                      color: Color(0xFF6C9EFF),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                )
                              : const Row(
                                  children: [
                                    Text(
                                      "> BYPASS_SYS: ",
                                      style: TextStyle(
                                        color: Color(0xFF6C9EFF),
                                        fontSize: 10,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    BlinkingConsoleCursor(),
                                  ],
                                );
                        }

                        final cmd = _visibleCommands[index];
                        final bool isError = cmd.contains("WARNING") || cmd.contains("FIREWALL");
                        final bool isSuccess = cmd.contains("SUCCESS") || cmd.contains("[OK]") || cmd.contains("COMPLETED");

                        Color cmdColor = const Color(0xFF8888AA);
                        if (isError) cmdColor = Colors.redAccent;
                        if (isSuccess) cmdColor = const Color(0xFF6C9EFF);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(
                            cmd,
                            style: TextStyle(
                              color: cmdColor,
                              fontSize: 10,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }
}
