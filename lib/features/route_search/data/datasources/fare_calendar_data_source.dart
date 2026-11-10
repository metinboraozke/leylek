import '../../../../core/json/json_reader.dart';
import '../../../../core/network/json_api.dart';

/// `/v1/calendar` yanıtının ham kaynağı.
abstract interface class FareCalendarDataSource {
  Future<Map<String, int>> month(String from, String to, String month);
}

class ApiFareCalendarDataSource implements FareCalendarDataSource {
  const ApiFareCalendarDataSource(this._api);

  final JsonApi _api;

  @override
  Future<Map<String, int>> month(String from, String to, String month) async {
    final json = await _api.getJson(
      '/v1/calendar',
      query: {'from': from, 'to': to, 'month': month, 'currency': 'TRY'},
    );
    return {
      for (final day in json.objList('days'))
        day.str('date'): day.integer('price'),
    };
  }
}

/// Backend yokken: gün numarasından türeyen örnek fiyatlar; her altıncı
/// gün boş (o güne uçuş verisi yok).
class SampleFareCalendarDataSource implements FareCalendarDataSource {
  const SampleFareCalendarDataSource();

  @override
  Future<Map<String, int>> month(String from, String to, String month) async {
    final parts = month.split('-').map(int.parse).toList();
    final days = DateTime(parts[0], parts[1] + 1, 0).day;
    return {
      for (var d = 1; d <= days; d++)
        if (d % 6 != 0)
          '$month-${d.toString().padLeft(2, '0')}': 4800 + (d * 373) % 2600,
    };
  }
}
