import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../design/prefs.dart';

/// كلاس يمثل بيانات الزرار الثالث الديناميكي في الاشتراك الإجباري
class DynamicActionConfig {
  final String actionType; // 'like' | 'comment' | 'subscribe'
  final String title;
  final String subtitle;
  final String url;

  const DynamicActionConfig({
    required this.actionType,
    required this.title,
    required this.subtitle,
    required this.url,
  });

  /// العنوان المعروض: نص البوت بالعربي، وبالانجليزي عنوان النوع الثابت
  String get displayTitle => AppPrefs.instance.isEn
      ? DynamicLinkService.englishTitleForType(actionType)
      : title;

  /// الوصف المعروض بنفس الطريقة
  String get displaySubtitle => AppPrefs.instance.isEn
      ? DynamicLinkService.englishSubtitleForType(actionType)
      : subtitle;

  IconData get icon {
    switch (actionType) {
      case 'comment':
        return Icons.chat_bubble_outline_rounded;
      case 'subscribe':
        return Icons.notifications_active_rounded;
      case 'like':
      default:
        return Icons.thumb_up_alt_rounded;
    }
  }

  factory DynamicActionConfig.defaultConfig() {
    return const DynamicActionConfig(
      actionType: 'like',
      title: 'حط لايك للفيديو',
      subtitle: 'اضغط لمشاهدة ووضع إعجاب بالفيديو',
      url: DynamicLinkService.defaultVideoUrl,
    );
  }
}

/// خدمة جلب وتحديث إعدادات ورابط الزرار الثالث المتحكم به من بوت التليجرام
class DynamicLinkService {
  // رابط احتياطي افتراضي
  static const String defaultVideoUrl = 'https://www.youtube.com/@sirjoex11';

  // الرابط المباشر لـ JSONBin الخاص بك
  static String configEndpoint =
      'https://api.jsonbin.io/v3/b/6a9e31dfffd5d16053e79008/latest';

  // مفتاح الـ X-Master-Key لـ JSONBin
  static String jsonBinAccessKey =
      r'$2a$10$rrugZxHmirfHFkjWWnIgLeYKqhLSaIIlGt6Su2CZajvek5hzuqTeq';

  static const String _kTypeKey = 'cached_action_type';
  static const String _kTitleKey = 'cached_action_title';
  static const String _kSubtitleKey = 'cached_action_subtitle';
  static const String _kUrlKey = 'cached_action_url';

  static String defaultTitleForType(String type) {
    switch (type) {
      case 'comment':
        return 'حط كومنت على الفيديو';
      case 'subscribe':
        return 'اشتراك وتفعيل الجرس';
      case 'like':
      default:
        return 'حط لايك للفيديو';
    }
  }

  static String englishTitleForType(String type) {
    switch (type) {
      case 'comment':
        return 'Comment on the video';
      case 'subscribe':
        return 'Subscribe and turn on the bell';
      case 'like':
      default:
        return 'Like the video';
    }
  }

  static String englishSubtitleForType(String type) {
    switch (type) {
      case 'comment':
        return 'Tap to write a comment on the video';
      case 'subscribe':
        return 'Tap to subscribe and turn on the bell';
      case 'like':
      default:
        return 'Tap to watch and like the video';
    }
  }

  static String defaultSubtitleForType(String type) {
    switch (type) {
      case 'comment':
        return 'اضغط لكتابة تعليق على الفيديو';
      case 'subscribe':
        return 'اضغط للاشتراك بالقناة وتفعيل الجرس';
      case 'like':
      default:
        return 'اضغط لمشاهدة ووضع إعجاب بالفيديو';
    }
  }

  /// قراءة إعدادات الزرار الثالث المحفوظة محلياً في الذاكرة بشكل فوري وسريع
  static Future<DynamicActionConfig> getCachedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final type = prefs.getString(_kTypeKey) ?? 'like';
      final title = prefs.getString(_kTitleKey) ?? defaultTitleForType(type);
      final subtitle =
          prefs.getString(_kSubtitleKey) ?? defaultSubtitleForType(type);
      final url = prefs.getString(_kUrlKey) ?? defaultVideoUrl;

      return DynamicActionConfig(
        actionType: type,
        title: title,
        subtitle: subtitle,
        url: url,
      );
    } catch (_) {
      return DynamicActionConfig.defaultConfig();
    }
  }

  /// جلب أحدث إعدادات للزرار الثالث من خدمة الـ JSON في الخلفية
  static Future<DynamicActionConfig> fetchLatestConfig() async {
    if (configEndpoint.isEmpty || !configEndpoint.startsWith('http')) {
      return getCachedConfig();
    }

    try {
      final headers = <String, String>{'Accept': 'application/json'};
      if (jsonBinAccessKey.isNotEmpty) {
        headers['X-Master-Key'] = jsonBinAccessKey;
        headers['X-Access-Key'] = jsonBinAccessKey;
      }

      final uri = Uri.parse(configEndpoint);
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final record = (decoded['record'] is Map)
              ? decoded['record'] as Map
              : decoded;

          final type = record['action_type']?.toString().trim() ?? 'like';
          final title =
              record['action_title']?.toString().trim() ??
              defaultTitleForType(type);
          final subtitle =
              record['action_subtitle']?.toString().trim() ??
              defaultSubtitleForType(type);
          final url =
              record['action_url']?.toString().trim() ??
              record['video_url']?.toString().trim() ??
              record['url']?.toString().trim() ??
              defaultVideoUrl;

          final config = DynamicActionConfig(
            actionType: type,
            title: title.isNotEmpty ? title : defaultTitleForType(type),
            subtitle: subtitle.isNotEmpty
                ? subtitle
                : defaultSubtitleForType(type),
            url: url.startsWith('http') ? url : defaultVideoUrl,
          );

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kTypeKey, config.actionType);
          await prefs.setString(_kTitleKey, config.title);
          await prefs.setString(_kSubtitleKey, config.subtitle);
          await prefs.setString(_kUrlKey, config.url);

          return config;
        }
      }
    } catch (_) {}

    return getCachedConfig();
  }

  /// للتوافق مع أي استدعاء قديم
  static Future<String> getCachedVideoUrl() async {
    final cfg = await getCachedConfig();
    return cfg.url;
  }

  static Future<String> fetchLatestVideoUrl() async {
    final cfg = await fetchLatestConfig();
    return cfg.url;
  }
}
