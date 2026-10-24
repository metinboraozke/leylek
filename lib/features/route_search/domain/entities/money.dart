import 'package:equatable/equatable.dart';

/// Tutar ve para birimi. Para birimi olmayan çıplak sayı dolaşmasın diye.
class Money extends Equatable {
  const Money(this.amount, this.currency);

  final double amount;

  /// ISO 4217, ör. `TRY`.
  final String currency;

  bool get isNegative => amount < 0;

  Money abs() => Money(amount.abs(), currency);

  @override
  List<Object?> get props => [amount, currency];
}
