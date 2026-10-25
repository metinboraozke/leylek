import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leylek/core/error/failure.dart';
import 'package:leylek/core/result/result.dart';
import 'package:leylek/features/route_search/domain/entities/search_query.dart';
import 'package:leylek/features/route_search/domain/entities/search_result.dart';
import 'package:leylek/features/route_search/domain/repositories/route_search_repository.dart';
import 'package:leylek/features/route_search/domain/usecases/search_routes.dart';
import 'package:leylek/features/route_search/presentation/cubit/search_cubit.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements RouteSearchRepository {}

void main() {
  final q1 = SearchQuery(
    from: 'city:ist',
    to: 'city:szg',
    date: DateTime(2026, 11, 20),
  );
  final q2 = SearchQuery(
    from: 'city:ist',
    to: 'city:inn',
    date: DateTime(2026, 11, 20),
  );
  const empty = SearchResult(options: [], warnings: [], attribution: []);
  const other = SearchResult(
    options: [],
    warnings: [SearchWarning.fewerThanThree],
    attribution: [],
  );

  late _MockRepo repo;
  SearchRoutes useCase() =>
      SearchRoutes(repo, clock: () => DateTime(2026, 10, 22));

  setUpAll(() => registerFallbackValue(q1));
  setUp(() => repo = _MockRepo());

  blocTest<SearchCubit, SearchState>(
    'başarılı aramada yükleniyor ve sonuç durumlarını yayar',
    setUp: () =>
        when(() => repo.search(q1)).thenAnswer((_) async => const Ok(empty)),
    build: () => SearchCubit(useCase()),
    act: (c) => c.search(q1),
    expect: () => [SearchInProgress(q1), SearchSuccess(q1, empty)],
  );

  blocTest<SearchCubit, SearchState>(
    'ağ hatasında hata durumu yayar, tekrar dene aynı sorguyu çalıştırır',
    setUp: () => when(
      () => repo.search(q1),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: () => SearchCubit(useCase()),
    act: (c) async {
      await c.search(q1);
      await c.retry();
    },
    expect: () => [
      SearchInProgress(q1),
      SearchError(q1, const NetworkFailure()),
      SearchInProgress(q1),
      SearchError(q1, const NetworkFailure()),
    ],
  );

  blocTest<SearchCubit, SearchState>(
    'geç gelen eski yanıt yeni aramanın sonucunu ezmez',
    setUp: () {
      final slow = Completer<Result<SearchResult>>();
      when(() => repo.search(q1)).thenAnswer((_) => slow.future);
      when(() => repo.search(q2)).thenAnswer((_) async {
        // Yeni arama bittikten sonra eski arama tamamlanıyor.
        scheduleMicrotask(() => slow.complete(const Ok(empty)));
        return const Ok(other);
      });
    },
    build: () => SearchCubit(useCase()),
    act: (c) async {
      unawaited(c.search(q1));
      await c.search(q2);
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      SearchInProgress(q1),
      SearchInProgress(q2),
      SearchSuccess(q2, other),
    ],
  );
}
