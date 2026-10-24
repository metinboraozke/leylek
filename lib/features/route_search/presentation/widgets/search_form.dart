import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/format/formatters.dart';
import '../../domain/entities/search_query.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_form_cubit.dart';
import 'place_field.dart';

/// Nereden, nereye, ne zaman ve yarıçap alanları ile arama düğmesi.
class SearchForm extends StatelessWidget {
  const SearchForm({super.key});

  @override
  Widget build(BuildContext context) {
    final form = context.watch<SearchFormCubit>();
    final state = form.state;
    final search = context.watch<SearchCubit>().state;
    final invalid = switch (search) {
      SearchError(failure: final ValidationFailure f) => f,
      _ => null,
    };
    String? errorFor(ValidationField field) =>
        invalid?.field == field ? invalid?.message : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PlaceField(
              key: const Key('from-field'),
              label: 'Nereden',
              icon: Icons.flight_takeoff,
              value: state.from,
              onTyped: form.typeFrom,
              onSelected: form.selectFrom,
              errorText: errorFor(ValidationField.from),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Kalkış ve varışı değiştir',
                onPressed: form.swap,
                icon: const Icon(Icons.swap_vert),
              ),
            ),
            PlaceField(
              key: const Key('to-field'),
              label: 'Nereye',
              icon: Icons.place_outlined,
              value: state.to,
              onTyped: form.typeTo,
              onSelected: form.selectTo,
              errorText: errorFor(ValidationField.to),
            ),
            const SizedBox(height: 12),
            _DateTile(
              date: state.date,
              errorText: errorFor(ValidationField.date),
              onPicked: form.setDate,
            ),
            const SizedBox(height: 8),
            _RadiusSlider(radiusKm: state.radiusKm, onChanged: form.setRadius),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('search-button'),
              onPressed: search is SearchInProgress
                  ? null
                  : () => context.read<SearchCubit>().search(state.toQuery()),
              child: const Text('Rota bul'),
            ),
          ],
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Gidiş tarihi',
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          errorText: errorText,
        ),
        child: Text(Formatters.day(date)),
      ),
    );
  }
}

class _RadiusSlider extends StatelessWidget {
  const _RadiusSlider({required this.radiusKm, required this.onChanged});

  final int radiusKm;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Varışa en fazla $radiusKm km uzaklıktaki havalimanları',
          style: theme.textTheme.bodyMedium,
        ),
        Slider(
          value: radiusKm.toDouble(),
          min: SearchQuery.minRadiusKm.toDouble(),
          max: SearchQuery.maxRadiusKm.toDouble(),
          divisions: (SearchQuery.maxRadiusKm - SearchQuery.minRadiusKm) ~/ 25,
          label: '$radiusKm km',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}
