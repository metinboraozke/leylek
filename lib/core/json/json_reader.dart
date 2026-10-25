/// JSON okurken tür hatasını anahtar adıyla bildiren yardımcılar.
///
/// `strict-casts` açık olduğu için her alan açıkça dönüştürülmeli.
/// Bunu her DTO'da tekrar yazmak yerine burada bir kez yazıyoruz;
/// hata mesajı hangi alanın bozuk olduğunu söylüyor.
typedef Json = Map<String, dynamic>;

extension JsonReader on Json {
  T _read<T>(String key) {
    final value = this[key];
    if (value is T) return value;
    throw FormatException('"$key" alanı beklenen türde değil: $value');
  }

  String str(String key) => _read<String>(key);

  String? strOrNull(String key) => this[key] == null ? null : str(key);

  int integer(String key) => _read<num>(key).toInt();

  int? integerOrNull(String key) => this[key] == null ? null : integer(key);

  double number(String key) => _read<num>(key).toDouble();

  double? numberOrNull(String key) => this[key] == null ? null : number(key);

  bool boolean(String key, {bool fallback = false}) =>
      this[key] == null ? fallback : _read<bool>(key);

  Json obj(String key) => _read<Map<String, dynamic>>(key);

  Json? objOrNull(String key) => this[key] == null ? null : obj(key);

  List<Json> objList(String key) {
    final value = this[key];
    if (value == null) return const [];
    if (value is! List) {
      throw FormatException('"$key" alanı liste değil: $value');
    }
    return value
        .map((item) {
          if (item is Map<String, dynamic>) return item;
          throw FormatException('"$key" listesinde nesne olmayan öğe: $item');
        })
        .toList(growable: false);
  }

  List<String> strList(String key) {
    final value = this[key];
    if (value == null) return const [];
    if (value is! List) {
      throw FormatException('"$key" alanı liste değil: $value');
    }
    return value.map((item) => item.toString()).toList(growable: false);
  }
}
