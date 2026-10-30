import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/leylek_colors.dart';
import '../cubit/recent_searches_cubit.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_form_cubit.dart';
import '../motion.dart';
import '../widgets/flight_scene.dart';
import '../widgets/globe.dart';
import '../widgets/recent_searches.dart';
import '../widgets/results_carousel.dart';
import '../widgets/search_card.dart';
import '../widgets/standing_stork.dart';

enum _Stage { form, flying, results }

/// Uygulamanın tek ekranı. Üç sahne aynı yerde birbirine geçer:
///
///   form     → soluk Avrupa haritası önünde başlık, üstüne leylek konmuş
///              arama kartı ve altında tek satır son arama; tek ekrana
///              sığar, kaydırılmaz
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

  /// Kartın sağ üstüne konan leyleğin boyu; ayakları kartın içine
  /// [_storkSink] kadar iner.
  static const double _storkHeight = 118;
  static const double _storkSink = 23;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [LeylekColors.skySoft, LeylekColors.field],
          ),
        ),
        // Harita zeminde sabit; başlık ve kartlar onun üstünde durur.
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _MapBackdrop(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, viewport) => SingleChildScrollView(
                  // Açılış tek ekrana sığar, kaydırılmaz. Yalnızca klavye
                  // açıkken (Scaffold klavyede küçülmüyor) yazılan alan
                  // klavyenin üstüne kaydırılabilsin.
                  physics: keyboard > 0
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: keyboard),
                  child: SizedBox(
                    height: viewport.maxHeight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: _Headline(),
                          ),
                          // Artan boşluk başlıkla kart arasına gider; kart
                          // ekranın altında durur. Kısa ekranda kart
                          // kaydırma yerine bir miktar küçülür.
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, area) => FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.bottomCenter,
                                child: SizedBox(
                                  width: area.maxWidth,
                                  child: const _CardStack(
                                    storkHeight: _storkHeight,
                                    storkSink: _storkSink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Üstüne leylek konmuş arama kartı ve altındaki son arama.
class _CardStack extends StatelessWidget {
  const _CardStack({required this.storkHeight, required this.storkSink});

  final double storkHeight;
  final double storkSink;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Leyleğin kartın üstünde kalan kısmı kadar yer.
        SizedBox(height: storkHeight - storkSink + 6),
        Stack(
          clipBehavior: Clip.none,
          children: [
            const SearchCard(),
            Positioned(
              right: 7,
              top: storkSink - storkHeight,
              child: IgnorePointer(
                child: StandingStork(
                  key: const Key('landing-stork'),
                  height: storkHeight,
                ),
              ),
            ),
          ],
        ),
        const RecentSearches(),
      ],
    );
  }
}

/// "leylek", büyük başlık ve kısa açıklama.
class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'leylek',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            color: LeylekColors.skyDeep,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Bir uçuş yerine,\nbir yolculuk.',
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.4,
            height: 1.08,
            color: LeylekColors.ink,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Aktarma şehirlerinde ara tatillerle\nrotanı birlikte kuralım.',
          style: TextStyle(
            fontSize: 16,
            height: 1.45,
            color: LeylekColors.muted,
          ),
        ),
      ],
    );
  }
}

/// Başlığın arkasındaki soluk dünya: ekranı aşan büyük bir kürenin üst
/// kenarı, ortasında Avrupa. Kara şekilleri yüklenene kadar yalnızca
/// kürenin kendisi görünür.
class _MapBackdrop extends StatefulWidget {
  const _MapBackdrop();

  @override
  State<_MapBackdrop> createState() => _MapBackdropState();
}

class _MapBackdropState extends State<_MapBackdrop> {
  LandShapes? _shapes;

  @override
  void initState() {
    super.initState();
    LandShapes.load().then((shapes) {
      if (mounted) setState(() => _shapes = shapes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return IgnorePointer(
      child: Opacity(
        opacity: 0.55,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final radius = w * 1.4;
            return CustomPaint(
              size: constraints.biggest,
              painter: GlobePainter(
                shapes: _shapes,
                // Kürenin tepesi başlığın hemen üstünde; merkez boylamı
                // 15°D: küre ekranda tam ortada, Avrupa tepesinin altında.
                center: Offset(w / 2, top + 30 + radius),
                radius: radius,
                rotation: 0.7,
                centerLat: -4,
              ),
            );
          },
        ),
      ),
    );
  }
}
