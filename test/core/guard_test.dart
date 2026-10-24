import 'package:flutter_test/flutter_test.dart';
import 'package:leylek/core/error/failure.dart';
import 'package:leylek/core/error/guard.dart';
import 'package:leylek/core/network/json_api.dart';
import 'package:leylek/core/result/result.dart';

Failure _failureOf(Result<Object?> r) => (r as Err<Object?>).failure;

void main() {
  test('başarılı çağrı Ok döner', () async {
    final r = await guard(() async => 42);
    expect((r as Ok<int>).value, 42);
  });

  test('sunucu hatası mesajı ve koduyla ServerFailure olur', () async {
    final r = await guard<int>(() async =>
        throw const ApiException('Kapsam dışı', code: 'OUT_OF_COVERAGE', statusCode: 422));
    expect(
      _failureOf(r),
      const ServerFailure('Kapsam dışı', code: 'OUT_OF_COVERAGE', statusCode: 422),
    );
  });

  test('ağ hatası NetworkFailure olur', () async {
    final r = await guard<int>(() async => throw const NetworkException('timeout'));
    expect(_failureOf(r), isA<NetworkFailure>());
  });

  test('bozuk biçim UnexpectedFailure olur', () async {
    final r = await guard<int>(() async => throw const FormatException('x'));
    expect(_failureOf(r), isA<UnexpectedFailure>());
  });
}
