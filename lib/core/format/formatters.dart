import 'package:intl/intl.dart';

/// Ekranda gösterilen sayı, para ve saat biçimleri.
///
/// Tek yerde toplandı: "2 sa 12 dk" ile "2s 12d" ekrandan ekrana
/// değişmesin.
abstract final class Formatters {
  static String money(double amount, String currency) {
    final format = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: _symbols[currency] ?? '$currency ',
      decimalDigits: 0,
    );
    return format.format(amount);
  }

  static String duration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m dk';
    if (m == 0) return '$h sa';
    return '$h sa $m dk';
  }

  /// Yerel duvar saatinden "09:55".
  static String clock(DateTime wallClock) =>
      '${_two(wallClock.hour)}:${_two(wallClock.minute)}';

  /// "20 Kasım Cuma". `initializeDateFormatting('tr')` çağrılmış olmalı.
  static String day(DateTime date) =>
      DateFormat('d MMMM EEEE', 'tr').format(date);

  /// Arama kartındaki tarih: "4 Kas, Çar".
  static String cardDay(DateTime date) =>
      DateFormat('d MMM, EEE', 'tr').format(date);

  /// Son aramadaki tarih: "12 Kas".
  static String dayMonth(DateTime date) =>
      DateFormat('d MMM', 'tr').format(date);

  /// Biniş kartındaki kısa tarih: "20 Kas Cum".
  static String shortDay(DateTime date) =>
      DateFormat('d MMM EEE', 'tr').format(date);

  /// Türkçe bulunma eki: "Münih" → "Münih'te", "Salzburg" → "Salzburg'da",
  /// "Linz" → "Linz'de". Son ünlüye göre -da/-de, sert ünsüzle bitiyorsa
  /// -ta/-te.
  static String locative(String name) {
    final lower = name.toLowerCase();
    const back = 'aıou';
    const vowels = 'aeıioöuüâîû';
    var vowel = 'e';
    for (var i = lower.length - 1; i >= 0; i--) {
      if (vowels.contains(lower[i])) {
        vowel = back.contains(lower[i]) || lower[i] == 'â' ? 'a' : 'e';
        break;
      }
    }
    final last = lower.isEmpty ? '' : lower[lower.length - 1];
    final hard = 'fstkçşhp'.contains(last) && last.isNotEmpty;
    return "$name'${hard ? 't' : 'd'}$vowel";
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static const Map<String, String> _symbols = {'TRY': '₺', 'EUR': '€'};
}
