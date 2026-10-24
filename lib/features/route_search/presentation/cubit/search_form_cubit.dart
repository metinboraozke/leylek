import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../places/domain/entities/place.dart';
import '../../domain/entities/search_query.dart';

/// Bir yer alanının içeriği: yazılan metin ve varsa listeden seçilen yer.
class PlaceInput extends Equatable {
  const PlaceInput({this.text = '', this.place});

  final String text;
  final Place? place;

  /// Aramaya giden değer: seçilmiş yerin kimliği, yoksa yazılan metin.
  String get value => place?.id ?? text.trim();

  @override
  List<Object?> get props => [text, place];
}

class SearchFormState extends Equatable {
  const SearchFormState({
    required this.date,
    this.from = const PlaceInput(),
    this.to = const PlaceInput(),
    this.radiusKm = SearchQuery.defaultRadiusKm,
  });

  final PlaceInput from;
  final PlaceInput to;
  final DateTime date;
  final int radiusKm;

  SearchFormState copyWith({
    PlaceInput? from,
    PlaceInput? to,
    DateTime? date,
    int? radiusKm,
  }) =>
      SearchFormState(
        from: from ?? this.from,
        to: to ?? this.to,
        date: date ?? this.date,
        radiusKm: radiusKm ?? this.radiusKm,
      );

  SearchQuery toQuery() => SearchQuery(
        from: from.value,
        to: to.value,
        date: date,
        radiusKm: radiusKm,
      );

  @override
  List<Object?> get props => [from, to, date, radiusKm];
}

/// Arama formunun durumu. Arama yapmaz; yalnızca formu tutar (SRP).
class SearchFormCubit extends Cubit<SearchFormState> {
  SearchFormCubit({required DateTime initialDate, SearchFormState? initial})
      : super(initial ?? SearchFormState(date: initialDate));

  /// Kullanıcı elle yazınca önceki seçim geçersiz olur.
  void typeFrom(String text) => emit(state.copyWith(from: PlaceInput(text: text)));

  void typeTo(String text) => emit(state.copyWith(to: PlaceInput(text: text)));

  void selectFrom(Place place) =>
      emit(state.copyWith(from: PlaceInput(text: place.label, place: place)));

  void selectTo(Place place) =>
      emit(state.copyWith(to: PlaceInput(text: place.label, place: place)));

  void swap() => emit(state.copyWith(from: state.to, to: state.from));

  void setDate(DateTime date) => emit(state.copyWith(date: date));

  void setRadius(int km) => emit(state.copyWith(
        radiusKm: km.clamp(SearchQuery.minRadiusKm, SearchQuery.maxRadiusKm),
      ));
}
