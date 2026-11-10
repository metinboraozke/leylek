import 'package:flutter/material.dart';

import '../../../../core/theme/leylek_colors.dart';
import '../../../places/domain/entities/place.dart';
import '../cubit/search_form_cubit.dart';
import '../pages/place_search_page.dart';

/// Kalkış ya da varış satırı.
///
/// Açılış kartındaki satır biçimi: solda küçük işaret, üstte soluk etiket,
/// altta büyük şehir adı ve yanında küçük alan kodu ("İstanbul IST").
/// Çerçeve ve dolgu yok; satırları saran kutu kartta çizilir.
///
/// Satır yazı alanı değildir: dokununca tam ekran yer arama açılır, seçilen
/// yer [onSelected] ile forma döner. Klavye o sayfayla birlikte açılıp
/// kapanır.
class PlaceField extends StatelessWidget {
  const PlaceField({
    required this.label,
    required this.value,
    required this.onSelected,
    required this.marker,
    this.hasError = false,
    super.key,
  });

  final String label;
  final PlaceInput value;
  final ValueChanged<Place> onSelected;

  /// Etiketin solundaki işaret: kalkışta halka, varışta turuncu nokta.
  final Widget marker;

  /// Hata metni kartta ayrıca yazar; alanda yalnızca etiket kızarır.
  final bool hasError;

  Future<void> _open(BuildContext context) async {
    final place = await PlaceSearchPage.open(context, title: label);
    if (place != null) onSelected(place);
  }

  @override
  Widget build(BuildContext context) {
    final place = value.place;
    final text = place?.name ?? value.text;
    return Semantics(
      button: true,
      label: '$label: ${text.isEmpty ? 'seçilmedi' : text}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                height: 22,
                child: Align(alignment: Alignment.centerLeft, child: marker),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: hasError
                            ? LeylekColors.beakText
                            : LeylekColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      text.isEmpty
                          ? const TextSpan(
                              text: 'Şehir ara',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: LeylekColors.muted,
                              ),
                            )
                          : TextSpan(
                              children: [
                                TextSpan(text: text),
                                if (place?.iata != null)
                                  TextSpan(
                                    text: ' ${place!.iata}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.3,
                                      color: LeylekColors.muted,
                                    ),
                                  ),
                              ],
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: LeylekColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
