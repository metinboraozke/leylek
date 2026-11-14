import 'package:flutter/material.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/leylek_colors.dart';
import '../../domain/entities/route_option.dart';
import '../labels.dart';
import 'journey_cards.dart';

/// Slaytın başındaki "Yolculuk planı": rotanın her adımı numaralı tek
/// satırda. Her adımda ne ile gidildiği (uçak, banliyö, otobüs...) ve
/// şehir düzeyinde nereden nereye gidildiği açıkça yazar; istasyon adları
/// ve saatler altta küçük. Ayrıntılı biniş kartları bunun altında.
class ItineraryCard extends StatelessWidget {
  const ItineraryCard({
    required this.option,
    required this.from,
    required this.to,
    super.key,
  });

  final RouteOption option;

  /// Aranan şehirler, ör. "İstanbul", "Salzburg".
  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final steps = itinerarySteps(option, from, to);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: LeylekColors.feather,
        borderRadius: BorderRadius.circular(20),
        boxShadow: LeylekColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.t('Yolculuk planı', 'Journey plan'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: LeylekColors.wingtip,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            steps
                .where((s) => s.travels)
                .map((s) => s.kind ?? s.mode)
                .join(' → '),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: LeylekColors.skyDeep,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            _StepRow(
              number: i + 1,
              step: steps[i],
              last: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

/// Planın bir adımı.
class ItineraryStep {
  const ItineraryStep({
    required this.icon,
    required this.mode,
    required this.title,
    this.detail,
    this.kind,
    this.travels = true,
  });

  final IconData icon;

  /// Ne ile: "Uçak", "Banliyö · S8", "Konaklama".
  final String mode;

  /// Üstteki özet için hat adı olmadan araç türü; yoksa [mode].
  final String? kind;

  /// Nereden nereye, şehir düzeyinde: "İstanbul → Münih".
  final String title;

  /// İstasyonlar, saatler, işletmeci.
  final String? detail;

  /// Araçla yer değiştiren adım mı. Konaklama ve yürüyüş değil: soluk
  /// işaretle çizilir, üstteki özete girmez.
  final bool travels;
}

/// Rotayı adımlara çevirir. Kara bacaklarında yalnızca istasyon adı
/// geldiği için ilk bacağın başı aktarma havalimanı, son bacağın sonu
/// varış şehri olarak yazılır; aradakiler istasyon adıyla kalır.
///
/// Yürüyüşler de ayrı adımdır: ilk durak havalimanından uzaksa oraya
/// gidiş, bacaklar arasındaki istasyon değişimleri.
List<ItineraryStep> itinerarySteps(RouteOption o, String from, String to) {
  final f = o.flight;
  final flightTo = o.via?.name ?? to;
  final steps = <ItineraryStep>[
    ItineraryStep(
      icon: Icons.flight_rounded,
      mode: f.transfers == 0
          ? S.t('Uçak', 'Flight')
          : S.t(
              'Uçak · ${f.transfers} aktarma',
              'Flight · ${f.transfers} stop',
            ),
      kind: S.t('Uçak', 'Flight'),
      title: '$from → $flightTo',
      detail: [
        '${f.fromIata ?? ''} ${Formatters.clock(f.departAt.wallClock)} → '
                '${f.toIata ?? f.airportIata ?? ''} '
                '${Formatters.clock(f.arriveAt.wallClock)}'
            .trim(),
        '${f.airline} ${f.flightNumber ?? ''}'.trim(),
      ].join(' · '),
    ),
  ];

  final via = o.via;
  final ground = o.ground;
  if (via == null || ground == null) {
    steps.add(
      ItineraryStep(
        icon: Icons.directions_transit_rounded,
        mode: S.t('Havalimanından şehre', 'Airport to city'),
        title: S.t('$to havalimanı → $to merkez', '$to airport → $to centre'),
        detail: S.t(
          'Yaklaşık 45 dk; ulaşımı kendin seçersin',
          'About 45 min; you choose how',
        ),
      ),
    );
    return steps;
  }

  // Saatin yanına gün de yazılır, gün uçuşun indiği günden farklıysa:
  // ara tatilde tren iki gün sonra kalkar.
  final landed = f.arriveAt.wallClock;
  String at(DateTime t) => DateUtils.isSameDay(t, landed)
      ? Formatters.clock(t)
      : '${Formatters.dayMonth(t)} ${Formatters.clock(t)}';

  final stay = o.stopover;
  if (stay != null) {
    // Konaklamada kara yolu havalimanından değil, şehirden başlar.
    steps.add(
      ItineraryStep(
        icon: Icons.directions_transit_rounded,
        mode: S.t('Havalimanından şehre', 'Airport to city'),
        title: S.t(
          '${via.name} havalimanı → ${stay.city} merkez',
          '${via.name} airport → ${stay.city} centre',
        ),
        detail: S.t('Ulaşımı kendin seçersin', 'You choose how'),
        travels: false,
      ),
    );
    steps.add(
      ItineraryStep(
        icon: Icons.hotel_rounded,
        mode: S.t('Konaklama', 'Stay'),
        title: Formatters.stay(stay.city, stay.days),
        detail:
            '${Formatters.shortDay(landed)} → '
            '${Formatters.shortDay(ground.departAt.wallClock)}',
        travels: false,
      ),
    );
  }

  final airport = S.t('${via.name} havalimanı', '${via.name} airport');
  if (ground.legs.isEmpty) {
    steps.add(
      ItineraryStep(
        icon: Icons.alt_route_rounded,
        mode: S.t('Tren / otobüs (tahmini)', 'Train / bus (estimate)'),
        title: '$airport → $to',
        detail:
            '~${Formatters.duration(ground.durationMin)} · '
            '${S.t('${at(ground.departAt.wallClock)} civarı', 'around ${at(ground.departAt.wallClock)}')} · '
            '${S.t('sefer doğrulanamadı', 'departure not verified')}',
      ),
    );
    return steps;
  }

  final access = ground.access;
  if (access != null) {
    final km = access.distanceKm.toStringAsFixed(1).replaceAll('.', ',');
    steps.add(
      ItineraryStep(
        icon: Icons.directions_walk_rounded,
        mode: S.t('Havalimanından istasyona', 'Airport to station'),
        title: '$airport → ${access.stop}',
        detail:
            '~$km km · ${S.t('yürüyerek', 'walk')} ~${Formatters.duration(access.walkMin)} '
            '${S.t('ya da taksi', 'or taxi')}',
        travels: false,
      ),
    );
  }

  for (var i = 0; i < ground.legs.length; i++) {
    final leg = ground.legs[i];
    final first = i == 0;
    final last = i == ground.legs.length - 1;
    final walk = leg.walkBeforeMin;
    if (walk != null) {
      final prev = first ? (access?.stop ?? airport) : ground.legs[i - 1].to;
      steps.add(
        ItineraryStep(
          icon: Icons.directions_walk_rounded,
          mode: S.t('Yürüyüş', 'Walk'),
          title: prev == leg.from
              ? S.t('${leg.from} içinde', 'within ${leg.from}')
              : '$prev → ${leg.from}',
          detail: '~${Formatters.duration(walk)}',
          travels: false,
        ),
      );
    }
    final mode = Labels.mode(leg.mode);
    final times = leg.departAt != null && leg.arriveAt != null
        ? '${at(leg.departAt!.wallClock)} → '
              '${Formatters.clock(leg.arriveAt!.wallClock)}'
        : null;
    // Şehir adıyla yazılan uçta asıl istasyon ayrıntıda görünsün.
    final stations = first || last ? '${leg.from} → ${leg.to}' : null;
    steps.add(
      ItineraryStep(
        icon: modeIcon(leg.mode),
        mode: leg.line == null ? mode : '$mode · ${leg.line}',
        kind: mode,
        title:
            '${first && stay == null && access == null && walk == null ? airport : leg.from} → '
            '${last ? to : leg.to}',
        detail: [?stations, ?times, ?leg.operator].join(' · '),
      ),
    );
  }
  return steps;
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.step,
    required this.last,
  });

  final int number;
  final ItineraryStep step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Numara ve adımları birleştiren dikey çizgi.
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: step.travels
                        ? LeylekColors.skyDeep
                        : LeylekColors.skySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    step.icon,
                    size: 15,
                    color: step.travels
                        ? LeylekColors.feather
                        : LeylekColors.skyDeep,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: LeylekColors.skySoft,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$number. ${step.mode}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: LeylekColors.skyDeep,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: LeylekColors.wingtip,
                    ),
                  ),
                  if (step.detail != null && step.detail!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      step.detail!,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: LeylekColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
