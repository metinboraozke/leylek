import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/leylek_theme.dart';
import '../features/places/domain/usecases/suggest_places.dart';
import '../features/route_search/data/repositories/recent_searches_repository_impl.dart';
import '../features/route_search/domain/repositories/recent_searches_repository.dart';
import '../features/route_search/presentation/cubit/recent_searches_cubit.dart';
import '../features/route_search/presentation/cubit/search_cubit.dart';
import '../features/route_search/presentation/cubit/search_form_cubit.dart';
import '../features/route_search/presentation/motion.dart';
import '../features/route_search/presentation/pages/search_page.dart';
import 'dependencies.dart';

class LeylekApp extends StatelessWidget {
  const LeylekApp({
    required this.dependencies,
    this.today,
    this.timing,
    this.recentSearches,
    super.key,
  });

  final AppDependencies dependencies;

  /// Formun ilk tarihi için "bugün". Testte sabitlenir.
  final DateTime? today;

  /// Animasyon süreleri; verilmezse standart (ya da "hareketi azalt").
  final SearchTiming? timing;

  /// Son aramaların deposu; verilmezse yalnızca bellekte tutulur.
  final RecentSearchesRepository? recentSearches;

  @override
  Widget build(BuildContext context) {
    final now = today ?? DateTime.now();
    return RepositoryProvider<SuggestPlaces>.value(
      value: dependencies.suggestPlaces,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            // Varsayılan tarih bir hafta sonrası: bugüne uçuş fiyatı
            // verisi çoğu zaman yok, bir hafta sonrası daha anlamlı.
            create: (_) => SearchFormCubit(
              initialDate: DateTime(now.year, now.month, now.day + 7),
            ),
          ),
          BlocProvider(create: (_) => SearchCubit(dependencies.searchRoutes)),
          BlocProvider(
            create: (_) => RecentSearchesCubit(
              recentSearches ?? InMemoryRecentSearchesRepository(),
            ),
          ),
        ],
        child: MaterialApp(
          title: 'Leylek',
          debugShowCheckedModeBanner: false,
          theme: LeylekTheme.light(),
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: timing == null
              ? const SearchPage()
              : SearchMotion(timing: timing!, child: const SearchPage()),
        ),
      ),
    );
  }
}
