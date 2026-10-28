import 'package:flutter/material.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/leylek_colors.dart';
import '../../domain/entities/route_option.dart';
import '../../domain/entities/search_result.dart';
import '../labels.dart';
import 'itinerary_card.dart';
import 'journey_cards.dart';

/// Tüm ekranı kaplayan tek bir rota slaytı.
///
/// Üstte etiket ve büyük "İstanbul → Salzburg"; ardından özet kartı (en
/// ucuza yeşil para, önerilene mavi tik), adım adım yolculuk planı ve
/// rotanın her parçası için PAX tarzı biniş kartları. "Rezervasyona git" ilgili kartın içinde.
class RouteSlide extends StatelessWidget {
  const RouteSlide({
    required this.option,
    required this.result,
    required this.date,
    super.key,
  });

  final RouteOption option;
  final SearchResult result;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final o = option;
    final from = result.fromName.isEmpty
        ? (o.flight.fromIata ?? '')
        : result.fromName;
    final to = result.toName.isEmpty ? (o.flight.toIata ?? '') : result.toName;
    final flags = _flagTexts(o);

    return ListView(
      key: PageStorageKey('slide-${o.rank}'),
      // Üstte geri düğmesi ve sayfa göstergesi, sağ altta leylek var;
      // içerik ikisinin altında kalmasın.
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 60,
        16,
        MediaQuery.paddingOf(context).bottom + 110,
      ),
      children: [
        Text(
          o.kind == RouteKind.direct
              ? 'DOĞRUDAN UÇUŞ'
              : [
                  'AKTARMALI · ${o.via!.name.toUpperCase()} ÜZERİNDEN',
                  if (o.stopover != null) '${o.stopover!.days} GÜN KONAKLAMA',
                ].join(' · '),
          style: const TextStyle(
            fontSize: 11.5,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
            color: LeylekColors.beakText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$from → $to',
          style: const TextStyle(
            fontSize: 28,
            height: 1.15,
            letterSpacing: -0.6,
            fontWeight: FontWeight.w800,
            color: LeylekColors.wingtip,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          Formatters.day(date),
          style: const TextStyle(fontSize: 13, color: LeylekColors.muted),
        ),
        const SizedBox(height: 16),
        _SummaryCard(option: o),
        if (flags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final t in flags) _FlagChip(t)],
          ),
        ],
        const SizedBox(height: 12),
        ItineraryCard(option: o, from: from, to: to),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
          child: Text(
            'Biletler ve ayrıntılar',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: LeylekColors.wingtip,
            ),
          ),
        ),
        ..._journey(o, from, to),
        const SizedBox(height: 16),
        Text(
          [
            if (o.kind == RouteKind.via)
              'Uçuş ve kara yolu ayrı biletlerdir; uçuş gecikirse kara yolu '
                  'bileti yanabilir.',
            if (result.isSample)
              'Örnek veri: backend bağlı değil, fiyatlar gerçek değil.',
            'Uçuş fiyatları son 48 saatte görülen fiyatlardır.',
            'Veri: ${result.attribution.map((a) => a.name).join(' · ')}',
          ].join('\n'),
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.5,
            color: LeylekColors.muted,
          ),
        ),
      ],
    );
  }

  List<Widget> _journey(RouteOption o, String from, String to) {
    final day = Formatters.shortDay(date);
    BookingLink? linkFor(BookingKind kind, [String? provider]) {
      for (final b in o.booking) {
        if (b.kind == kind && (provider == null || b.provider == provider)) {
          return b;
        }
      }
      return null;
    }

    final widgets = <Widget>[
      BoardingPass.flight(
        o.flight,
        day,
        linkFor(BookingKind.flight),
        fromCity: from,
        toCity: o.via?.name ?? to,
      ),
    ];
    final ground = o.ground;
    if (ground == null) {
      widgets.add(
        const WaitStrip(minutes: 45, note: 'havalimanından şehre (tahmini)'),
      );
      return widgets;
    }

    final stay = o.stopover;
    widgets.add(
      stay != null
          ? StayStrip(days: stay.days, city: stay.city)
          : WaitStrip(
              minutes: ground.waitMin,
              note: 'pasaport, bagaj, istasyon',
            ),
    );
    if (ground.legs.isEmpty) {
      widgets.add(BoardingPass.estimated(ground, day, o.via?.iata ?? '', to));
      return widgets;
    }

    // Kara yolunun fiyatı bacak bacak bilinmiyor; toplam son kartta.
    final fare =
        '${ground.fareSource == FareSource.transitous ? '' : '~'}'
        '${Formatters.money(ground.fare.amount, ground.fare.currency)}';
    for (var i = 0; i < ground.legs.length; i++) {
      final leg = ground.legs[i];
      if (i > 0) {
        final prev = ground.legs[i - 1];
        final gap = prev.arriveAt != null && leg.departAt != null
            ? leg.departAt!.difference(prev.arriveAt!).inMinutes
            : 0;
        widgets.add(WaitStrip(minutes: gap, note: 'aktarma'));
      }
      final last = i == ground.legs.length - 1;
      widgets.add(
        BoardingPass.leg(
          leg,
          day,
          booking: leg.operator == null
              ? null
              : linkFor(BookingKind.ground, leg.operator),
          price: last ? fare : null,
        ),
      );
    }
    return widgets;
  }

  static List<String> _flagTexts(RouteOption o) => o.flags
      .where((f) => f != RouteFlag.separateTickets)
      .map(Labels.flag)
      .whereType<String>()
      .toList(growable: false);
}

