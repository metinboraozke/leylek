import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/result/result.dart';
import '../../../../core/theme/leylek_colors.dart';
import '../../../places/domain/entities/place.dart';
import '../../../places/domain/usecases/suggest_places.dart';
import '../cubit/search_form_cubit.dart';

/// Otomatik tamamlamalı yer alanı.
///
/// Açılış kartındaki satır biçimi: solda küçük işaret, üstte soluk etiket,
/// altta büyük şehir adı ve yanında küçük alan kodu ("İstanbul IST").
/// Çerçeve ve dolgu yok; satırları saran kutu kartta çizilir.
///
/// Metni dışarıdan gelen [value] belirler: "yer değiştir" düğmesine
/// basılınca iki alanın içeriği formdan güncellenir. Kendi denetleyicisini
/// tutar ama yalnızca formla farklılaştığında üzerine yazar; böylece
/// kullanıcı yazarken imleç zıplamaz.
class PlaceField extends StatefulWidget {
  const PlaceField({
    required this.label,
    required this.value,
    required this.onTyped,
    required this.onSelected,
    required this.marker,
    this.hasError = false,
    super.key,
  });

  final String label;
  final PlaceInput value;
  final ValueChanged<String> onTyped;
  final ValueChanged<Place> onSelected;

  /// Etiketin solundaki işaret: kalkışta halka, varışta turuncu nokta.
  final Widget marker;

  /// Hata metni kartta ayrıca yazar; alanda yalnızca etiket kızarır.
  final bool hasError;

  @override
  State<PlaceField> createState() => _PlaceFieldState();
}

class _PlaceFieldState extends State<PlaceField> {
  late final _PlaceController _controller = _PlaceController(
    text: widget.value.text,
  )..place = widget.value.place;
  final FocusNode _focusNode = FocusNode();

  @override
  void didUpdateWidget(covariant PlaceField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.place = widget.value.place;
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
    return GestureDetector(
      // Satırın herhangi bir yerine dokunmak alanı açar.
      behavior: HitTestBehavior.opaque,
      onTap: _focusNode.requestFocus,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              height: 22,
              child: Align(
                alignment: Alignment.centerLeft,
                child: widget.marker,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.hasError
                          ? LeylekColors.beakText
                          : LeylekColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _field(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field() => RawAutocomplete<Place>(
    textEditingController: _controller,
    focusNode: _focusNode,
    displayStringForOption: (place) => place.label,
    optionsBuilder: _suggest,
    onSelected: widget.onSelected,
    fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: widget.onTyped,
          onSubmitted: (_) => onSubmitted(),
          textInputAction: TextInputAction.next,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: LeylekColors.ink,
          ),
          decoration: const InputDecoration(
            hintText: 'Şehir ara',
            hintStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: LeylekColors.muted,
            ),
            isCollapsed: true,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
    optionsViewBuilder: (context, onSelected, options) => _Options(
      options: options.toList(growable: false),
      onSelected: onSelected,
    ),
  );
}

/// Seçili yerin metnini "İstanbul" büyük, " IST" küçük ve soluk çizer.
/// Kullanıcı yazmaya başlayınca seçim düşer ve metin tek biçimde kalır.
class _PlaceController extends TextEditingController {
  _PlaceController({super.text});

  Place? place;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final p = place;
    final code = p?.iata;
    if (p == null || code == null || text != p.label) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: p.name),
        TextSpan(
          text: ' $code',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
            color: LeylekColors.muted,
          ),
        ),
      ],
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
                leading: Icon(switch (place.kind) {
                  PlaceKind.airport => Icons.local_airport_outlined,
                  PlaceKind.country => Icons.public_rounded,
                  PlaceKind.city => Icons.location_city_outlined,
                }),
                title: Text(place.name),
                subtitle: Text(switch (place.kind) {
                  PlaceKind.country => 'Ülke · tüm havalimanları',
                  PlaceKind.airport => 'Havalimanı · ${place.countryName}',
                  PlaceKind.city => place.countryName,
                }),
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
