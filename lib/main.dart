import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/dependencies.dart';
import 'app/leylek_app.dart';
import 'core/config/app_config.dart';
import 'features/route_search/data/repositories/recent_searches_repository_impl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // "20 Kasım Cuma" gibi Türkçe gün ve ay adları için.
  await initializeDateFormatting('tr');
  final dependencies = AppDependencies.create(AppConfig.fromEnvironment());
  runApp(
    LeylekApp(
      dependencies: dependencies,
      recentSearches: PrefsRecentSearchesRepository(),
    ),
  );
}
