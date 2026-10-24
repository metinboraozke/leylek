import '../result/result.dart';

/// Tek bir iş kuralını çalıştıran sınıfların ortak arayüzü.
///
/// Her kullanım durumu tek bir iş yapar (SRP) ve sunum katmanı yalnızca
/// bu arayüzü bilir; arkasındaki depo değişse de ekran değişmez.
abstract interface class UseCase<Out, In> {
  Future<Result<Out>> call(In input);
}
