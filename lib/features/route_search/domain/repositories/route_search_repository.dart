import '../../../../core/result/result.dart';
import '../entities/search_query.dart';
import '../entities/search_result.dart';

abstract interface class RouteSearchRepository {
  Future<Result<SearchResult>> search(SearchQuery query);
}
