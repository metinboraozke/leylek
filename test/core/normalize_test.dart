import 'package:flutter_test/flutter_test.dart';
import 'package:leylek/core/text/normalize.dart';

void main() {
  test('Türkçe ve Avrupa harflerini sadeleştirir', () {
    expect(normalizeForSearch('İSTANBUL'), 'istanbul');
    expect(normalizeForSearch('Münih'), 'munih');
    expect(normalizeForSearch('München'), 'munchen');
    expect(normalizeForSearch('  Kraków   Główny '), 'krakow glowny');
    expect(normalizeForSearch('IĞDIR'), 'igdir');
  });
}
