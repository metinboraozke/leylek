import 'package:flutter/widgets.dart';

/// Arama akışındaki animasyon süreleri.
///
/// Tek yerde toplandı ve ağaçtan okunuyor: testler kısa süreler verir,
/// "hareketi azalt" ayarı açık olan kullanıcı da kısa sürümü görür.
class SearchMotion extends InheritedWidget {
  const SearchMotion({required this.timing, required super.child, super.key});

  final SearchTiming timing;

  static SearchTiming of(BuildContext context) {
    final explicit = context
        .dependOnInheritedWidgetOfExactType<SearchMotion>()
        ?.timing;
    if (explicit != null) return explicit;
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false
        ? SearchTiming.reduced
        : SearchTiming.standard;
  }

  @override
  bool updateShouldNotify(SearchMotion oldWidget) => timing != oldWidget.timing;
}

class SearchTiming {
  const SearchTiming({
    required this.fadeOut,
    required this.flight,
    required this.reveal,
  });

  /// Form ve duran leyleğin kaybolması.
  final Duration fadeOut;

  /// Leyleğin uçtuğu, araçların geçtiği sahne. Veri bu sürede gelmezse
  /// sahne gelene kadar tekrar eder.
  final Duration flight;

  /// Sonuç slaytlarının ve başını uzatan leyleğin girişi.
  final Duration reveal;

  /// Toplam ~8,6 sn: 0,6 sn kaybolma + 8 sn uçuş.
  static const standard = SearchTiming(
    fadeOut: Duration(milliseconds: 600),
    flight: Duration(seconds: 8),
    reveal: Duration(milliseconds: 700),
  );

  static const reduced = SearchTiming(
    fadeOut: Duration(milliseconds: 150),
    flight: Duration(milliseconds: 1200),
    reveal: Duration(milliseconds: 150),
  );
}
