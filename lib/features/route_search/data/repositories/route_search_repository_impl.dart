import '../../../../core/error/guard.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/search_query.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/repositories/route_search_repository.dart';
import '../datasources/route_search_data_source.dart';
import '../models/search_result_mapper.dart';

class RouteSearchRepositoryImpl implements RouteSearchRepository {
  const RouteSearchRepositoryImpl(this._source);

  final RouteSearchDataSource _source;

  @override
  Future<Result<SearchResult>> search(SearchQuery query) => guard(
    () async => SearchResultMapper.fromJson(await _source.search(query)),
  );
}
