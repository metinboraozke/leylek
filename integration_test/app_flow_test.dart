// Gerçek cihazda/emülatörde uçtan uca kullanıcı akışı.
//
//   flutter test integration_test -d <cihaz>
//   flutter test integration_test -d <cihaz> --dart-define=API_BASE_URL=http://10.0.2.2:8080
//
// Adres verilmezse örnek veriyle, verilirse gerçek backend'le koşar.
// Animasyonlar gerçek sürelerinde oynar; sahne en az bir tur döner.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:leylek/app/dependencies.dart';
import 'package:leylek/app/leylek_app.dart';
import 'package:leylek/core/config/app_config.dart';
import 'package:leylek/features/route_search/presentation/widgets/flight_scene.dart';
import 'package:leylek/features/route_search/presentation/widgets/results_carousel.dart';
import 'package:leylek/features/route_search/presentation/widgets/search_card.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('tr'));

  /// Sürekli dönen animasyonlar yüzünden pumpAndSettle bitmez; koşul
  /// sağlanana kadar kare kare ilerlenir.
  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Zaman aşımı: $finder');
  }

  Future<void> pickPlace(
    WidgetTester tester,
    String fieldKey,
    String text,
    String option,
  ) async {
    await tester.enterText(
      find.descendant(
        of: find.byKey(Key(fieldKey)),
        matching: find.byType(TextField),
      ),
      text,
    );
    final tile = find.widgetWithText(ListTile, option);
    await pumpUntil(tester, tile, timeout: const Duration(seconds: 10));
    await tester.tap(tile.first);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'İstanbul → Salzburg: ara, sahneyi izle, slaytları gez, forma dön',
    (tester) async {
      final deps = AppDependencies.create(AppConfig.fromEnvironment());
      await tester.pumpWidget(LeylekApp(dependencies: deps));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SearchCard), findsOneWidget);

      await pickPlace(tester, 'from-field', 'İstan', 'İstanbul');
      await pickPlace(tester, 'to-field', 'salz', 'Salzburg');
      await tester.tap(find.byKey(const Key('search-button')));

      await pumpUntil(tester, find.byType(FlightScene));
      await pumpUntil(tester, find.byType(ResultsCarousel));
      expect(find.byKey(const Key('badge-cheapest')), findsOneWidget);

      final pages = find.textContaining(RegExp(r'^1 / \d$'));
      expect(pages, findsOneWidget);
      final total = int.parse(
        (tester.widget<Text>(pages).data ?? '1 / 1').split('/').last.trim(),
      );
      expect(total, inInclusiveRange(1, 4));

      for (var i = 2; i <= total; i++) {
        await tester.drag(
          find.byKey(const Key('results-pages')),
          const Offset(-300, 0),
        );
        await pumpUntil(
          tester,
          find.text('$i / $total'),
          timeout: const Duration(seconds: 5),
        );
      }

      await tester.tap(find.bySemanticsLabel('Yeni arama'));
      await pumpUntil(
        tester,
        find.byType(SearchCard),
        timeout: const Duration(seconds: 5),
      );
    },
  );
}
