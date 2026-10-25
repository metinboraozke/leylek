import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/theme/leylek_colors.dart';
import '../../domain/entities/search_query.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_form_cubit.dart';
import 'place_field.dart';

/// Ana arama kartı: nereden, nereye, ne zaman, yarıçap ve "Rotaları ara".
///
/// PAX'in keşfet ekranındaki yüzen kart gibi: beyaz, yumuşak gölgeli,
/// alanlar büyük ve ferah.
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

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: LeylekColors.feather,
        borderRadius: BorderRadius.circular(24),
        boxShadow: LeylekColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  PlaceField(
                    key: const Key('from-field'),
                    label: 'Nereden',
                    icon: Icons.flight_takeoff_rounded,
                    value: state.from,
                    onTyped: form.typeFrom,
                    onSelected: form.selectFrom,
                    errorText: errorFor(ValidationField.from),
                  ),
                  const SizedBox(height: 10),
                  PlaceField(
                    key: const Key('to-field'),
                    label: 'Nereye',
                    icon: Icons.place_rounded,
                    value: state.to,
                    onTyped: form.typeTo,
                    onSelected: form.selectTo,
                    errorText: errorFor(ValidationField.to),
                  ),
                ],
              ),
              Positioned(
                right: 10,
                top: 42,
                child: _SwapButton(onPressed: form.swap),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _DateTile(
            date: state.date,
            errorText: errorFor(ValidationField.date),
            onPicked: form.setDate,
          ),
          const SizedBox(height: 6),
          _RadiusSlider(radiusKm: state.radiusKm, onChanged: form.setRadius),
          if (failure != null && invalid == null) ...[
            Text(
              failure.message,
              style: const TextStyle(
                color: LeylekColors.beakText,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            key: const Key('search-button'),
            onPressed: search is SearchInProgress
                ? null
                : () => context.read<SearchCubit>().search(state.toQuery()),
            icon: const Icon(Icons.travel_explore_rounded),
            label: const Text('Rotaları ara'),
          ),
        ],
      ),
    );
  }
}

class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: LeylekColors.skySoft,
    shape: const CircleBorder(
      side: BorderSide(color: LeylekColors.feather, width: 3),
    ),
    child: IconButton(
      tooltip: 'Kalkış ve varışı değiştir',
      onPressed: onPressed,
      icon: const Icon(Icons.swap_vert_rounded, color: LeylekColors.skyDeep),
    ),
  );
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.date, required this.onPicked, this.errorText});

  final DateTime date;
  final ValueChanged<DateTime> onPicked;
  final String? errorText;

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
    borderRadius: BorderRadius.circular(12),
    onTap: () => _pick(context),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: 'Gidiş tarihi',
        prefixIcon: const Icon(Icons.calendar_month_rounded),
        errorText: errorText,
      ),
      child: Text(Formatters.day(date), style: const TextStyle(fontSize: 16)),
    ),
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
        padding: const EdgeInsets.only(left: 4, top: 4),
        child: Text(
          'Varışa $radiusKm km içindeki havalimanları',
          style: const TextStyle(fontSize: 13.5, color: LeylekColors.muted),
        ),
      ),
      Slider(
        value: radiusKm.toDouble(),
        min: SearchQuery.minRadiusKm.toDouble(),
        max: SearchQuery.maxRadiusKm.toDouble(),
        divisions: (SearchQuery.maxRadiusKm - SearchQuery.minRadiusKm) ~/ 25,
        label: '$radiusKm km',
        activeColor: LeylekColors.skyDeep,
        onChanged: (v) => onChanged(v.round()),
      ),
    ],
  );
}
