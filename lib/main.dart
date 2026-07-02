import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/apple_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool? _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn == null) {
      // Premium dark loading indicator while checking local storage session
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF0A0A0E),
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE2E8F0)),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'JOEX TOOL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE2E8F0),
          brightness: Brightness.dark,
          primary: const Color(0xFFE2E8F0),
          secondary: const Color(0xFF718096),
          surface: const Color(0xFF16161F),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0A0E),
        useMaterial3: true,
      ),
      home: _isLoggedIn!
          ? const JoeXApplePage()
          : Builder(
              builder: (context) {
                return JoeXSplashPage(
                  onComplete: () {
                    // Custom premium transition: Fade and Scale into the Cyberpunk Login Screen
                    Navigator.of(context).pushReplacement(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => JoeXLoginPage(
                          onComplete: () async {
                            // Save session state locally
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('is_logged_in', true);

                            // Transition directly to the JoeX APPLE Screen
                            if (context.mounted) {
                              Navigator.of(context).pushReplacement(
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => const JoeXApplePage(),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
                                      CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                                    );
                                    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                                      CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                                    );
                                    return FadeTransition(
                                      opacity: fadeAnimation,
                                      child: ScaleTransition(
                                        scale: scaleAnimation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  transitionDuration: const Duration(milliseconds: 700),
                                ),
                              );
                            }
                          },
                        ),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
                            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                          );
                          final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                            CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                          );
                          return FadeTransition(
                            opacity: fadeAnimation,
                            child: ScaleTransition(
                              scale: scaleAnimation,
                              child: child,
                            ),
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 700),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
