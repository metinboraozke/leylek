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
import 'package:leylek/features/route_search/presentation/widgets/route_card.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  AppDependencies sampleDeps() => AppDependencies(
        suggestPlaces: SuggestPlaces(PlacesRepositoryImpl(const SamplePlacesDataSource())),
        searchRoutes: SearchRoutes(
          RouteSearchRepositoryImpl(const SampleRouteSearchDataSource(latency: Duration.zero)),
        ),
      );

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pickPlace(WidgetTester tester, String fieldKey, String text, String option) async {
    await tester.enterText(
      find.descendant(of: find.byKey(Key(fieldKey)), matching: find.byType(TextField)),
      text,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, option));
    await tester.pumpAndSettle();
  }

  testWidgets('arama en az 3 kartı en ucuzdan pahalıya ve önerilenle gösterir', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(LeylekApp(dependencies: sampleDeps()));

    await pickPlace(tester, 'from-field', 'İstan', 'İstanbul');
    await pickPlace(tester, 'to-field', 'salz', 'Salzburg');
    await tester.tap(find.byKey(const Key('search-button')));
    await tester.pumpAndSettle();

    final cards = find.byType(RouteCard);
    expect(cards, findsNWidgets(3));

    final prices = tester
        .widgetList<RouteCard>(cards)
        .map((c) => c.option.total.price.amount)
        .toList();
    expect(prices, [...prices]..sort());

    expect(find.text('Önerilen'), findsOneWidget);
    expect(find.text('En ucuz'), findsOneWidget);
    expect(find.text('En hızlı'), findsOneWidget);
    expect(find.textContaining('Örnek veri'), findsOneWidget);
    expect(find.textContaining('Transitous'), findsOneWidget);
  });

  testWidgets('boş varışta istek atmadan alan altında hata gösterir', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(LeylekApp(dependencies: sampleDeps()));

    await pickPlace(tester, 'from-field', 'İstan', 'İstanbul');
    await tester.tap(find.byKey(const Key('search-button')));
    await tester.pumpAndSettle();

    expect(find.text('Nereye gideceğini seç.'), findsOneWidget);
    expect(find.byType(RouteCard), findsNothing);
  });
}
