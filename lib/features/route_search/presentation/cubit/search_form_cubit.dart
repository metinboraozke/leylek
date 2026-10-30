import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../places/domain/entities/place.dart';
import '../../domain/entities/recent_search.dart';
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
    this.stopoverDays = 0,
  });

  final PlaceInput from;
  final PlaceInput to;
  final DateTime date;
  final int radiusKm;
  final int stopoverDays;

  SearchFormState copyWith({
    PlaceInput? from,
    PlaceInput? to,
    DateTime? date,
    int? radiusKm,
    int? stopoverDays,
  }) => SearchFormState(
    from: from ?? this.from,
    to: to ?? this.to,
    date: date ?? this.date,
    radiusKm: radiusKm ?? this.radiusKm,
    stopoverDays: stopoverDays ?? this.stopoverDays,
  );

  SearchQuery toQuery() => SearchQuery(
    from: from.value,
    to: to.value,
    date: date,
    radiusKm: radiusKm,
    stopoverDays: stopoverDays,
  );

  /// "Son aramalar"a yazılacak kayıt.
  RecentSearch toRecent() => RecentSearch(
    fromText: from.text,
    fromPlace: from.place,
    toText: to.text,
    toPlace: to.place,
    date: date,
    radiusKm: radiusKm,
    stopoverDays: stopoverDays,
  );

  @override
  List<Object?> get props => [from, to, date, radiusKm, stopoverDays];
}

/// Arama formunun durumu. Arama yapmaz; yalnızca formu tutar (SRP).
class SearchFormCubit extends Cubit<SearchFormState> {
  SearchFormCubit({required DateTime initialDate, SearchFormState? initial})
    : super(initial ?? SearchFormState(date: initialDate));

  /// Kullanıcı elle yazınca önceki seçim geçersiz olur.
  void typeFrom(String text) =>
      emit(state.copyWith(from: PlaceInput(text: text)));

  void typeTo(String text) => emit(state.copyWith(to: PlaceInput(text: text)));

  void selectFrom(Place place) => emit(
    state.copyWith(
      from: PlaceInput(text: place.label, place: place),
    ),
  );

  void selectTo(Place place) => emit(
    state.copyWith(
      to: PlaceInput(text: place.label, place: place),
    ),
  );

  void swap() => emit(state.copyWith(from: state.to, to: state.from));

  /// Son aramalardan birine dokununca form onunla doldurulur. Tarihi
  /// geçmişte kaldıysa formdaki tarih korunur.
  void restore(RecentSearch recent, {required DateTime today}) => emit(
    SearchFormState(
      // Eski kayıtlar "İstanbul (IST)" biçiminde; seçili yer güncel adla yazılır.
      from: PlaceInput(
        text: recent.fromPlace?.label ?? recent.fromText,
        place: recent.fromPlace,
      ),
      to: PlaceInput(
        text: recent.toPlace?.label ?? recent.toText,
        place: recent.toPlace,
      ),
      date: recent.date.isBefore(today) ? state.date : recent.date,
      radiusKm: recent.radiusKm,
      stopoverDays: recent.stopoverDays,
    ),
  );

  void setDate(DateTime date) => emit(state.copyWith(date: date));

  void setStopover(int days) => emit(
    state.copyWith(stopoverDays: days.clamp(0, SearchQuery.maxStopoverDays)),
  );

  void setRadius(int km) => emit(
    state.copyWith(
      radiusKm: km.clamp(SearchQuery.minRadiusKm, SearchQuery.maxRadiusKm),
    ),
  );
}
