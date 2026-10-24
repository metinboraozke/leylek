import 'package:flutter_test/flutter_test.dart';
import 'package:leylek/core/error/failure.dart';
import 'package:leylek/core/result/result.dart';
import 'package:leylek/features/route_search/domain/entities/search_query.dart';
import 'package:leylek/features/route_search/domain/entities/search_result.dart';
import 'package:leylek/features/route_search/domain/repositories/route_search_repository.dart';
import 'package:leylek/features/route_search/domain/usecases/search_routes.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements RouteSearchRepository {}

void main() {
  final today = DateTime(2026, 10, 22, 15, 30);
  late _MockRepo repo;
  late SearchRoutes searchRoutes;

  SearchQuery query({
    String from = 'city:ist',
    String to = 'city:szg',
    DateTime? date,
    int radiusKm = 250,
    double maxGroundHours = 5,
  }) =>
      SearchQuery(
        from: from,
        to: to,
        date: date ?? DateTime(2026, 11, 20),
        radiusKm: radiusKm,
        maxGroundHours: maxGroundHours,
      );

  setUpAll(() => registerFallbackValue(query()));

  setUp(() {
    repo = _MockRepo();
    searchRoutes = SearchRoutes(repo, clock: () => today);
    when(() => repo.search(any())).thenAnswer(
      (_) async => const Ok(SearchResult(options: [], warnings: [], attribution: [])),
    );
  });

  Future<ValidationField?> invalidField(SearchQuery q) async {
    final r = await searchRoutes(q);
    return switch (r) {
      Err(failure: final ValidationFailure f) => f.field,
      _ => null,
    };
  }

  test('geçerli sorguyu depoya iletir', () async {
    final r = await searchRoutes(query());
    expect(r, isA<Ok<SearchResult>>());
    verify(() => repo.search(query())).called(1);
  });

  test('boş kalkış ve varışı reddeder', () async {
    expect(await invalidField(query(from: '  ')), ValidationField.from);
    expect(await invalidField(query(to: '')), ValidationField.to);
  });

  test('aynı kalkış ve varışı büyük-küçük harf ve aksandan bağımsız reddeder', () async {
    expect(await invalidField(query(from: 'Münih', to: 'MUNIH')), ValidationField.to);
  });

  test('bugünü kabul eder, dünü reddeder', () async {
    expect(await invalidField(query(date: DateTime(2026, 10, 22))), isNull);
    expect(await invalidField(query(date: DateTime(2026, 10, 21))), ValidationField.date);
  });

  test('330 günden ilerisini reddeder', () async {
    final limit = DateTime(2026, 10, 22).add(const Duration(days: 330));
    expect(await invalidField(query(date: limit)), isNull);
    expect(await invalidField(query(date: limit.add(const Duration(days: 1)))),
        ValidationField.date);
  });

  test('yarıçap ve kara süresi sınırlarını uygular', () async {
    expect(await invalidField(query(radiusKm: 49)), ValidationField.radius);
    expect(await invalidField(query(radiusKm: 401)), ValidationField.radius);
    expect(await invalidField(query(maxGroundHours: 0.5)), ValidationField.maxGroundHours);
  });

  test('geçersiz sorguda depoya hiç gitmez', () async {
    await searchRoutes(query(from: ''));
    verifyNever(() => repo.search(any()));
  });
}
