// Uygulamanın veri katmanını çalışan bir backend'e bağlayıp dener.
//
//   dart run tool/e2e_api_contract.dart http://127.0.0.1:8080 2026-11-20
//
// `backend/scripts/e2e.ts` bunu kendi başlattığı sunucuya karşı çağırır.
// Uygulamadaki bileşim kökü (AppDependencies) aynen kullanılır; böylece
// backend yanıtı değişip uygulamanın ayrıştırıcısı geride kalırsa burada
// yakalanır. Flutter gerektirmez: domain ve veri katmanı saf Dart.
import 'dart:io';

import 'package:leylek/app/dependencies.dart';
import 'package:leylek/core/config/app_config.dart';
import 'package:leylek/core/error/failure.dart';
import 'package:leylek/core/result/result.dart';
import 'package:leylek/features/route_search/domain/entities/route_option.dart';
import 'package:leylek/features/route_search/domain/entities/search_query.dart';

var _failed = 0;

Future<void> _check(String name, Future<String?> Function() body) async {
  try {
    final detail = await body();
    stdout.writeln('✓ $name${detail == null ? '' : ' — $detail'}');
  } catch (e) {
    _failed++;
    stdout.writeln('✗ $name — $e');
  }
}

void _expect(bool cond, String message) {
  if (!cond) throw StateError(message);
}

T _ok<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError(
    '${failure.runtimeType}: ${failure.message}',
  ),
};

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln(
      'Kullanım: dart run tool/e2e_api_contract.dart <adres> <YYYY-AA-GG>',
    );
    exit(2);
  }
  final deps = AppDependencies.create(AppConfig(apiBaseUrl: args[0]));
  final date = DateTime.parse(args[1]);

  await _check('Yer önerisi ayrıştırılıyor', () async {
    final places = _ok(await deps.suggestPlaces('salz'));
    _expect(places.isNotEmpty, 'öneri yok');
    _expect(places.first.name == 'Salzburg', 'ilk öneri ${places.first.name}');
    return places.first.label;
  });

  for (final stay in [0, 1]) {
    await _check('Arama yanıtı ayrıştırılıyor (konaklama $stay gün)', () async {
      final result = _ok(
        await deps.searchRoutes(
          SearchQuery(
            from: 'İstanbul',
            to: 'Salzburg',
            date: date,
            stopoverDays: stay,
          ),
        ),
      );
      final options = result.options;
      _expect(!result.isSample, 'örnek veri döndü, backend kullanılmadı');
      _expect(
        options.isNotEmpty && options.length <= 4,
        'kart sayısı ${options.length}',
      );
      _expect(
        result.fromName.isNotEmpty && result.toName.isNotEmpty,
        'yer adları boş',
      );
      _expect(options.first.isCheapest, 'ilk kart en ucuz değil');
      _expect(
        options.where((o) => o.isRecommended).length <= 1,
        'birden çok önerilen',
      );
      _expect(
        result.attribution.any((a) => a.name == 'Transitous'),
        'Transitous atfı yok',
      );
      for (final o in options) {
        _expect(
          o.total.price.currency == 'TRY',
          'para birimi ${o.total.price.currency}',
        );
        _expect(
          o.flight.duration.inMinutes > 0,
          'uçuş süresi ${o.flight.duration}',
        );
        for (final b in o.booking) {
          _expect(b.url.scheme == 'https', 'https olmayan bağlantı ${b.url}');
        }
        if (o.kind == RouteKind.via) {
          _expect(
            o.via != null && o.ground != null,
            'aktarmalı kartta via/ground yok',
          );
          if (stay > 0) {
            _expect(o.stopover?.days == stay, 'konaklama ayrıştırılmadı');
            _expect(
              o.flags.contains(RouteFlag.stopover),
              'STOPOVER etiketi yok',
            );
          }
        }
      }
      return options
          .map((o) => o.kind == RouteKind.direct ? 'doğrudan' : o.via!.iata)
          .join(', ');
    });
  }

  await _check('Sunucu hatası Türkçe ServerFailure olarak geliyor', () async {
    final r = await deps.searchRoutes(
      SearchQuery(from: 'İstanbul', to: 'Ankara', date: date),
    );
    final failure = switch (r) {
      Ok() => throw StateError('kapsam dışı arama başarılı döndü'),
      Err(:final failure) => failure,
    };
    _expect(failure is ServerFailure, 'hata türü ${failure.runtimeType}');
    _expect(
      (failure as ServerFailure).code == 'OUT_OF_COVERAGE',
      'kod ${failure.code}',
    );
    return failure.message;
  });

  await _check('Ulaşılamayan sunucu NetworkFailure veriyor', () async {
    final dead = AppDependencies.create(
      const AppConfig(apiBaseUrl: 'http://127.0.0.1:9'),
    );
    final r = await dead.suggestPlaces('salz');
    _expect(
      r is Err && (r as Err).failure is NetworkFailure,
      'hata türü yanlış: $r',
    );
    return null;
  });

  exit(_failed == 0 ? 0 : 1);
}
