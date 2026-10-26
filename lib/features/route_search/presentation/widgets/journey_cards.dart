import 'package:flutter/material.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/leylek_colors.dart';
import '../../domain/entities/route_option.dart';
import '../labels.dart';
import 'booking_card.dart';

/// Rotanın her parçası için biniş kartı.
///
/// PAX'teki `BoardingPassCard` ile aynı yapı: beyaz kart, yumuşak gölge;
/// üstte etiket hapı ve tarih, iki uçta büyük kodlar ve aradaki süre
/// çizgisi; çentikli kesikli ayırıcı; altta işletmeci ve fiyat; en altta
/// kartın içinde "Rezervasyona git" düğmesi.
class BoardingPass extends StatelessWidget {
  const BoardingPass({
    required this.label,
    required this.date,
    required this.from,
    required this.to,
    required this.fromTime,
    required this.toTime,
    required this.duration,
    required this.detail,
    required this.icon,
    required this.provider,
    this.providerDetail,
    this.price,
    this.booking,
    this.note,
    this.compactEndpoints = false,
    super.key,
  });

  /// Uçuş kartı.
  factory BoardingPass.flight(Flight f, String date, BookingLink? booking) {
    return BoardingPass(
      label: 'UÇUŞ',
      date: date,
      from: f.fromIata ?? '—',
      to: f.toIata ?? f.airportIata ?? '—',
      fromTime: Formatters.clock(f.departAt.wallClock),
      toTime: Formatters.clock(f.arriveAt.wallClock),
      duration: Formatters.duration(f.duration.inMinutes),
      detail: f.transfers == 0 ? 'Aktarmasız' : '${f.transfers} aktarma',
      icon: Icons.flight_rounded,
      provider: booking?.provider ?? f.airline,
      providerDetail: [
        '${f.airline} ${f.flightNumber ?? ''}'.trim(),
        if (f.priceSeenHoursAgo != null)
          'fiyat ${_age(f.priceSeenHoursAgo!)} görüldü',
      ].join(' • '),
      price: Formatters.money(f.price.amount, f.price.currency),
      booking: booking,
    );
  }

  /// Kara yolunun bir bacağı.
  factory BoardingPass.leg(
    GroundLeg l,
    String date, {
    BookingLink? booking,
    String? price,
  }) {
    final minutes = l.departAt != null && l.arriveAt != null
        ? l.arriveAt!.difference(l.departAt!).inMinutes
        : null;
    final mode = Labels.mode(l.mode);
    return BoardingPass(
      label: l.line == null
          ? mode.toUpperCase()
          : '${mode.toUpperCase()} · ${l.line}',
      date: date,
      from: l.from,
      to: l.to,
      fromTime: l.departAt == null
          ? ''
          : Formatters.clock(l.departAt!.wallClock),
      toTime: l.arriveAt == null ? '' : Formatters.clock(l.arriveAt!.wallClock),
      duration: minutes == null ? '' : Formatters.duration(minutes),
      detail: mode,
      icon: modeIcon(l.mode),
      provider: l.operator ?? mode,
      providerDetail: l.line,
      price: price,
      booking: booking,
      compactEndpoints: true,
    );
  }

  /// Kara yolu doğrulanamadığında tahmini kart.
  factory BoardingPass.estimated(
    GroundJourney g,
    String date,
    String from,
    String to,
  ) {
    return BoardingPass(
      label: 'KARA YOLU · TAHMİNİ',
      date: date,
      from: from,
      to: to,
      fromTime: '~${Formatters.clock(g.departAt.wallClock)}',
      toTime: '~${Formatters.clock(g.arriveAt.wallClock)}',
      duration: '~${Formatters.duration(g.durationMin)}',
      detail: 'Tren / otobüs',
      icon: Icons.alt_route_rounded,
      provider: 'Sefer bilgisi doğrulanamadı',
      price: '~${Formatters.money(g.fare.amount, g.fare.currency)}',
      note:
          'Süre ve fiyat mesafeden tahmin edildi; yola çıkmadan önce sefer '
          'saatlerini kontrol et.',
      compactEndpoints: true,
    );
  }

  final String label;
  final String date;
  final String from;
  final String to;
  final String fromTime;
  final String toTime;
  final String duration;

  /// Çizginin altındaki küçük metin, ör. "Aktarmasız".
  final String detail;
  final IconData icon;
  final String provider;
  final String? providerDetail;
  final String? price;
  final BookingLink? booking;

  /// Kartın altındaki uyarı (ör. tahmini kara yolu).
  final String? note;

  /// Uzun istasyon adları için daha küçük uç yazısı.
  final bool compactEndpoints;

