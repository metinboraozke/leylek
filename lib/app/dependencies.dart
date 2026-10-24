import '../core/config/app_config.dart';
import '../core/network/json_api.dart';
import '../features/places/data/datasources/places_data_source.dart';
import '../features/places/data/datasources/sample_places_data_source.dart';
import '../features/places/data/repositories/places_repository_impl.dart';
import '../features/places/domain/usecases/suggest_places.dart';
import '../features/route_search/data/datasources/route_search_data_source.dart';
import '../features/route_search/data/datasources/sample_route_search_data_source.dart';
import '../features/route_search/data/repositories/route_search_repository_impl.dart';
import '../features/route_search/domain/usecases/search_routes.dart';

/// Bileşim kökü: somut sınıfların birbirine bağlandığı tek yer.
///
/// Uygulamanın geri kalanı yalnızca arayüzleri bilir (DIP). Backend
/// adresi verilmişse gerçek API, verilmemişse örnek veri kaynakları
/// takılır; ekranlar farkı bilmez.
class AppDependencies {
  const AppDependencies({required this.suggestPlaces, required this.searchRoutes});

  factory AppDependencies.create(AppConfig config) {
    final PlacesDataSource places;
    final RouteSearchDataSource routes;
    if (config.useSampleData) {
      places = const SamplePlacesDataSource();
      routes = const SampleRouteSearchDataSource();
    } else {
      final api = DioJsonApi(baseUrl: config.apiBaseUrl);
      places = ApiPlacesDataSource(api);
      routes = ApiRouteSearchDataSource(api);
    }

    return AppDependencies(
      suggestPlaces: SuggestPlaces(PlacesRepositoryImpl(places)),
      searchRoutes: SearchRoutes(RouteSearchRepositoryImpl(routes)),
    );
  }

  final SuggestPlaces suggestPlaces;
  final SearchRoutes searchRoutes;
}
