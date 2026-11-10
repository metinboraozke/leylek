import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/result/result.dart';
import '../../domain/repositories/fare_calendar_repository.dart';

/// Tarih şeridinde gösterilen günlük fiyatlar ve hangi rotaya ait olduğu.
class FareCalendarState extends Equatable {
  const FareCalendarState({this.route = '', this.prices = const {}});

  /// `from|to`; rota değişince eski fiyatlar atılır.
  final String route;

  /// `2026-11-24` → fiyat (TRY).
  final Map<String, int> prices;

  int? priceOn(DateTime day) => prices[dayKey(day)];

  static String dayKey(DateTime day) => '${monthKey(day)}-${_two(day.day)}';

  static String monthKey(DateTime day) => '${day.year}-${_two(day.month)}';

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  List<Object?> get props => [route, prices];
}

/// Ayları ihtiyaç oldukça, rota başına bir kez yükler. Hata sessizdir:
/// fiyat gelmezse şerit yalnızca tarihleri gösterir.
class FareCalendarCubit extends Cubit<FareCalendarState> {
  FareCalendarCubit(this._repository) : super(const FareCalendarState());

  final FareCalendarRepository _repository;
  final Set<String> _requested = {};

  /// [from] ve [to] aramaya giden değerler (yer kimliği); [days] şeritte
  /// görünen günler.
  void ensure(String from, String to, Iterable<DateTime> days) {
    if (from.isEmpty || to.isEmpty) return;
    final route = '$from|$to';
    if (route != state.route) {
      _requested.clear();
      emit(FareCalendarState(route: route));
    }
    for (final month in days.map(FareCalendarState.monthKey).toSet()) {
      if (!_requested.add(month)) continue;
      _repository.month(from, to, month).then((result) {
        if (isClosed || state.route != route) return;
        if (result case Ok(:final value)) {
          emit(
            FareCalendarState(
              route: route,
              prices: {...state.prices, ...value},
            ),
          );
        }
      });
    }
  }
}
