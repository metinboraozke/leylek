import 'package:intl/intl.dart';

import '../l10n/strings.dart';

/// Ekranda gösterilen sayı, para ve saat biçimleri.
///
/// Tek yerde toplandı: "2 sa 12 dk" ile "2s 12d" ekrandan ekrana
/// değişmesin.
abstract final class Formatters {
  static String money(double amount, String currency) {
    final format = NumberFormat.currency(
      locale: S.isEnglish ? 'en' : 'tr_TR',
      symbol: _symbols[currency] ?? '$currency ',
      decimalDigits: 0,
    );
    return format.format(amount);
  }

  static String duration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final hu = S.t('sa', 'h');
    final mu = S.t('dk', 'min');
    if (h == 0) return '$m $mu';
    if (m == 0) return '$h $hu';
    return '$h $hu $m $mu';
  }

  /// Yerel duvar saatinden "09:55".
  static String clock(DateTime wallClock) =>
      '${_two(wallClock.hour)}:${_two(wallClock.minute)}';

  /// "20 Kasım Cuma" / "Friday 20 November". `initializeDateFormatting`
  /// iki dil için de çağrılmış olmalı.
  static String day(DateTime date) =>
      DateFormat(S.t('d MMMM EEEE', 'EEEE d MMMM'), S.intl).format(date);

  /// Arama kartındaki tarih: "4 Kas, Çar" / "Wed, 4 Nov".
  static String cardDay(DateTime date) =>
      DateFormat(S.t('d MMM, EEE', 'EEE, d MMM'), S.intl).format(date);

  /// Son aramadaki tarih: "12 Kas" / "12 Nov".
  static String dayMonth(DateTime date) =>
      DateFormat('d MMM', S.intl).format(date);

  /// Biniş kartındaki kısa tarih: "20 Kas Cum" / "Fri 20 Nov".
  static String shortDay(DateTime date) =>
      DateFormat(S.t('d MMM EEE', 'EEE d MMM'), S.intl).format(date);

  /// Kısa gün adı: "Pzt" / "Mon".
  static String weekday(DateTime date) =>
      DateFormat('EEE', S.intl).format(date);

  /// Sayı, dile göre binlik ayırıcıyla: "5.836" / "5,836".
  static String number(num value) =>
      NumberFormat.decimalPattern(S.isEnglish ? 'en' : 'tr_TR').format(value);

  /// Aktarma şehrinde kalış: "Münih'te 2 gün" / "2 days in Munich".
  static String stay(String city, int days) => S.isEnglish
      ? '$days ${days == 1 ? 'day' : 'days'} in $city'
      : '${locative(city)} $days gün';

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
