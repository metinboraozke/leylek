import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/result/result.dart';
import '../../../places/domain/entities/place.dart';
import '../../../places/domain/usecases/suggest_places.dart';
import '../cubit/search_form_cubit.dart';

/// Otomatik tamamlamalı yer alanı.
///
/// Metni dışarıdan gelen [value] belirler: "yer değiştir" düğmesine
/// basılınca iki alanın içeriği formdan güncellenir. Kendi denetleyicisini
/// tutar ama yalnızca formla farklılaştığında üzerine yazar; böylece
/// kullanıcı yazarken imleç zıplamaz.
class PlaceField extends StatefulWidget {
  const PlaceField({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTyped,
    required this.onSelected,
    this.errorText,
    super.key,
  });

  final String label;
  final IconData icon;
  final PlaceInput value;
  final ValueChanged<String> onTyped;
  final ValueChanged<Place> onSelected;
  final String? errorText;

  @override
  State<PlaceField> createState() => _PlaceFieldState();
}

class _PlaceFieldState extends State<PlaceField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value.text);
  final FocusNode _focusNode = FocusNode();

  @override
  void didUpdateWidget(covariant PlaceField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.value.text) {
      _controller.value = TextEditingValue(
        text: widget.value.text,
        selection: TextSelection.collapsed(offset: widget.value.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<Iterable<Place>> _suggest(TextEditingValue value) async {
    final result = await context.read<SuggestPlaces>()(value.text);
    // Öneri gelmezse alan sessizce boş liste gösterir; asıl hata
    // aramada kullanıcıya söylenir. Yazarken her harfte hata kutusu
    // çıkması rahatsız ederdi.
    return switch (result) {
      Ok(:final value) => value,
      Err() => const <Place>[],
    };
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Place>(
      textEditingController: _controller,
      focusNode: _focusNode,
      displayStringForOption: (place) => place.label,
      optionsBuilder: _suggest,
      onSelected: widget.onSelected,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: widget.onTyped,
        onSubmitted: (_) => onSubmitted(),
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: Icon(widget.icon),
          errorText: widget.errorText,
        ),
      ),
      optionsViewBuilder: (context, onSelected, options) => _Options(
        options: options.toList(growable: false),
        onSelected: onSelected,
      ),
    );
  }
}

class _Options extends StatelessWidget {
  const _Options({required this.options, required this.onSelected});

  final List<Place> options;
  final ValueChanged<Place> onSelected;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280, maxWidth: 420),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final place = options[index];
              return ListTile(
                leading: Icon(
                  place.kind == PlaceKind.airport
                      ? Icons.local_airport_outlined
                      : Icons.location_city_outlined,
                ),
                title: Text(place.name),
                subtitle: Text(place.countryName),
                trailing: place.iata == null ? null : Text(place.iata!),
                onTap: () => onSelected(place),
              );
            },
          ),
        ),
      ),
    );
  }
}
