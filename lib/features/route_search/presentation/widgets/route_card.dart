import 'package:flutter/material.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/leylek_colors.dart';
import '../../domain/entities/route_option.dart';
import '../labels.dart';

/// Sonuç listesindeki tek kart.
///
/// Görsel tasarım daha sonra ayrıca konuşulacak; bu sürüm bilginin
/// doğru ve eksiksiz göründüğü sade bir yerleşim.
class RouteCard extends StatelessWidget {
  const RouteCard({required this.option, super.key});

  final RouteOption option;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final o = option;
    final end = o.ground?.arriveAt ?? o.flight.arriveAt;

    return Card(
      shape: o.isRecommended
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: LeylekColors.beak, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (o.badges.isNotEmpty) ...[
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final badge in _ordered(o.badges)) _BadgeChip(badge),
              ]),
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    Formatters.money(o.total.price.amount, o.total.price.currency),
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  Formatters.duration(o.total.doorToDoorMin),
                  style: theme.textTheme.bodyMedium?.copyWith(color: LeylekColors.muted),
                ),
              ],
            ),
            if (_savingsText(o) case final text?) ...[
              const SizedBox(height: 2),
              Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: o.total.savings!.isNegative ? LeylekColors.beakText : LeylekColors.meadowText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(_title(o), style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${Formatters.clock(o.flight.departAt.wallClock)} kalkış · '
              '${Formatters.clock(end.wallClock)} varış',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            _Segment(
              icon: Icons.flight,
              text: '${o.flight.airline}${o.flight.flightNumber ?? ''} · '
                  '${Formatters.clock(o.flight.departAt.wallClock)}–'
                  '${Formatters.clock(o.flight.arriveAt.wallClock)} · '
                  '${Formatters.money(o.flight.price.amount, o.flight.price.currency)}'
                  '${o.flight.transfers > 0 ? ' · ${o.flight.transfers} aktarma' : ''}',
            ),
            if (o.ground case final ground?) ...[
              _Segment(
                icon: Icons.hourglass_bottom,
                text: '${Formatters.duration(ground.waitMin)} bekleme',
              ),
              for (final leg in ground.legs)
                _Segment(
                  icon: _modeIcon(leg.mode),
                  text: '${leg.line ?? Labels.mode(leg.mode)} · ${leg.from} → ${leg.to}',
                ),
              _Segment(
                icon: Icons.confirmation_number_outlined,
                text: 'Kara yolu ${Formatters.money(ground.fare.amount, ground.fare.currency)}'
                    '${ground.fareSource == FareSource.transitous ? '' : ' (tahmini)'}',
              ),
            ],
            if (o.isRecommended && o.reason != null) ...[
              const SizedBox(height: 8),
              Text(Labels.reason(o.reason!), style: theme.textTheme.bodySmall),
            ],
            if (_flagTexts(o).isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final text in _flagTexts(o)) _FlagChip(text),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  static String _title(RouteOption o) => switch (o.kind) {
        RouteKind.direct => 'Doğrudan uçuş · ${o.flight.airportIata ?? ''}',
        RouteKind.via => '${o.via!.name} (${o.via!.iata}) üzerinden',
      };

  static String? _savingsText(RouteOption o) {
    final savings = o.total.savings;
    if (savings == null || savings.amount == 0) return null;
    final amount = Formatters.money(savings.abs().amount, savings.currency);
    return savings.isNegative ? 'Doğrudan uçuştan $amount pahalı' : '$amount tasarruf';
  }

  static List<String> _flagTexts(RouteOption o) =>
      o.flags.map(Labels.flag).whereType<String>().toList(growable: false);

  static List<RouteBadge> _ordered(Set<RouteBadge> badges) =>
      RouteBadge.values.reversed.where(badges.contains).toList(growable: false);

  static IconData _modeIcon(TransitMode mode) => switch (mode) {
        TransitMode.walk => Icons.directions_walk,
        TransitMode.bus || TransitMode.coach => Icons.directions_bus,
        TransitMode.tram => Icons.tram,
        TransitMode.subway => Icons.subway,
        TransitMode.ferry => Icons.directions_boat,
        _ => Icons.train,
      };
}

class _Segment extends StatelessWidget {
  const _Segment({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: LeylekColors.muted),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      );
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip(this.badge);

  final RouteBadge badge;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (badge) {
      RouteBadge.recommended => (LeylekColors.beak, LeylekColors.feather),
      RouteBadge.cheapest => (LeylekColors.meadow.withValues(alpha: 0.18), LeylekColors.meadowText),
      RouteBadge.fastest => (LeylekColors.skySoft, LeylekColors.wingtip),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        Labels.badge(badge),
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FlagChip extends StatelessWidget {
  const _FlagChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: LeylekColors.warningSoft,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: const TextStyle(color: LeylekColors.warning, fontSize: 12)),
      );
}
