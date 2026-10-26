import 'package:equatable/equatable.dart';

/// Kullanıcıya gösterilebilecek hata.
///
/// Domain ve sunum katmanları istisna (exception) görmez; veri katmanı
/// her hatayı bu türlerden birine çevirir. Böylece ekran, hatanın ağdan
/// mı sunucudan mı geldiğine göre farklı davranabilir ama Dio'yu tanımaz.
sealed class Failure extends Equatable {
  const Failure(this.message);

  /// Türkçe, kullanıcıya olduğu gibi gösterilebilir metin.
  final String message;

  @override
  List<Object?> get props => [message];
}

/// Bağlantı yok ya da istek zaman aşımına uğradı. Yeniden denemek mantıklı.
final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message =
        'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.',
  ]);
}

/// Sunucu isteği anladı ama yanıt veremedi (4xx/5xx).
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.code, this.statusCode});

  /// Backend'in makine tarafından okunur kodu, ör. `OUT_OF_COVERAGE`.
  final String? code;
  final int? statusCode;

  @override
  List<Object?> get props => [message, code, statusCode];
}

/// Kullanıcının girdisi geçersiz; istek hiç gönderilmedi.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {required this.field});

  final ValidationField field;

  @override
  List<Object?> get props => [message, field];
}

enum ValidationField { from, to, date, radius, maxGroundHours, stopover }

/// Beklenmeyen durum: bozuk yanıt biçimi gibi. Kullanıcıya genel mesaj.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([
    super.message = 'Beklenmeyen bir sorun oldu. Biraz sonra tekrar dene.',
  ]);
}
