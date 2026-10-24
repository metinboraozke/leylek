/// Arama için metni sadeleştirir: küçük harf, aksansız, tek boşluk.
///
/// "Münih", "munih" ve "MÜNİH" aynı sonucu bulsun diye. Türkçe büyük
/// "İ" ve "I" harfleri `toLowerCase` ile yanlış çevrildiği için önce
/// elle değiştirilir.
String normalizeForSearch(String input) {
  final buffer = StringBuffer();
  for (final rune in input.replaceAll('İ', 'i').replaceAll('I', 'ı').runes) {
    final char = String.fromCharCode(rune).toLowerCase();
    buffer.write(_folds[char] ?? char);
  }
  return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

const Map<String, String> _folds = {
  'ı': 'i',
  'ğ': 'g',
  'ü': 'u',
  'ş': 's',
  'ö': 'o',
  'ç': 'c',
  'â': 'a',
  'î': 'i',
  'û': 'u',
  'ä': 'a',
  'á': 'a',
  'à': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'í': 'i',
  'ó': 'o',
  'ô': 'o',
  'ú': 'u',
  'ß': 'ss',
  'ñ': 'n',
  'ø': 'o',
  'å': 'a',
  'ł': 'l',
  'č': 'c',
  'ř': 'r',
  'ž': 'z',
  'š': 's',
};
