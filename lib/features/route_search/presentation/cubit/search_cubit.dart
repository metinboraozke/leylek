import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/search_query.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/usecases/search_routes.dart';

sealed class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object?> get props => [];
}

final class SearchIdle extends SearchState {
  const SearchIdle();
}

final class SearchInProgress extends SearchState {
  const SearchInProgress(this.query);

  final SearchQuery query;

  @override
  List<Object?> get props => [query];
}

final class SearchSuccess extends SearchState {
  const SearchSuccess(this.query, this.result);

  final SearchQuery query;
  final SearchResult result;

  @override
  List<Object?> get props => [query, result];
}

final class SearchError extends SearchState {
  const SearchError(this.query, this.failure);

  final SearchQuery query;
  final Failure failure;

  @override
  List<Object?> get props => [query, failure];
}

/// Aramayı çalıştırır ve sonucu ekrana taşır.
class SearchCubit extends Cubit<SearchState> {
  SearchCubit(this._searchRoutes) : super(const SearchIdle());

  final SearchRoutes _searchRoutes;

  /// Kullanıcı arama sürerken yeniden ararsa eski yanıt yenisini ezmesin.
  int _generation = 0;

  Future<void> search(SearchQuery query) async {
    // Geçersiz girdide "aranıyor" durumuna hiç girilmez: uçuş animasyonu
    // başlamadan hata formdaki alanın altında görünür.
    final invalid = _searchRoutes.validate(query);
    if (invalid != null) {
      emit(SearchError(query, invalid));
      return;
    }

    final generation = ++_generation;
    emit(SearchInProgress(query));
    final result = await _searchRoutes(query);
    if (generation != _generation || isClosed) return;
    emit(switch (result) {
      Ok(:final value) => SearchSuccess(query, value),
      Err(:final failure) => SearchError(query, failure),
    });
  }

  Future<void> retry() async {
    final current = state;
    if (current is SearchError) await search(current.query);
  }

  /// Sonuç ekranından forma dönüş. Süren bir arama varsa sonucu yok sayılır.
  void reset() {
    _generation++;
    emit(const SearchIdle());
  }
}
