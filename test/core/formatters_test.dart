import 'package:flutter_test/flutter_test.dart';
import 'package:leylek/core/format/formatters.dart';

void main() {
  test('bulunma eki ünlü uyumu ve sert ünsüze göre seçilir', () {
    expect(Formatters.locative('Münih'), "Münih'te");
    expect(Formatters.locative('Salzburg'), "Salzburg'da");
    expect(Formatters.locative('Linz'), "Linz'de");
    expect(Formatters.locative('Innsbruck'), "Innsbruck'ta");
    expect(Formatters.locative('Viyana'), "Viyana'da");
    expect(Formatters.locative('Prag'), "Prag'da");
  });
}
