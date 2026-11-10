import '../../../../core/error/guard.dart';
import '../../../../core/result/result.dart';
import '../../domain/repositories/fare_calendar_repository.dart';
import '../datasources/fare_calendar_data_source.dart';

class FareCalendarRepositoryImpl implements FareCalendarRepository {
  const FareCalendarRepositoryImpl(this._source);

  final FareCalendarDataSource _source;

  @override
  Future<Result<Map<String, int>>> month(
    String from,
    String to,
    String month,
  ) => guard(() => _source.month(from, to, month));
}
