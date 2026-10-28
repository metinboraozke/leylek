import 'package:flutter_test/flutter_test.dart';
import 'package:leylek/features/route_search/data/repositories/recent_searches_repository_impl.dart';
import 'package:leylek/features/route_search/domain/entities/recent_search.dart';
import 'package:leylek/features/route_search/presentation/cubit/recent_searches_cubit.dart';

RecentSearch _search(String from, String to, {int day = 1}) => RecentSearch(
  fromText: from,
  toText: to,
  date: DateTime(2026, 12, day),
  radiusKm: 250,
  stopoverDays: 0,
);

void main() {
  test('en fazla iki kayıt tutar, en yeni başta', () async {
    final repo = InMemoryRecentSearchesRepository();
    final cubit = RecentSearchesCubit(repo);
    await cubit.add(_search('İstanbul', 'Salzburg'));
    await cubit.add(_search('Ankara', 'Lyon'));
    await cubit.add(_search('İzmir', 'Bari'));

    expect(cubit.state.map((s) => s.toName), ['Bari', 'Lyon']);
    expect((await repo.load()).length, 2);
  });

  test('aynı rota tekrar aranınca eskisi silinir, yenisi başa geçer', () async {
    final cubit = RecentSearchesCubit(InMemoryRecentSearchesRepository());
    await cubit.add(_search('İstanbul', 'Salzburg'));
    await cubit.add(_search('Ankara', 'Lyon'));
    await cubit.add(_search('istanbul', 'salzburg', day: 9));

    expect(cubit.state.length, 2);
    expect(cubit.state.first.date, DateTime(2026, 12, 9));
    expect(cubit.state.last.toName, 'Lyon');
  });

  test('açılışta depodaki kayıtları yükler', () async {
    final cubit = RecentSearchesCubit(
      InMemoryRecentSearchesRepository([_search('Ankara', 'Lyon')]),
    );
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.single.toName, 'Lyon');
  });
}
