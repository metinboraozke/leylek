import 'package:equatable/equatable.dart';

/// Saat dilimini kaybetmeyen zaman.
///
/// Backend saatleri yerel ofsetiyle gönderir (`2026-11-20T08:05:00+03:00`).
/// Dart'ın `DateTime.parse` sonucu UTC'ye çevirip ofseti atar; o zaman
/// İstanbul kalkışı telefonun saat diliminde görünürdü. Burada an (instant)
/// ile ofset ayrı tutulur ve ekranda havalimanının yerel saati gösterilir.
class ZonedTime extends Equatable implements Comparable<ZonedTime> {
  const ZonedTime({required this.instant, required this.offset});

  factory ZonedTime.parse(String iso) {
    final instant = DateTime.parse(iso).toUtc();
    final match = _offsetPattern.firstMatch(iso);
    if (match == null) {
      throw FormatException('Saat dilimi bilgisi yok', iso);
    }
    if (match.group(0) == 'Z') {
      return ZonedTime(instant: instant, offset: Duration.zero);
    }
    final sign = match.group(1) == '-' ? -1 : 1;
    final hours = int.parse(match.group(2)!);
    final minutes = int.parse(match.group(3)!);
    return ZonedTime(
      instant: instant,
      offset: Duration(hours: hours, minutes: minutes) * sign,
    );
  }

  static final RegExp _offsetPattern = RegExp(r'(?:([+-])(\d{2}):?(\d{2})|Z)$');

  /// UTC an.
  final DateTime instant;

  /// O yerin UTC'ye göre farkı.
  final Duration offset;

  /// Yerel duvar saati. Yalnızca gösterim içindir: `isUtc` true kalır,
  /// alanları (saat, dakika) yerel saati verir.
  DateTime get wallClock => instant.add(offset);

  Duration difference(ZonedTime other) => instant.difference(other.instant);

  @override
  int compareTo(ZonedTime other) => instant.compareTo(other.instant);

  @override
  List<Object?> get props => [instant, offset];
}
