import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:leylek/app/dependencies.dart';
import 'package:leylek/app/leylek_app.dart';
import 'package:leylek/features/places/data/datasources/sample_places_data_source.dart';
import 'package:leylek/features/places/data/repositories/places_repository_impl.dart';
import 'package:leylek/features/places/domain/usecases/suggest_places.dart';
import 'package:leylek/features/route_search/data/datasources/sample_route_search_data_source.dart';
import 'package:leylek/features/route_search/data/repositories/route_search_repository_impl.dart';
import 'package:leylek/features/route_search/domain/usecases/search_routes.dart';
import 'package:leylek/features/route_search/presentation/motion.dart';
import 'package:leylek/features/route_search/presentation/widgets/flight_scene.dart';
import 'package:leylek/features/route_search/presentation/widgets/idle_stork.dart';
import 'package:leylek/features/route_search/presentation/widgets/results_carousel.dart';
import 'package:leylek/features/route_search/presentation/widgets/search_card.dart';
import 'package:leylek/features/route_search/presentation/widgets/standing_stork.dart';

/// Testte kısa süreler: kaybolma 100 ms, uçuş sahnesi 1 sn.
const _fast = SearchTiming(
  fadeOut: Duration(milliseconds: 100),
  flight: Duration(seconds: 1),
  reveal: Duration(milliseconds: 100),
);

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  AppDependencies sampleDeps({Duration latency = Duration.zero}) =>
      AppDependencies(
        suggestPlaces: SuggestPlaces(
          PlacesRepositoryImpl(const SamplePlacesDataSource()),
        ),
        searchRoutes: SearchRoutes(
          RouteSearchRepositoryImpl(
            SampleRouteSearchDataSource(latency: latency),
          ),
        ),
      );

  void phoneScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Animasyonlar sürekli döndüğü için pumpAndSettle kullanılamaz.
  Future<void> advance(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 50);
    for (var t = Duration.zero; t < total; t += step) {
      await tester.pump(step);
    }
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
    await advance(tester, const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(ListTile, option));
    await advance(tester, const Duration(milliseconds: 300));
  }

  Future<void> searchSalzburg(WidgetTester tester) async {
    await pickPlace(tester, 'from-field', 'İstan', 'İstanbul');
    await pickPlace(tester, 'to-field', 'salz', 'Salzburg');
    await tester.tap(find.byKey(const Key('search-button')));
    await tester.pump();
  }

  testWidgets('form ekranında arama kartı ve altta bekleyen leylek var', (
    tester,
  ) async {
    phoneScreen(tester);
    await tester.pumpWidget(
      LeylekApp(dependencies: sampleDeps(), timing: _fast),
    );
    await tester.pump();

    expect(find.byType(SearchCard), findsOneWidget);
    expect(find.byType(IdleStork), findsOneWidget);
    expect(find.byType(StandingStork), findsOneWidget);
    expect(find.text('Rotaları ara'), findsOneWidget);
  });

  testWidgets(
    'arama: form kaybolur, uçuş sahnesi oynar, sonra tam ekran slaytlar',
    (tester) async {
      phoneScreen(tester);
      await tester.pumpWidget(
        LeylekApp(dependencies: sampleDeps(), timing: _fast),
      );
      await searchSalzburg(tester);

      await advance(tester, const Duration(milliseconds: 300));
      expect(find.byType(FlightScene), findsOneWidget);
      expect(find.byType(SearchCard), findsNothing);

      // Veri hemen geldi ama sahne bir turunu tamamlamadan sonuç açılmaz.
      expect(find.byType(ResultsCarousel), findsNothing);

      await advance(tester, const Duration(milliseconds: 1500));
      expect(find.byType(ResultsCarousel), findsOneWidget);
      expect(find.byType(FlightScene), findsNothing);

      // İlk slayt: en ucuz rota, yeşil para rozeti, büyük başlık
      expect(find.text('İstanbul → Salzburg'), findsOneWidget);
      expect(find.text('1 / 4'), findsOneWidget);
      expect(find.byKey(const Key('badge-cheapest')), findsOneWidget);
      expect(find.byKey(const Key('badge-recommended')), findsNothing);
      expect(find.text('IST'), findsOneWidget);
      expect(find.text('MUC'), findsOneWidget);

      // Sağa kaydır: ikinci rota önerilen, mavi tik
      await tester.drag(
        find.byKey(const Key('results-pages')),
        const Offset(-250, 0),
      );
      await advance(tester, const Duration(milliseconds: 600));
      expect(find.text('2 / 4'), findsOneWidget);
      expect(find.byKey(const Key('badge-recommended')), findsOneWidget);

      // Biniş kartları: uçuş ve iki kara bacağı; "Rezervasyona git" ilgili
      // kartın içinde (Pegasus uçuşu ve ÖBB treni, IVB otobüsünün bağlantısı yok).
      expect(find.text('Pegasus'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('ÖBB'),
        300,
        scrollable: find.byType(Scrollable).at(1),
      );
      expect(find.text('ÖBB'), findsOneWidget);
      expect(find.text('Rezervasyona git'), findsNWidgets(2));
    },
  );

  testWidgets(
    'veri sahneden geç gelirse sahne tekrar eder, sonra sonuçlar açılır',
    (tester) async {
      phoneScreen(tester);
      await tester.pumpWidget(
        LeylekApp(
          dependencies: sampleDeps(latency: const Duration(milliseconds: 2500)),
          timing: _fast,
        ),
      );
      await searchSalzburg(tester);

      await advance(tester, const Duration(milliseconds: 1600));
      expect(find.byType(FlightScene), findsOneWidget);
      await advance(tester, const Duration(milliseconds: 1600));
      expect(find.byType(ResultsCarousel), findsOneWidget);
    },
  );

  testWidgets(
    'başını uzatan leyleğe dokununca forma dönülür, alanlar korunur',
    (tester) async {
      phoneScreen(tester);
      await tester.pumpWidget(
        LeylekApp(dependencies: sampleDeps(), timing: _fast),
      );
      await searchSalzburg(tester);
      await advance(tester, const Duration(milliseconds: 2000));

      await tester.tap(find.bySemanticsLabel('Yeni arama'));
      await advance(tester, const Duration(milliseconds: 400));
      expect(find.byType(SearchCard), findsOneWidget);
      expect(find.text('Salzburg (SZG)'), findsOneWidget);
    },
  );

  testWidgets('eksik varışta animasyon başlamaz, hata alanın altında', (
    tester,
  ) async {
    phoneScreen(tester);
    await tester.pumpWidget(
      LeylekApp(dependencies: sampleDeps(), timing: _fast),
    );
    await pickPlace(tester, 'from-field', 'İstan', 'İstanbul');
    await tester.tap(find.byKey(const Key('search-button')));
    await advance(tester, const Duration(milliseconds: 300));

    expect(find.byType(FlightScene), findsNothing);
    expect(find.text('Nereye gideceğini seç.'), findsOneWidget);
  });
}
