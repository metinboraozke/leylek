import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/leylek_colors.dart';
import '../../../../core/ui/leylek_mark.dart';
import '../cubit/search_cubit.dart';
import '../motion.dart';
import '../widgets/flight_scene.dart';
import '../widgets/idle_stork.dart';
import '../widgets/results_carousel.dart';
import '../widgets/search_card.dart';

enum _Stage { form, flying, results }

/// Uygulamanın tek ekranı. Üç sahne aynı yerde birbirine geçer:
///
///   form     → üstte arama kartı, altta tepede bekleyen leylek
///   flying   → kart ve leylek kaybolur; leylek uçar, altta uçak, otobüs,
///              tren, feribot geçer (~8 sn). Bu sırada veri toplanır.
///   results  → sol üstten başını uzatan leylek ve tam ekran slaytlar
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
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 12, 20, 14),
                        child: _Header(),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SearchCard(),
                      ),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight:
                                IdleStork.heightFor(context) +
                                48 +
                                MediaQuery.paddingOf(context).bottom,
                          ),
                          child: const IdleStork(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      LeylekMark(size: 40),
      SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Leylek',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: LeylekColors.wingtip,
              ),
            ),
            Text(
              'Uç, sonra yürü: aktarmalı ucuz rotalar',
              style: TextStyle(fontSize: 14, color: LeylekColors.muted),
            ),
          ],
        ),
      ),
    ],
  );
}
