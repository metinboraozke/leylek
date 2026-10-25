import 'package:flutter_test/flutter_test.dart';
import 'package:leylek/core/time/zoned_time.dart';

void main() {
  group('ZonedTime.parse', () {
    test('ofseti korur ve yerel saati verir', () {
      final t = ZonedTime.parse('2026-11-20T08:05:00+03:00');
      expect(t.offset, const Duration(hours: 3));
      expect(t.instant, DateTime.utc(2026, 11, 20, 5, 5));
      expect(t.wallClock.hour, 8);
      expect(t.wallClock.minute, 5);
    });

    test('negatif ofset ve Z biçimini okur', () {
      expect(
        ZonedTime.parse('2026-11-20T08:05:00-04:30').offset,
        const Duration(hours: -4, minutes: -30),
      );
      expect(ZonedTime.parse('2026-11-20T08:05:00Z').offset, Duration.zero);
    });

    test('farklı dilimlerdeki iki saat arasındaki gerçek süreyi hesaplar', () {
      final depart = ZonedTime.parse('2026-11-20T08:05:00+03:00');
      final arrive = ZonedTime.parse('2026-11-20T09:55:00+01:00');
      expect(arrive.difference(depart), const Duration(hours: 3, minutes: 50));
    });

    test('ofseti olmayan metni reddeder', () {
      expect(
        () => ZonedTime.parse('2026-11-20T08:05:00'),
        throwsFormatException,
      );
    });
  });
}
