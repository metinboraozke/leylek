import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/leylek_colors.dart';
import '../cubit/recent_searches_cubit.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_form_cubit.dart';
import '../motion.dart';
import '../widgets/flight_scene.dart';
import '../widgets/peek_stork.dart';
import '../widgets/recent_searches.dart';
import '../widgets/results_carousel.dart';
import '../widgets/search_card.dart';

enum _Stage { form, flying, results }

/// Uygulamanın tek ekranı. Üç sahne aynı yerde birbirine geçer:
///
///   form     → yüzen arama kartı ve altında son aramalar (kaydırılır);
///              sol alt köşeden başını uzatan leylek
///   flying   → kartlar kaybolur; leylek uçar, altından dünyanın üstünde
///              uçak geçer (~4 sn). Bu sırada veri toplanır.
///   results  → tam ekran slaytlar; sol üstte geri düğmesi, sağ altta
///              başını uzatan leylek (ikisi de forma döner)
///
/// Sonuçlara geçmek için iki şart birlikte aranır: sahnenin bir turu
/// bitmiş olmalı ve veri gelmiş olmalı. Veri geç gelirse sahne tekrar
/// eder; hata gelirse forma dönülür ve hata kartta gösterilir.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  _Stage _stage = _Stage.form;
  bool _sceneCycled = false;

  void _onSearchState(BuildContext context, SearchState state) {
    switch (state) {
      case SearchInProgress():
        // Geçerli bir arama başladı: formdaki hâli son aramalara yazılır.
        context.read<RecentSearchesCubit>().add(
          context.read<SearchFormCubit>().state.toRecent(),
        );
        setState(() {
          _stage = _Stage.flying;
          _sceneCycled = false;
        });
      case SearchSuccess():
        if (_stage == _Stage.flying && _sceneCycled) {
          setState(() => _stage = _Stage.results);
        }
      case SearchError():
      case SearchIdle():
        if (_stage != _Stage.form) setState(() => _stage = _Stage.form);
    }
  }

  void _onSceneCycle() {
    _sceneCycled = true;
    if (context.read<SearchCubit>().state is SearchSuccess &&
        _stage == _Stage.flying) {
      setState(() => _stage = _Stage.results);
    }
  }

  void _newSearch() => context.read<SearchCubit>().reset();

  @override
  Widget build(BuildContext context) {
    final timing = SearchMotion.of(context);
    final search = context.watch<SearchCubit>().state;

    final Widget scene = switch (_stage) {
      _Stage.form => const _FormScene(key: ValueKey('form')),
      _Stage.flying => FlightScene(
        key: const ValueKey('flying'),
        duration: timing.flight,
        onCycle: _onSceneCycle,
      ),
      _Stage.results =>
        search is SearchSuccess
            ? ResultsCarousel(
                key: const ValueKey('results'),
                result: search.result,
                date: search.query.date,
                onNewSearch: _newSearch,
                peekDelay: timing.reveal,
              )
            : const _FormScene(key: ValueKey('form')),
    };

    return BlocListener<SearchCubit, SearchState>(
      listener: _onSearchState,
      child: PopScope(
        // Sonuç ekranında geri tuşu uygulamayı kapatmasın, forma dönsün.
        canPop: _stage == _Stage.form,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _newSearch();
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: _stage == _Stage.results
              ? LeylekColors.mist
              : LeylekColors.skySoft,
          body: AnimatedSwitcher(
            duration: timing.fadeOut,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: scene,
          ),
        ),
      ),
    );
  }
}

class _FormScene extends StatelessWidget {
  const _FormScene({super.key});

  /// Sol alttaki leyleğin boyu; son kart onun üstüne kaydırılabilsin diye
  /// listenin altında bu kadar boşluk bırakılır.
  static const double _storkSize = 150;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [LeylekColors.skySoft, LeylekColors.skyLight],
          ),
        ),
        // Leylek zeminde, köşede; kartlar onun üstünde yüzer ve kayar.
        // Klavye açılınca kartlar kayar, zemin yerinde kalır.
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned(
              left: 0,
              bottom: 0,
              child: PeekStork(
                key: Key('landing-stork'),
                delay: Duration(milliseconds: 200),
                size: _storkSize,
                fromLeft: true,
                backdrop: LeylekColors.sky,
              ),
            ),
            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                // İçerik kısa olsa da sürüklenebilsin (PAX'teki gibi).
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                // Scaffold klavyede küçülmüyor (zemin oynamasın diye);
                // kartın altı klavyenin üstüne kaydırılabilsin.
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  _storkSize * 0.7 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [SearchCard(), RecentSearches()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
