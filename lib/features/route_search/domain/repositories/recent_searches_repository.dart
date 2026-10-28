import '../entities/recent_search.dart';

/// Son aramaların saklandığı yer. Yalnızca cihazda tutulur; sunucuya
/// gönderilmez.
abstract interface class RecentSearchesRepository {
  /// En yeniden eskiye.
  Future<List<RecentSearch>> load();

  Future<void> save(List<RecentSearch> searches);
}
