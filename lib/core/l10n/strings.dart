/// Uygulamanın dili: Türkçe ya da İngilizce.
///
/// Metinler kullanıldıkları yerde iki dilde yan yana yazılır:
/// `S.t('Gidiş', 'Departure')`. Böylece bir metni değiştiren öbür dili de
/// görür; ayrı bir çeviri dosyası ile kod birbirinden kopmaz. Dil
/// değişince uygulama ağacı yeniden kurulur (bkz. `LeylekApp`), bu yüzden
/// statik okuma yeterli.
///
/// Flutter'a bağlı değil: veri katmanı da kullanır ve o katman
/// `tool/e2e_api_contract.dart` ile saf Dart olarak çalışır.
abstract final class S {
  static const List<String> supported = ['tr', 'en'];

  static String _lang = 'tr';

  /// Etkin dil kodu: `tr` ya da `en`. Backend isteklerine de bu gider.
  static String get lang => _lang;

  static set lang(String value) =>
      _lang = supported.contains(value) ? value : 'tr';

  static bool get isEnglish => _lang == 'en';

  /// intl tarih ve sayı biçimleri için yerel ayar.
  static String get intl => isEnglish ? 'en' : 'tr';

  /// Etkin dildeki metin.
  static String t(String tr, String en) => isEnglish ? en : tr;

  /// Cihaz dili İngilizceyse İngilizce, diğer her durumda Türkçe.
  static String fromDevice(String languageCode) =>
      languageCode == 'en' ? 'en' : 'tr';
}
