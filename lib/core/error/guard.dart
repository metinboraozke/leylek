import '../network/json_api.dart';
import '../result/result.dart';
import 'failure.dart';

/// Veri katmanındaki bir çağrıyı çalıştırır, istisnaları [Failure]'a çevirir.
///
/// Her depo aynı çeviriyi tekrar yazmasın diye tek yerde. Domain'e hiçbir
/// istisna sızmaz.
Future<Result<T>> guard<T>(Future<T> Function() body) async {
  try {
    return Ok(await body());
  } on ApiException catch (error) {
    return Err(
      ServerFailure(
        error.message,
        code: error.code,
        statusCode: error.statusCode,
      ),
    );
  } on NetworkException {
    return const Err(NetworkFailure());
  } on FormatException {
    return const Err(UnexpectedFailure());
  }
}
