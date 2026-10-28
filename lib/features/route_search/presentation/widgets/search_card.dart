import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/theme/leylek_colors.dart';
import '../../domain/entities/search_query.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_form_cubit.dart';
import 'place_field.dart';

/// Ana arama kartı: nereden, nereye, ne zaman, konaklama, yarıçap.
///
/// Ölçüler PAX'in keşfet ekranındaki yüzen karttan: 12'lik iç boşluk,
/// nereden/nereye yan yana, küçük etiketli dolgulu kutular, 44'lük buton.
/// Kart ekranın üst yarısında kalmalı; altta küre ve leylek görünsün.
class SearchCard extends StatelessWidget {
  const SearchCard({super.key});

  @override
  Widget build(BuildContext context) {
    final form = context.watch<SearchFormCubit>();
    final state = form.state;
    final search = context.watch<SearchCubit>().state;
    final failure = search is SearchError ? search.failure : null;
    final invalid = failure is ValidationFailure ? failure : null;
    String? errorFor(ValidationField field) =>
        invalid?.field == field ? invalid?.message : null;
    final placeError =
        errorFor(ValidationField.from) ?? errorFor(ValidationField.to);
    final otherError = invalid == null
        ? failure?.message
        : errorFor(ValidationField.date) ??
              errorFor(ValidationField.stopover) ??
              errorFor(ValidationField.radius);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LeylekColors.feather,
        borderRadius: BorderRadius.circular(20),
        boxShadow: LeylekColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: PlaceField(
                  key: const Key('from-field'),
                  label: 'Nereden',
                  value: state.from,
                  onTyped: form.typeFrom,
                  onSelected: form.selectFrom,
                  hasError: errorFor(ValidationField.from) != null,
                ),
              ),
              _SwapButton(onPressed: form.swap),
              Expanded(
                child: PlaceField(
                  key: const Key('to-field'),
                  label: 'Nereye',
                  value: state.to,
                  onTyped: form.typeTo,
                  onSelected: form.selectTo,
                  hasError: errorFor(ValidationField.to) != null,
                ),
              ),
            ],
          ),
          if (placeError != null) _ErrorText(placeError),
          const SizedBox(height: 8),
          _DateBox(date: state.date, onPicked: form.setDate),
          const SizedBox(height: 8),
          _StopoverPicker(
            days: state.stopoverDays,
            onChanged: form.setStopover,
          ),
          _RadiusSlider(radiusKm: state.radiusKm, onChanged: form.setRadius),
          if (otherError != null) _ErrorText(otherError),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('search-button'),
            onPressed: search is SearchInProgress
                ? null
                : () => context.read<SearchCubit>().search(state.toQuery()),
            child: const Text('Rotaları ara'),
          ),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, left: 4),
    child: Text(
      text,
      style: const TextStyle(
        color: LeylekColors.beakText,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

/// Nereden ile nereye arasındaki küçük değiştir düğmesi.
class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 32,
    height: 46,
    child: IconButton(
      tooltip: 'Kalkış ve varışı değiştir',
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: const Icon(
        Icons.swap_horiz_rounded,
        size: 18,
        color: LeylekColors.muted,
      ),
    ),
  );
}

/// PAX'in bütçe/tarih kutusu kalıbı: küçük etiket, altında kalın değer.
class _DateBox extends StatelessWidget {
  const _DateBox({required this.date, required this.onPicked});

  final DateTime date;
  final ValueChanged<DateTime> onPicked;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: date.isBefore(today) ? today : date,
      firstDate: today,
      lastDate: today.add(const Duration(days: SearchQuery.maxDaysAhead)),
      locale: const Locale('tr'),
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: () => _pick(context),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: LeylekColors.skySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Gidiş tarihi',
            style: TextStyle(fontSize: 11, color: LeylekColors.muted),
          ),
          SizedBox(
            height: 22,
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 15,
                  color: LeylekColors.skyDeep,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    Formatters.day(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: LeylekColors.wingtip,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Aktarma şehrinde kaç gün kalınacağı: yatay kaydırılan küçük haplar
/// (PAX'in "Haftasonu / 3-5 gün" çipleriyle aynı ölçü).
class _StopoverPicker extends StatelessWidget {
  const _StopoverPicker({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  static const _options = [
    (0, 'Konaklamasız'),
    (1, '1 gün kal'),
    (2, '2 gün kal'),
    (3, '3 gün kal'),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(left: 4, bottom: 6),
        child: Text(
          'Aktarma şehrinde konaklama',
          style: TextStyle(fontSize: 11, color: LeylekColors.muted),
        ),
      ),
      SizedBox(
        height: 34,
        child: ListView.separated(
          key: const Key('stopover-picker'),
          scrollDirection: Axis.horizontal,
          itemCount: _options.length,
          separatorBuilder: (_, _) => const SizedBox(width: 4),
          itemBuilder: (context, i) {
            final (value, label) = _options[i];
            final selected = value == days;
            return Semantics(
              button: true,
              selected: selected,
              child: GestureDetector(
                key: Key('stopover-$value'),
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? LeylekColors.skyDeep
                        : LeylekColors.skySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? LeylekColors.feather
                          : LeylekColors.muted,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _RadiusSlider extends StatelessWidget {
  const _RadiusSlider({required this.radiusKm, required this.onChanged});

  final int radiusKm;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, top: 8),
        child: Text(
          'Varışa $radiusKm km içindeki havalimanları',
          style: const TextStyle(fontSize: 11, color: LeylekColors.muted),
        ),
      ),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        ),
        child: SizedBox(
          height: 28,
          child: Slider(
            value: radiusKm.toDouble(),
            min: SearchQuery.minRadiusKm.toDouble(),
            max: SearchQuery.maxRadiusKm.toDouble(),
            divisions:
                (SearchQuery.maxRadiusKm - SearchQuery.minRadiusKm) ~/ 25,
            label: '$radiusKm km',
            activeColor: LeylekColors.skyDeep,
            inactiveColor: LeylekColors.skySoft,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ),
    ],
  );
}
