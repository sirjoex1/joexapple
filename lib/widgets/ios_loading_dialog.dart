import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// ديالوج تحميل بنمط آيفون الأصلي الصافي بدون نصوص
/// شاشة ضبابية زجاجية مع مؤشر دوران آبل الأيقوني فقط
class IosLoadingDialog extends StatelessWidget {
  const IosLoadingDialog({super.key});

  /// عرض ديالوج التحميل بنمط آيفون
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? subtitle,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      barrierLabel: 'IosLoadingDialog',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) => const IosLoadingDialog(),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// إغلاق ديالوج التحميل
  static void hide(BuildContext context) {
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xE6202024),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Center(
                child: CupertinoActivityIndicator(
                  radius: 16,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
