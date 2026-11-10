import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/leylek_colors.dart';
import '../../domain/entities/search_query.dart';
import '../cubit/fare_calendar_cubit.dart';

/// Gidiş günü şeridi: yan yana günler, altlarında o güne varışa en ucuz
/// doğrudan uçuş fiyatı. Görünen ayın en ucuz günü yeşil yazar; böylece
/// "bir gün önce gitsem daha ucuz" arama yapmadan görülür.
///
/// Fiyatlar [FareCalendarCubit]'ten, kaydırdıkça görünen aylar için
/// yüklenir. Uzak tarih için sağdaki takvim düğmesi tam takvimi açar.
class DateStrip extends StatefulWidget {
  const DateStrip({
    required this.date,
    required this.onPicked,
    required this.from,
    required this.to,
    super.key,
  });

  final DateTime date;
  final ValueChanged<DateTime> onPicked;

  /// Aramaya giden kalkış ve varış değerleri; fiyatlar bunlar için sorulur.
  final String from;
  final String to;

  @override
  State<DateStrip> createState() => _DateStripState();
}

class _DateStripState extends State<DateStrip> {
  static const double _chipWidth = 54;
  static const double _gap = 6;
  static const double _extent = _chipWidth + _gap;

  late final DateTime _today = _dayOnly(DateTime.now());
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: _offsetFor(widget.date),
  );

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _dayAt(int index) =>
      DateTime(_today.year, _today.month, _today.day + index);

  int _indexOf(DateTime day) => _dayOnly(day).difference(_today).inDays;

  /// Seçili gün soldan üçüncü sırada görünsün: önceki iki gün de seçilebilir.
  double _offsetFor(DateTime day) =>
      ((_indexOf(day) - 2).clamp(0, SearchQuery.maxDaysAhead)) * _extent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadVisible());
  }

  @override
  void didUpdateWidget(covariant DateStrip old) {
    super.didUpdateWidget(old);
    final routeChanged = old.from != widget.from || old.to != widget.to;
    if (!DateUtils.isSameDay(old.date, widget.date) && _scroll.hasClients) {
      final target = _offsetFor(widget.date);
      final visible = _scroll.offset;
      final width = _scroll.position.viewportDimension;
      // Takvimden uzak bir gün seçildiyse şerit oraya kayar.
      if (target < visible || target > visible + width - _extent) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    }
    if (routeChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadVisible());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _loadVisible() {
    if (!mounted) return;
    final offset = _scroll.hasClients
        ? _scroll.offset
        : _offsetFor(widget.date);
    final width = _scroll.hasClients
        ? _scroll.position.viewportDimension
        : 360.0;
    final first = (offset / _extent).floor();
    final last = ((offset + width) / _extent).ceil();
    context.read<FareCalendarCubit>().ensure(widget.from, widget.to, [
      for (var i = first; i <= last; i++) _dayAt(i),
    ]);
  }

  Future<void> _openCalendar() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.date.isBefore(_today) ? _today : widget.date,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: SearchQuery.maxDaysAhead)),
      locale: const Locale('tr'),
    );
    if (picked != null) widget.onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final calendar = context.watch<FareCalendarCubit>().state;
    final prices = calendar.route == '${widget.from}|${widget.to}'
        ? calendar
        : const FareCalendarState();
    // Ayın en ucuz günü: yalnızca o ayda birden fazla fiyat varsa.
    final cheapest = <String, int>{};
    prices.prices.forEach((day, price) {
      final month = day.substring(0, 7);
      final best = cheapest[month];
      if (best == null || price < best) cheapest[month] = price;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'Gidiş',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: LeylekColors.muted,
                ),
              ),
            ),
            const Spacer(),
            Text(
              Formatters.cardDay(widget.date),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: LeylekColors.ink,
              ),
            ),
            const SizedBox(width: 2),
            SizedBox.square(
              dimension: 34,
              child: IconButton(
                key: const Key('date-box'),
                tooltip: 'Takvimden seç',
                padding: EdgeInsets.zero,
                onPressed: _openCalendar,
                icon: const Icon(
                  Icons.calendar_month_rounded,
                  size: 20,
                  color: LeylekColors.skyDeep,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 66,
          child: NotificationListener<ScrollEndNotification>(
            onNotification: (_) {
              _loadVisible();
              return false;
            },
            child: ListView.builder(
              key: const Key('date-strip'),
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              itemExtent: _extent,
              itemCount: SearchQuery.maxDaysAhead + 1,
              itemBuilder: (context, i) {
                final day = _dayAt(i);
                final price = prices.priceOn(day);
                final monthBest =
                    cheapest[FareCalendarState.monthKey(day)] == price;
                return Padding(
                  padding: const EdgeInsets.only(right: _gap),
                  child: _DayChip(
                    day: day,
                    price: price,
                    cheapest: price != null && monthBest,
                    selected: DateUtils.isSameDay(day, widget.date),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onPicked(day);
                    },
                  ),
                );
              },
            ),
          ),
        ),
        if (prices.prices.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 4, top: 4),
            child: Text(
              'Doğrudan uçuşun en ucuz fiyatı, ₺ · yeşil: ayın en ucuzu',
              style: TextStyle(fontSize: 11, color: LeylekColors.muted),
            ),
          ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.price,
    required this.cheapest,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final int? price;
  final bool cheapest;
  final bool selected;
  final VoidCallback onTap;

  static final NumberFormat _number = NumberFormat.decimalPattern('tr_TR');

  @override
  Widget build(BuildContext context) {
    final fg = selected ? LeylekColors.feather : LeylekColors.ink;
    final soft = selected ? LeylekColors.skyLight : LeylekColors.muted;
    final priceColor = selected
        ? LeylekColors.feather
        : cheapest
        ? LeylekColors.meadowText
        : LeylekColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${Formatters.day(day)}'
          '${price == null ? '' : ', ${_number.format(price)} lira'}',
      excludeSemantics: true,
      child: Material(
        color: selected ? LeylekColors.skyDeep : LeylekColors.field,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: Key('day-${day.year}-${day.month}-${day.day}'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('EEE', 'tr').format(day),
                style: TextStyle(fontSize: 11, color: soft),
              ),
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: fg,
                ),
              ),
              Text(
                price == null ? '–' : _number.format(price),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: cheapest || selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: priceColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
