import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/ai_diagnostic_screen.dart';
import 'screens/apple_screen.dart';
import 'widgets/network_wrapper.dart';
import 'design/design_system.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // الصفحات تمتد تحت شريط الحالة وشريط التنقل، وايقوناتهما فاتحة فوق الاسود
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  await AppPrefs.instance.load();
  await preloadBrandFonts();
  runApp(const MyApp());
}

enum _Screen { login, diagnostic, app }

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// الشاشة تحت الاستهلال، تُركّب عند انفتاح فتحته
  _Screen? _screen;
  bool _splashOn = true;

  /// يُقرأ من البداية حتى لا تتأخر الفتحة في آخر الاستهلال
  late final Future<_Screen> _next = _resolveNext();

  Future<_Screen> _resolveNext() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    final hasCompletedSub =
        prefs.getBool('has_completed_subscription') ?? false;
    final hasCompletedDiag =
        prefs.getBool('has_completed_diagnostic') ?? false;
    if (!isLoggedIn || !hasCompletedSub) return _Screen.login;
    if (!hasCompletedDiag) return _Screen.diagnostic;
    return _Screen.app;
  }

  Future<void> _onSplashReveal() async {
    final next = await _next;
    if (!mounted) return;
    setState(() => _screen = next);
  }

  void _onSplashComplete() {
    if (!mounted) return;
    setState(() => _splashOn = false);
  }

  Future<void> _onLoginComplete() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedDiag =
        prefs.getBool('has_completed_diagnostic') ?? false;
    setState(() => _screen = hasCompletedDiag ? _Screen.app : _Screen.diagnostic);
  }

  void _onDiagnosticComplete() {
    if (!mounted) return;
    setState(() => _screen = _Screen.app);
  }

  void _onLogout() {
    if (!mounted) return;
    setState(() => _screen = _Screen.login);
  }

  Widget _buildCurrentScreen() {
    switch (_screen!) {
      case _Screen.login:
        return LoginScreen(
          onLoginComplete: _onLoginComplete,
          heroVisible: !_splashOn,
        );
      case _Screen.diagnostic:
        return AiDiagnosticScreen(
          onDiagnosticComplete: _onDiagnosticComplete,
        );
      case _Screen.app:
        return JoeXApplePage(onLogout: _onLogout);
    }
  }

  /// الشاشة الجديدة تصعد من القاع والقديمة تتراجع الى الخلف وتعتم
  Widget _pageTransition(Widget child, Animation<double> animation) {
    final incoming = child.key == ValueKey(_screen);
    if (incoming) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      );
    }
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JoeX PRO',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      builder: (context, child) {
        return NetworkWrapper(child: child ?? const SizedBox.shrink());
      },
      home: ColoredBox(
        color: kInk,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // اول شاشة بلا انتقال: الفتحة نفسها هي دخولها
            if (_screen != null)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 680),
                reverseDuration: const Duration(milliseconds: 520),
                switchInCurve: Motion.emphasized,
                switchOutCurve: Motion.standard,
                transitionBuilder: _pageTransition,
                child: KeyedSubtree(
                  key: ValueKey(_screen),
                  child: _buildCurrentScreen(),
                ),
              ),
            if (_splashOn)
              JoeXSplashPage(
                key: const ValueKey('splash'),
                onReveal: _onSplashReveal,
                onComplete: _onSplashComplete,
              ),
          ],
        ),
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kJade,
        brightness: Brightness.dark,
        primary: kEmerald,
        secondary: kJade,
        surface: kCoal,
        error: kRose,
      ),
      scaffoldBackgroundColor: kInk,
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: kCoalHi,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          border: Border.all(color: kEmerald.withValues(alpha: 0.5)),
        ),
        textStyle: TextStyle(color: kEmeraldPale, fontSize: 12),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: kEmerald,
        selectionColor: kEmerald.withValues(alpha: 0.3),
        selectionHandleColor: kEmerald,
      ),
      useMaterial3: true,
    );
  }
}
