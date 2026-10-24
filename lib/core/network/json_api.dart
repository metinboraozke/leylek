import 'package:dio/dio.dart';

import '../json/json_reader.dart';

/// Backend'e GET isteği atıp JSON nesnesi döndüren en küçük arayüz.
///
/// Veri kaynakları Dio'ya değil buna bağlıdır (DIP). Testte sahte bir
/// uygulama verilir, ileride HTTP kütüphanesi değişirse yalnızca
/// [DioJsonApi] değişir.
abstract interface class JsonApi {
  Future<Json> getJson(String path, {Map<String, Object?> query});
}

/// Sunucu bir hata yanıtı döndürdü.
class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// Sunucuya ulaşılamadı ya da istek zaman aşımına uğradı.
class NetworkException implements Exception {
  const NetworkException(this.cause);

  final Object cause;

  @override
  String toString() => 'NetworkException: $cause';
}

class DioJsonApi implements JsonApi {
  DioJsonApi({required String baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                // Backend'in kendi üst süresi 25 sn; biraz pay bırakıyoruz.
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 30),
                responseType: ResponseType.json,
                headers: {'Accept': 'application/json'},
              ),
            );

  final Dio _dio;

  @override
  Future<Json> getJson(String path, {Map<String, Object?> query = const {}}) async {
    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: {
          for (final entry in query.entries)
            if (entry.value != null) entry.key: entry.value,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      throw const FormatException('Yanıt bir JSON nesnesi değil');
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  Exception _translate(DioException error) {
    final response = error.response;
    if (response == null) return NetworkException(error);

    // Backend hataları `{ error: { code, message } }` biçiminde ve Türkçe.
    final body = response.data;
    if (body is Map<String, dynamic> && body['error'] is Map<String, dynamic>) {
      final err = body.obj('error');
      return ApiException(
        err.strOrNull('message') ?? 'Sunucu isteği tamamlayamadı.',
        code: err.strOrNull('code'),
        statusCode: response.statusCode,
      );
    }
    return ApiException(
      'Sunucu isteği tamamlayamadı.',
      statusCode: response.statusCode,
    );
  }
}
