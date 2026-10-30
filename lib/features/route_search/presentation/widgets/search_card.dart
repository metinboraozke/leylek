import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/theme/leylek_colors.dart';
import '../../domain/entities/search_query.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_form_cubit.dart';
import 'place_field.dart';

/// Ana arama kartı: nereden, nereye, gidiş, ara tatil, yarıçap.
///
/// Açılış tasarımı: büyük yuvarlak beyaz kart; nereden/nereye tek açık
/// mavi kutuda alt alta, sağda yuvarlak değiştir düğmesi; altında gidiş
/// ve ara tatil yan yana; sonra yarıçap kaydırıcısı ve büyük arama
/// düğmesi.
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: LeylekColors.feather,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F3550),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: Color(0x080F3550),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlacesBox(
            from: PlaceField(
              key: const Key('from-field'),
              label: 'Nereden',
              marker: const _OriginMarker(),
              value: state.from,
              onTyped: form.typeFrom,
              onSelected: form.selectFrom,
              hasError: errorFor(ValidationField.from) != null,
            ),
            to: PlaceField(
              key: const Key('to-field'),
              label: 'Nereye',
              marker: const _DestinationMarker(),
              value: state.to,
              onTyped: form.typeTo,
              onSelected: form.selectTo,
              hasError: errorFor(ValidationField.to) != null,
            ),
            onSwap: form.swap,
          ),
          if (placeError != null) _ErrorText(placeError),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DateBox(date: state.date, onPicked: form.setDate),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StopoverBox(
                  days: state.stopoverDays,
                  onChanged: form.setStopover,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _RadiusSlider(radiusKm: state.radiusKm, onChanged: form.setRadius),
          if (otherError != null) _ErrorText(otherError),
          const SizedBox(height: 10),
          FilledButton(
            key: const Key('search-button'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
            onPressed: search is SearchInProgress
                ? null
                : () => context.read<SearchCubit>().search(state.toQuery()),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Rotaları ara'),
                SizedBox(width: 14),
                Icon(Icons.arrow_forward_rounded, size: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nereden ve nereye: tek kutuda alt alta, arada ince çizgi; değiştir
/// düğmesi sağda, iki satırın ortasında.
class _PlacesBox extends StatelessWidget {
  const _PlacesBox({
    required this.from,
    required this.to,
    required this.onSwap,
  });

  final Widget from;
  final Widget to;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 4, 12, 4),
    decoration: BoxDecoration(
      color: LeylekColors.field,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              from,
              const Padding(
                padding: EdgeInsets.only(left: 36),
                child: Divider(
                  height: 1,
                  thickness: 1.2,
                  color: LeylekColors.fieldLine,
                ),
              ),
              to,
            ],
          ),
        ),
        const SizedBox(width: 8),
        _SwapButton(onPressed: onSwap),
      ],
    ),
  );
}

class _OriginMarker extends StatelessWidget {
  const _OriginMarker();

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: LeylekColors.skyDeep, width: 2.6),
    ),
  );
}

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) => Container(
    width: 11,
    height: 11,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: LeylekColors.beak,
    ),
  );
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

/// Kutunun sağındaki yuvarlak beyaz değiştir düğmesi.
class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: LeylekColors.feather,
      boxShadow: [
        BoxShadow(
          color: Color(0x140F3550),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: SizedBox.square(
      dimension: 44,
      child: IconButton(
        tooltip: 'Kalkış ve varışı değiştir',
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: const Icon(
          Icons.swap_vert_rounded,
          size: 26,
          color: LeylekColors.skyDeep,
        ),
      ),
    ),
  );
}

/// Açık mavi, küçük etiketli kutu: "Gidiş / 4 Kas, Çar" gibi.
class _ValueBox extends StatelessWidget {
  const _ValueBox({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: LeylekColors.field,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: LeylekColors.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: LeylekColors.ink,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

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
  Widget build(BuildContext context) => _ValueBox(
    key: const Key('date-box'),
    label: 'Gidiş',
    value: Formatters.cardDay(date),
    onTap: () => _pick(context),
  );
}

/// Aktarma şehrinde kaç gün kalınacağı. Kutuya dokununca alttan seçenek
/// listesi açılır.
class _StopoverBox extends StatelessWidget {
  const _StopoverBox({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  static const _options = [
    (0, 'Konaklamasız'),
    (1, '1 gün kal'),
    (2, '2 gün kal'),
    (3, '3 gün kal'),
  ];

  Future<void> _pick(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: LeylekColors.feather,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          key: const Key('stopover-picker'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 6),
              child: Text(
                'Aktarma şehrinde ara tatil',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: LeylekColors.ink,
                ),
              ),
            ),
            for (final (value, label) in _options)
              ListTile(
                key: Key('stopover-$value'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: value == days
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: LeylekColors.ink,
                  ),
                ),
                trailing: value == days
                    ? const Icon(
                        Icons.check_rounded,
                        color: LeylekColors.skyDeep,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) => _ValueBox(
    key: const Key('stopover-box'),
    label: 'Ara tatil',
    value: _options
        .firstWhere((o) => o.$1 == days, orElse: () => (days, '$days gün kal'))
        .$2,
    onTap: () => _pick(context),
  );
}

class _RadiusSlider extends StatelessWidget {
  const _RadiusSlider({required this.radiusKm, required this.onChanged});

  final int radiusKm;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Varışa yakın havalimanları',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: LeylekColors.ink,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: LeylekColors.field,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$radiusKm km',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: LeylekColors.skyDeep,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 2),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 6,
          activeTrackColor: LeylekColors.skyDeep,
          inactiveTrackColor: LeylekColors.fieldLine,
          activeTickMarkColor: Colors.transparent,
          inactiveTickMarkColor: Colors.transparent,
          thumbShape: const _RingThumb(),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          overlayColor: LeylekColors.skyDeep.withValues(alpha: 0.08),
          showValueIndicator: ShowValueIndicator.never,
          // Ray kartın iç kenarlarına kadar uzansın.
          padding: EdgeInsets.zero,
        ),
        child: SizedBox(
          height: 32,
          child: Slider(
            value: radiusKm.toDouble(),
            min: SearchQuery.minRadiusKm.toDouble(),
            max: SearchQuery.maxRadiusKm.toDouble(),
            divisions:
                (SearchQuery.maxRadiusKm - SearchQuery.minRadiusKm) ~/ 25,
            semanticFormatterCallback: (v) => '${v.round()} km',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ),
    ],
  );
}

/// Kaydırıcının topuzu: beyaz içli, koyu mavi halka.
class _RingThumb extends SliderComponentShape {
  const _RingThumb();

  static const double _radius = 12;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(
      center.translate(0, 1.5),
      _radius,
      Paint()
        ..color = const Color(0x220F3550)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(center, _radius, Paint()..color = LeylekColors.feather);
    canvas.drawCircle(
      center,
      _radius - 1.7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..color = LeylekColors.skyDeep,
    );
  }
}
