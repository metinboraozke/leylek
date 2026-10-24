import '../../../../core/error/guard.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/place.dart';
import '../../domain/repositories/places_repository.dart';
import '../datasources/places_data_source.dart';

class PlacesRepositoryImpl implements PlacesRepository {
  const PlacesRepositoryImpl(this._source);

  final PlacesDataSource _source;

  @override
  Future<Result<List<Place>>> suggest(String query) => guard(() async {
        final dtos = await _source.suggest(query);
        return dtos.map((dto) => dto.toEntity()).toList(growable: false);
      });
}
