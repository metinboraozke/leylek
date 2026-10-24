import '../../../../core/result/result.dart';
import '../../../../core/usecase/use_case.dart';
import '../entities/place.dart';
import '../repositories/places_repository.dart';

/// Yazılan metne göre yer önerir.
///
/// İki harften kısa metinlerde depoya hiç gidilmez: "i" yazınca yüzlerce
/// sonuç dönmesi kimseye yaramaz ve backend'i boşuna yorar.
class SuggestPlaces implements UseCase<List<Place>, String> {
  const SuggestPlaces(this._repository);

  static const int minQueryLength = 2;

  final PlacesRepository _repository;

  @override
  Future<Result<List<Place>>> call(String input) async {
    final query = input.trim();
    if (query.length < minQueryLength) return const Ok([]);
    return _repository.suggest(query);
  }
}
