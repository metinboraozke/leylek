import '../error/failure.dart';

/// Başarı ya da [Failure] taşıyan sonuç.
///
/// Kullanım durumları istisna fırlatmaz, bunu döndürür. `sealed` olduğu
/// için `switch` iki dalı da ele almayı zorunlu kılar; unutulan hata
/// durumu derleme hatası olur.
sealed class Result<T> {
  const Result();

  R fold<R>(R Function(Failure failure) onErr, R Function(T value) onOk) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;
}
