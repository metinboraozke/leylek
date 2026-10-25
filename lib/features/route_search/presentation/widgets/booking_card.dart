import 'package:url_launcher/url_launcher.dart';

/// "Rezervasyona git": sağlayıcının kendi sitesini uygulama içi
/// tarayıcıda açar (Android Custom Tabs, iOS SFSafariViewController);
/// kullanıcı geri dönünce sonuçlar yerinde durur. Bağlantılar ortaklık
/// işaretsiz ve yalnızca https.
Future<void> openBookingLink(Uri url) async {
  if (url.scheme != 'https') return;
  await launchUrl(url, mode: LaunchMode.inAppBrowserView);
}
