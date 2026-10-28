import 'package:flutter/material.dart';

import '../../../../core/theme/leylek_colors.dart';
import '../../domain/entities/search_result.dart';
import 'peek_stork.dart';
import 'route_slide.dart';

/// Sonuç ekranı: tam ekran slaytlar, sağa kaydırdıkça sonraki rota.
///
/// Sol üstteki geri düğmesi ve sağ alttan başını uzatan leylek forma
/// döner; sağ üstte kaçıncı rotada olunduğu yazar. Slaytlar en ucuzdan en
/// pahalıya sıralı.
class ResultsCarousel extends StatefulWidget {
  const ResultsCarousel({
    required this.result,
    required this.date,
    required this.onNewSearch,
    required this.peekDelay,
    super.key,
  });

  final SearchResult result;
  final DateTime date;
  final VoidCallback onNewSearch;
  final Duration peekDelay;

  @override
  State<ResultsCarousel> createState() => _ResultsCarouselState();
}

class _ResultsCarouselState extends State<ResultsCarousel> {
  final PageController _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.result.options;
    if (options.isEmpty) {
      return _Empty(onNewSearch: widget.onNewSearch);
    }
    return Stack(
      children: [
        PageView.builder(
          key: const Key('results-pages'),
          controller: _pages,
          itemCount: options.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) => RouteSlide(
            option: options[i],
            result: widget.result,
            date: widget.date,
          ),
        ),
        Positioned(
          left: 12,
          top: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _BackButton(onTap: widget.onNewSearch),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: PeekStork(
              onTap: widget.onNewSearch,
              delay: widget.peekDelay,
            ),
          ),
        ),
        Positioned(
          right: 16,
          top: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _PageIndicator(count: options.length, index: _index),
            ),
          ),
        ),
        if (widget.result.warnings.contains(SearchWarning.fewerThanThree))
          const Positioned(
            left: 16,
            right: 96,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: _Hint('Bu varış için üçten az seçenek bulundu.'),
            ),
          ),
      ],
    );
  }
}

/// Sol üstte, her zaman görünen geri düğmesi. iPhone'da sistem geri tuşu
/// yok; sonuçtan çıkmanın açık bir yolu olmalı.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: LeylekColors.feather,
    shape: const CircleBorder(),
    elevation: 0,
    shadowColor: Colors.transparent,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: LeylekColors.cardShadow,
      ),
      child: IconButton(
        key: const Key('back-to-search'),
        tooltip: 'Aramaya dön',
        onPressed: onTap,
        icon: const Icon(Icons.arrow_back_rounded, color: LeylekColors.wingtip),
      ),
    ),
  );
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: LeylekColors.feather,
      borderRadius: BorderRadius.circular(999),
      boxShadow: LeylekColors.cardShadow,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${index + 1} / $count',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: LeylekColors.wingtip,
          ),
        ),
        const SizedBox(width: 8),
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: i == index ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? LeylekColors.skyDeep : LeylekColors.line,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: LeylekColors.warningSoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: const TextStyle(color: LeylekColors.warning)),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onNewSearch});

  final VoidCallback onNewSearch;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Bu tarih için rota bulunamadı',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Tarihi ya da yarıçapı değiştirip yeniden dene.',
            style: TextStyle(color: LeylekColors.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onNewSearch, child: const Text('Yeni arama')),
        ],
      ),
    ),
  );
}
