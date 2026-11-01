import 'package:flutter_test/flutter_test.dart';
import 'package:leylek/features/places/domain/entities/place.dart';
import 'package:leylek/features/route_search/domain/entities/search_query.dart';
import 'package:leylek/features/route_search/presentation/cubit/search_form_cubit.dart';

const _madrid = Place(
  id: 'city:3117735',
  name: 'Madrid',
  countryCode: 'ES',
  countryName: 'İspanya',
  kind: PlaceKind.city,
  iata: 'MAD',
  radiusKm: 450,
);
const _amsterdam = Place(
  id: 'city:2759794',
  name: 'Amsterdam',
  countryCode: 'NL',
  countryName: 'Hollanda',
  kind: PlaceKind.city,
  iata: 'AMS',
  radiusKm: 200,
);

void main() {
  SearchFormCubit cubit() => SearchFormCubit(initialDate: DateTime(2026, 12));

  test('varış seçilince yarıçap ülkeninkine geçer', () {
    final form = cubit();
    expect(form.state.radiusKm, SearchQuery.defaultRadiusKm);
    form.selectTo(_madrid);
    expect(form.state.radiusKm, 450);
    form.selectTo(_amsterdam);
    expect(form.state.radiusKm, 200);
  });

  test('elle seçilen yarıçapa varış değişince dokunulmaz', () {
    final form = cubit()..selectTo(_madrid);
    form.setRadius(150);
    form.selectTo(_amsterdam);
    expect(form.state.radiusKm, 150);
  });

  test('yer değiştirince yeni varışın yarıçapı gelir', () {
    final form = cubit()
      ..selectFrom(_madrid)
      ..selectTo(_amsterdam);
    expect(form.state.radiusKm, 200);
    form.swap();
    expect(form.state.to.place, _madrid);
    expect(form.state.radiusKm, 450);
  });
}
