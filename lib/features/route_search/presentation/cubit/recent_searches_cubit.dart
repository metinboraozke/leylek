import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/recent_search.dart';
import '../../domain/repositories/recent_searches_repository.dart';

/// Formun altındaki "Son arama" kartının kaynağı: en yeni başta, en fazla
/// [limit] kayıt.
class RecentSearchesCubit extends Cubit<List<RecentSearch>> {
  RecentSearchesCubit(this._repository) : super(const []) {
    _repository.load().then((items) {
      // Yükleme sürerken arama yapıldıysa yenisi kaybolmasın.
      if (!isClosed && state.isEmpty) emit(_trim(items));
    });
  }

  final RecentSearchesRepository _repository;

  static const int limit = 1;

  Future<void> add(RecentSearch search) async {
    final next = _trim([search, ...state.where((s) => !s.sameRouteAs(search))]);
    emit(next);
    await _repository.save(next);
  }

  static List<RecentSearch> _trim(List<RecentSearch> items) =>
      List.unmodifiable(items.take(limit));
}
