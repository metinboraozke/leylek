/// Derleme sırasında `--dart-define` ile verilen ayarlar.
///
/// Örnek:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
///
/// Adres verilmezse uygulama örnek veriyle çalışır ve ekranda bunu
/// açıkça söyler. Backend hazır olmadan arayüz geliştirilebilsin diye.
class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  factory AppConfig.fromEnvironment() =>
      const AppConfig(apiBaseUrl: String.fromEnvironment('API_BASE_URL'));

  final String apiBaseUrl;

  bool get useSampleData => apiBaseUrl.isEmpty;
}