/// Özet kartı: toplam fiyat, tasarruf, süre ve sağ altta rozetler.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.option});

  final RouteOption option;

  @override
  Widget build(BuildContext context) {
    final o = option;
    final savings = o.total.savings;
    String? savingsText;
    if (savings != null && savings.amount != 0) {
      final amount = Formatters.money(savings.abs().amount, savings.currency);
      savingsText = savings.isNegative
          ? 'Doğrudan uçuştan $amount pahalı'
          : 'Doğrudan uçuşa göre $amount tasarruf';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LeylekColors.feather,
        borderRadius: BorderRadius.circular(20),
        boxShadow: LeylekColors.cardShadow,
        border: o.isRecommended
            ? Border.all(color: LeylekColors.skyDeep, width: 1.5)
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Toplam',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: LeylekColors.muted,
                  ),
                ),
                Text(
                  Formatters.money(
                    o.total.price.amount,
                    o.total.price.currency,
                  ),
                  style: const TextStyle(
                    fontSize: 32,
                    height: 1.1,
                    letterSpacing: -0.8,
                    fontWeight: FontWeight.w800,
                    color: LeylekColors.wingtip,
                  ),
                ),
                if (savingsText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    savingsText,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: savings!.isNegative
                          ? LeylekColors.beakText
                          : LeylekColors.meadowText,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  [
                    o.stopover == null
                        ? 'Kapıdan kapıya ${Formatters.duration(o.total.doorToDoorMin)}'
                        : 'Yolda ${Formatters.duration(o.total.travelMin)} · '
                              '${Formatters.locative(o.stopover!.city)} ${o.stopover!.days} gün',
                    if (o.total.extraMin > 0)
                      '+${Formatters.duration(o.total.extraMin)}',
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: LeylekColors.muted,
                  ),
                ),
                if (o.isRecommended && o.reason != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    Labels.reason(o.reason!),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: LeylekColors.skyDeep,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (o.isCheapest)
            const _BadgeIcon(
              key: Key('badge-cheapest'),
              icon: Icons.payments_rounded,
              color: LeylekColors.meadowDeep,
              label: 'En ucuz',
            ),
          if (o.isCheapest && o.isRecommended) const SizedBox(width: 8),
          if (o.isRecommended)
            const _BadgeIcon(
              key: Key('badge-recommended'),
              icon: Icons.check_rounded,
              color: LeylekColors.skyDeep,
              label: 'Önerilen',
            ),
        ],
      ),
    );
  }
}

/// Sağ alttaki yuvarlak rozet: yeşil para (en ucuz), mavi tik (önerilen).
class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({
    required this.icon,
    required this.color,
    required this.label,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Semantics(
      label: label,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: LeylekColors.feather, size: 22),
      ),
    ),
  );
}

class _FlagChip extends StatelessWidget {
  const _FlagChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: LeylekColors.warningSoft,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: LeylekColors.warning,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