  static String _age(int hours) =>
      hours < 24 ? '$hours saat önce' : '${hours ~/ 24} gün önce';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LeylekColors.feather,
        borderRadius: BorderRadius.circular(20),
        boxShadow: LeylekColors.cardShadow,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Uzun hat adı tarihi itmesin: hap daralır, sonu "…" olur.
                    Flexible(child: _Pill(label)),
                    const SizedBox(width: 8),
                    const Spacer(),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: LeylekColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _Endpoint(
                        code: from,
                        time: fromTime,
                        alignment: CrossAxisAlignment.start,
                        compact: compactEndpoints,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: _PathIndicator(
                        duration: duration,
                        detail: detail,
                        icon: icon,
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: _Endpoint(
                        code: to,
                        time: toTime,
                        alignment: CrossAxisAlignment.end,
                        compact: compactEndpoints,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const _PerforatedDivider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: LeylekColors.wingtip,
                        ),
                      ),
                      if (providerDetail != null && providerDetail!.isNotEmpty)
                        Text(
                          providerDetail!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: LeylekColors.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (price != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    price!,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: LeylekColors.wingtip,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                note!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: LeylekColors.warning,
                ),
              ),
            ),
          if (booking != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => openBookingLink(booking!.url),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Rezervasyona git'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

IconData modeIcon(TransitMode mode) => switch (mode) {
  TransitMode.walk => Icons.directions_walk_rounded,
  TransitMode.bus || TransitMode.coach => Icons.directions_bus_rounded,
  TransitMode.tram => Icons.tram_rounded,
  TransitMode.subway => Icons.subway_rounded,
  TransitMode.ferry => Icons.directions_boat_rounded,
  _ => Icons.train_rounded,
};

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: LeylekColors.skySoft,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: LeylekColors.skyDeep,
        letterSpacing: 0.4,
      ),
    ),
  );
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({
    required this.code,
    required this.time,
    required this.alignment,
    required this.compact,
  });

  final String code;
  final String time;
  final CrossAxisAlignment alignment;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignment,
    children: [
      Text(
        code,
        maxLines: compact ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        textAlign: alignment == CrossAxisAlignment.end
            ? TextAlign.end
            : TextAlign.start,
        style: TextStyle(
          fontSize: compact ? 16 : 26,
          fontWeight: FontWeight.w700,
          letterSpacing: compact ? -0.2 : 1,
          color: LeylekColors.wingtip,
          height: 1.15,
        ),
      ),
      if (time.isNotEmpty)
        Text(
          time,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: LeylekColors.muted,
          ),
        ),
    ],
  );
}

class _PathIndicator extends StatelessWidget {
  const _PathIndicator({
    required this.duration,
    required this.detail,
    required this.icon,
  });

  final String duration;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(
      children: [
        Text(
          duration,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: LeylekColors.muted,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(child: Container(height: 1, color: LeylekColors.line)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(icon, size: 14, color: LeylekColors.skyDeep),
            ),
            Expanded(child: Container(height: 1, color: LeylekColors.line)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: LeylekColors.muted),
        ),
      ],
    ),
  );
}

/// Biletin kesikli ayırıcısı — iki yanda sayfa renginde yarım daire çentik.
class _PerforatedDivider extends StatelessWidget {
  const _PerforatedDivider();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 20,
    child: Row(
      children: [
        const _Notch(left: true),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              const dash = 5.0;
              const gap = 4.0;
              final count = (c.maxWidth / (dash + gap)).floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  count,
                  (_) => Container(
                    width: dash,
                    height: 1.2,
                    color: LeylekColors.line,
                  ),
                ),
              );
            },
          ),
        ),
        const _Notch(left: false),
      ],
    ),
  );
}

class _Notch extends StatelessWidget {
  const _Notch({required this.left});

  final bool left;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 10,
    height: 20,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: LeylekColors.mist,
        borderRadius: BorderRadius.horizontal(
          right: left ? const Radius.circular(10) : Radius.zero,
          left: left ? Radius.zero : const Radius.circular(10),
        ),
      ),
    ),
  );
}

/// Kartlar arasındaki bekleme bilgisi: kartları ayırmadan, aralarına
/// küçük bir hap olarak.
class WaitStrip extends StatelessWidget {
  const WaitStrip({required this.minutes, this.note, super.key});

  final int minutes;
  final String? note;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: LeylekColors.feather,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: LeylekColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 14,
              color: LeylekColors.muted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                [Formatters.duration(minutes), ?note].join(' · '),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: LeylekColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Uçuş ile kara yolu arasında aktarma şehrinde kalış.
class StayStrip extends StatelessWidget {
  const StayStrip({required this.days, required this.city, super.key});

  final int days;
  final String city;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: LeylekColors.skySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hotel_rounded,
            size: 18,
            color: LeylekColors.skyDeep,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${Formatters.locative(city)} $days gün kal',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: LeylekColors.skyDeep,
                  ),
                ),
                const Text(
                  'Havalimanından şehre ulaşım ve konaklama fiyata dahil değil.',
                  style: TextStyle(fontSize: 12, color: LeylekColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
