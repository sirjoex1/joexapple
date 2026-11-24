import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════
// اختيارات المستخدم التي تغيّر شكل التطبيق كله: المنصة (ولونها) واللغة.
// تُقرأ قبل اول اطار وتُحفظ على الموبايل. عند تغيير اي منهما يُعاد بناء
// الشجرة كلها ورسمها، فتأخذ الالوان والنصوص والاتجاه القيم الجديدة حتى
// في القطع الثابتة (const) والرسامين الذين لا يعيدون الرسم وحدهم.
// ═══════════════════════════════════════════════════════════════

/// المنصات بترتيبها المحفوظ: الرقم في 'selected_platform' لا يتغير
enum Platform {
  oneXBet('1xBet', 'assets/platform_1.jpg', '1X'),
  melbet('MelBet', 'assets/platform_2.jpg', 'MLB'),
  linebet('Linebet', 'assets/platform_3.jpg', 'LB');

  final String label;
  final String asset;
  final String badge;
  const Platform(this.label, this.asset, this.badge);
}

class AppPrefs extends ChangeNotifier {
  AppPrefs._();
  static final AppPrefs instance = AppPrefs._();

  static const String platformKey = 'selected_platform';
  static const String langKey = 'app_lang';

  /// مثل مشروع gpt: 1xBet مختارة حتى يختار المستخدم غيرها
  Platform _platform = Platform.oneXBet;
  String _lang = 'ar';

  Platform get platform => _platform;
  String get lang => _lang;
  bool get isEn => _lang == 'en';
  TextDirection get dir => isEn ? TextDirection.ltr : TextDirection.rtl;

  /// يُنادى في main قبل runApp
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final p = prefs.getInt(platformKey);
      if (p != null && p >= 0 && p < Platform.values.length) {
        _platform = Platform.values[p];
      }
      final l = prefs.getString(langKey);
      if (l == 'en' || l == 'ar') _lang = l!;
    } catch (_) {
      // يبقى الافتراضي
    }
  }

  Future<void> setPlatform(Platform p) async {
    if (p == _platform) return;
    _platform = p;
    _changed();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(platformKey, p.index);
    } catch (_) {}
  }

  Future<void> setLang(String l) async {
    if (l == _lang || (l != 'ar' && l != 'en')) return;
    _lang = l;
    _changed();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(langKey, l);
    } catch (_) {}
  }

  Future<void> toggleLang() => setLang(isEn ? 'ar' : 'en');

  /// للاختبارات: يرجع الافتراضي بلا حفظ
  @visibleForTesting
  void reset({Platform platform = Platform.oneXBet, String lang = 'ar'}) {
    _platform = platform;
    _lang = lang;
  }

  void _changed() {
    notifyListeners();
    _refreshTree();
  }

  /// كل عنصر يُبنى من جديد وكل جسم يُرسم من جديد
  static void _refreshTree() {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return;
    void visit(Element e) {
      e.markNeedsBuild();
      if (e is RenderObjectElement) e.renderObject.markNeedsPaint();
      e.visitChildren(visit);
    }

    root.visitChildren(visit);
  }
}

/// النص باللغة المختارة: العربي اولا ثم الانجليزي
String tr(String ar, String en) => AppPrefs.instance.isEn ? en : ar;

/// اتجاه الصفحات باللغة المختارة
TextDirection get appDir => AppPrefs.instance.dir;
