import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/design_system.dart';

class NetworkWrapper extends StatefulWidget {
  final Widget child;
  const NetworkWrapper({super.key, required this.child});

  @override
  State<NetworkWrapper> createState() => _NetworkWrapperState();
}

class _NetworkWrapperState extends State<NetworkWrapper> {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySub;
  bool _isDisconnected = false;
  bool _isChecking = false;
  bool _canShowDialog = false; // Grace period during startup
  Timer? _startupTimer;

  @override
  void initState() {
    super.initState();

    // Allow 5 seconds grace period on app launch before any disconnection dialog can appear
    _startupTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _canShowDialog = true);
        _checkConnectivity();
      }
    });

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      _handleConnectivityChange(results);
    });
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    _connectivitySub.cancel();
    super.dispose();
  }

  Future<void> _handleConnectivityChange(
    List<ConnectivityResult> results,
  ) async {
    if (!_canShowDialog) return;

    final hasNetworkInterface = results.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn,
    );

    if (hasNetworkInterface) {
      // Immediate restoration if network interface is detected
      if (_isDisconnected && mounted) {
        setState(() => _isDisconnected = false);
      }
      return;
    }

    // If interface reports NONE, wait 3 seconds before double-checking to prevent false alarms
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted || !_canShowDialog) return;

    final doubleCheckResults = await Connectivity().checkConnectivity();
    final stillNoInterface = !doubleCheckResults.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn,
    );

    if (stillNoInterface) {
      final isOnline = await _verifyInternetAccess();
      if (!isOnline && mounted) {
        setState(() => _isDisconnected = true);
      }
    }
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    await _handleConnectivityChange(results);
  }

  Future<bool> _verifyInternetAccess() async {
    // 1. Check socket to Cloudflare DNS 1.1.1.1
    try {
      final socket = await Socket.connect(
        '1.1.1.1',
        53,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      return true;
    } catch (_) {}

    // 2. Check socket to Google DNS 8.8.8.8
    try {
      final socket = await Socket.connect(
        '8.8.8.8',
        53,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      return true;
    } catch (_) {}

    // 3. Fallback DNS lookup
    try {
      final lookup = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 3));
      return lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } catch (_) {}

    return false;
  }

  Future<void> _retryConnection() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    // Re-verify network status
    final results = await Connectivity().checkConnectivity();
    final hasInterface = results.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn,
    );

    bool isOnline = hasInterface;
    if (!isOnline) {
      isOnline = await _verifyInternetAccess();
    }

    if (mounted) {
      setState(() {
        _isDisconnected = !isOnline;
        _isChecking = false;
      });
    }
  }

  void _exitApp() {
    SystemNavigator.pop();
    try {
      exit(0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: appDir,
      children: [
        widget.child,
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: Motion.slow,
            reverseDuration: Motion.medium,
            switchInCurve: Motion.emphasized,
            switchOutCurve: Motion.accelerate,
            transitionBuilder: (child, a) =>
                FadeTransition(opacity: a, child: child),
            child: _isDisconnected && _canShowDialog
                ? _offlineLayer()
                : const SizedBox.shrink(key: ValueKey('online')),
          ),
        ),
      ],
    );
  }

  /// الخلفية تعتم بينما تصعد الورقة من القاع
  Widget _offlineLayer() {
    return ColoredBox(
      key: const ValueKey('offline'),
      color: kInk.withValues(alpha: 0.7),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 0),
        duration: Motion.slow,
        curve: Motion.emphasized,
        builder: (context, v, child) => FractionalTranslation(
          translation: Offset(0, v * 0.5),
          child: child,
        ),
        child: RisingSheet(
          child: OfflineCard(
            onExit: _exitApp,
            onRetry: _isChecking ? null : _retryConnection,
            checking: _isChecking,
          ),
        ),
      ),
    );
  }
}

/// ورقة انقطاع الاتصال
class OfflineCard extends StatelessWidget {
  final VoidCallback onExit;
  final VoidCallback? onRetry;
  final bool checking;

  const OfflineCard({
    super.key,
    required this.onExit,
    required this.onRetry,
    required this.checking,
  });

  @override
  Widget build(BuildContext context) {
    return StaggerIn(
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: kRose.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: kRose.withValues(alpha: 0.5)),
              ),
              child: const Icon(Icons.wifi_off_rounded, color: kRose, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                tr('لا يوجد إنترنت', 'No internet'),
                style: headText(kWhite, 22, height: 1.3),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            tr(
              'يرجى التحقق من الإنترنت ثم إعادة المحاولة لمتابعة استخدام التطبيق.',
              'Check your connection, then try again to keep using the app.',
            ),
            style: bodyText(kMist, 13.5),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: PillButton(
            label: tr('إعادة المحاولة', 'Try again'),
            loading: checking,
            onPressed: onRetry,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onExit,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: 48,
            child: Center(
              child: Text(
                tr('خروج من التطبيق', 'Exit the app'),
                style: bodyText(kRose, 13, weight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
