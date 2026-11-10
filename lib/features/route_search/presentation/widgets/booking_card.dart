import 'package:url_launcher/url_launcher.dart';

/// "Rezervasyona git": sağlayıcının kendi sitesini uygulama içi
/// tarayıcıda açar (Android Custom Tabs, iOS SFSafariViewController);
/// kullanıcı geri dönünce sonuçlar yerinde durur. Bağlantılar ortaklık
/// işaretsiz ve yalnızca https.
///
/// Haritalar bağlantısı ([external]) uygulama içinde değil, Google
/// Haritalar uygulamasında (yoksa tarayıcıda) açılır.
Future<void> openBookingLink(Uri url, {bool external = false}) async {
  if (url.scheme != 'https') return;
  await launchUrl(
    url,
    mode: external
        ? LaunchMode.externalApplication
        : LaunchMode.inAppBrowserView,
  );
}
