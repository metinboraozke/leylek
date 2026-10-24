import '../../../../core/result/result.dart';
import '../entities/place.dart';

/// Yer önerileri kaynağı. Uygulaması veri katmanında.
abstract interface class PlacesRepository {
  Future<Result<List<Place>>> suggest(String query);
}
