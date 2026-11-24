import 'package:url_launcher/url_launcher.dart';

// ═══════════════════════════════════════════════════════════════
// الروابط ورمز الترويج في مكان واحد: صفحة الدخول وصفحة السكريبت تقرآن منه.
// رابط التسجيل والرمز هما نفس قيم مشروع gpt لكل المنصات.
// ═══════════════════════════════════════════════════════════════

const String kYoutubeUrl = 'https://youtube.com/@joexxvc';
const String kTelegramUrl = 'https://t.me/elostora_vip';
const String kTelegramHandle = '@elostora_vip';
const String kYoutubeHandle = '@joexxvc';

/// رمز الترويج الذي يُنسخ ويُكتب في المنصة
const String kPromoCode = 'joe27';

/// رابط التسجيل في المنصة برمز الترويج
const String kRegLink =
    'https://refpa-65760.com/L?tag=d_4906381m_1599c_JOE27&site=4906381&ad=1599&r=registration';

/// الدعم على تليجرام
const String kHelpLink = 'https://t.me/joe27';

/// يفتح الرابط في تطبيقه (تليجرام او يوتيوب او المتصفح)، وبغيره اذا تعذر
Future<void> openUrl(String url) async {
  final uri = Uri.parse(url);
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  } catch (_) {
    try {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {}
  }
}
