import 'package:flutter_test/flutter_test.dart';
import 'package:leylek/core/result/result.dart';
import 'package:leylek/features/places/data/datasources/sample_places_data_source.dart';
import 'package:leylek/features/places/data/repositories/places_repository_impl.dart';
import 'package:leylek/features/places/domain/entities/place.dart';
import 'package:leylek/features/places/domain/repositories/places_repository.dart';
import 'package:leylek/features/places/domain/usecases/suggest_places.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PlacesRepository {}

void main() {
  test('iki harften kısa metinde depoya gitmez', () async {
    final repo = _MockRepo();
    final r = await SuggestPlaces(repo)(' m ');
    expect((r as Ok<List<Place>>).value, isEmpty);
    verifyNever(() => repo.suggest(any()));
  });

  test('örnek kaynak yerel ve İngilizce adla bulur', () async {
    final suggest = SuggestPlaces(
      PlacesRepositoryImpl(const SamplePlacesDataSource()),
    );

    final byTurkish = await suggest('münih');
    expect((byTurkish as Ok<List<Place>>).value.single.iata, 'MUC');

    final byEnglish = await suggest('Vienna');
    expect((byEnglish as Ok<List<Place>>).value.single.name, 'Viyana');

    final byCode = await suggest('szg');
    expect((byCode as Ok<List<Place>>).value.single.name, 'Salzburg');
  });
}
