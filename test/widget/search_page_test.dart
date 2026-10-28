import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:leylek/features/route_search/presentation/cubit/search_form_cubit.dart';
import 'package:leylek/features/route_search/presentation/motion.dart';
import 'package:leylek/features/route_search/presentation/widgets/flight_scene.dart';
import 'package:leylek/features/route_search/presentation/widgets/results_carousel.dart';
import 'package:leylek/features/route_search/presentation/widgets/search_card.dart';

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

  testWidgets('form ekranında arama kartı ve sol altta leylek var', (
    tester,
  ) async {
    phoneScreen(tester);
    await tester.pumpWidget(
      LeylekApp(dependencies: sampleDeps(), timing: _fast),
    );
    await tester.pump();

    expect(find.byType(SearchCard), findsOneWidget);
    expect(find.byKey(const Key('landing-stork')), findsOneWidget);
    expect(find.text('Rotaları ara'), findsOneWidget);
    // Henüz arama yapılmadı.
    expect(find.text('Son aramalar'), findsNothing);
  });

  testWidgets('yapılan arama son aramalara düşer, dokununca form dolar', (
    tester,
  ) async {
    phoneScreen(tester);
    await tester.pumpWidget(
      LeylekApp(dependencies: sampleDeps(), timing: _fast),
    );
    await searchSalzburg(tester);
    await advance(tester, const Duration(milliseconds: 2000));
    await tester.tap(find.byKey(const Key('back-to-search')));
    await advance(tester, const Duration(milliseconds: 400));

    expect(find.text('Son aramalar'), findsOneWidget);
    expect(find.text('İstanbul → Salzburg'), findsOneWidget);

    final form = BlocProvider.of<SearchFormCubit>(
      tester.element(find.byType(SearchCard)),
    );
    form.typeTo('');
    await tester.pump();
    await tester.tap(find.byKey(const Key('recent-0')));
    await tester.pump();
    expect(form.state.to.place?.name, 'Salzburg');
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
      // Yolculuk planı: her adımda ne ile ve şehir düzeyinde nereden nereye.
      expect(find.text('Yolculuk planı'), findsOneWidget);
      expect(find.text('Uçak → Banliyö → Bölgesel tren'), findsOneWidget);
      expect(find.text('İstanbul → Münih'), findsOneWidget);
      expect(find.text('Münih havalimanı → München Hbf'), findsOneWidget);
      expect(find.text('München Hbf → Salzburg'), findsOneWidget);

      // Biniş kartında kodun altında şehir adı.
      await tester.scrollUntilVisible(
        find.text('IST'),
        300,
        scrollable: find.byType(Scrollable).at(1),
      );
      expect(find.text('MUC'), findsOneWidget);
      expect(find.text('Münih'), findsOneWidget);

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
      await tester.scrollUntilVisible(
        find.text('Pegasus'),
        300,
        scrollable: find.byType(Scrollable).at(1),
      );
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

  testWidgets('sol üstteki geri düğmesi sonuçtan forma döner', (tester) async {
    phoneScreen(tester);
    await tester.pumpWidget(
      LeylekApp(dependencies: sampleDeps(), timing: _fast),
    );
    await searchSalzburg(tester);
    await advance(tester, const Duration(milliseconds: 2000));
    expect(find.byType(ResultsCarousel), findsOneWidget);

    await tester.tap(find.byKey(const Key('back-to-search')));
    await advance(tester, const Duration(milliseconds: 400));
    expect(find.byType(ResultsCarousel), findsNothing);
    expect(find.byType(SearchCard), findsOneWidget);
  });

  testWidgets('konaklama hapları formu günceller, seçilen tek olur', (
    tester,
  ) async {
    phoneScreen(tester);
    await tester.pumpWidget(
      LeylekApp(dependencies: sampleDeps(), timing: _fast),
    );
    await tester.pump();

    final context = tester.element(find.byType(SearchCard));
    final form = BlocProvider.of<SearchFormCubit>(context);
    expect(form.state.stopoverDays, 0);

    // Haplar yatay kaydırılan bir şeritte; ekran dışındakine kaydırılır.
    await tester.dragUntilVisible(
      find.byKey(const Key('stopover-2')),
      find.byKey(const Key('stopover-picker')),
      const Offset(-80, 0),
    );
    await tester.ensureVisible(find.byKey(const Key('stopover-2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('stopover-2')));
    await tester.pump();
    expect(form.state.stopoverDays, 2);
    expect(form.state.toQuery().stopoverDays, 2);
    await tester.dragUntilVisible(
      find.byKey(const Key('stopover-0')),
      find.byKey(const Key('stopover-picker')),
      const Offset(80, 0),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('stopover-0')));
    await tester.pump();
    expect(form.state.stopoverDays, 0);
  });

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
