import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/result/result.dart';
import '../../../../core/theme/leylek_colors.dart';
import '../../../places/domain/entities/place.dart';
import '../../../places/domain/usecases/suggest_places.dart';
import '../cubit/recent_searches_cubit.dart';

/// Tam ekran yer arama: kartın "Nereden / Nereye" satırına dokununca açılır,
/// seçilen yeri döndürüp kapanır.
///
/// Klavye bu sayfaya aittir: sayfa kapanınca kendiliğinden iner, açılış
/// ekranında öneri listesi ile klavye yarışmaz. Sonuçlar şehir, havalimanı
/// ve ülke diye gruplanır; boşken son aramadaki yerler görünür.
class PlaceSearchPage extends StatefulWidget {
  const PlaceSearchPage({required this.title, super.key});

  /// "Nereden" ya da "Nereye".
  final String title;

  /// Sayfayı aşağıdan yumuşakça açar; seçilen yeri döndürür.
  static Future<Place?> open(BuildContext context, {required String title}) =>
      Navigator.of(context).push<Place>(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (_, _, _) => PlaceSearchPage(title: title),
          transitionsBuilder: (_, animation, _, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        ),
      );

  @override
  State<PlaceSearchPage> createState() => _PlaceSearchPageState();
}

class _PlaceSearchPageState extends State<PlaceSearchPage> {
  /// Hızlı yazarken her harf için istek atılmaz; yazma durunca sorulur.
  static const Duration _debounce = Duration(milliseconds: 250);

  final TextEditingController _controller = TextEditingController();
  Timer? _timer;
  List<Place> _results = const [];
  bool _searched = false;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _timer?.cancel();
    if (text.trim().length < SuggestPlaces.minQueryLength) {
      setState(() {
        _results = const [];
        _searched = false;
      });
      return;
    }
    // Liste son aramalardan sonuç görünümüne hemen geçsin.
    setState(() {});
    _timer = Timer(_debounce, () => _suggest(text));
  }

  Future<void> _suggest(String text) async {
    final result = await context.read<SuggestPlaces>()(text);
    // Bu arada yeni harf yazıldıysa eski sonuç gösterilmez.
    if (!mounted || _controller.text != text) return;
    setState(() {
      _searched = true;
      _results = switch (result) {
        Ok(:final value) => value,
        Err() => const [],
      };
    });
  }

  void _select(Place place) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(place);
  }

  @override
  Widget build(BuildContext context) {
    final typing =
        _controller.text.trim().length >= SuggestPlaces.minQueryLength;
    return Scaffold(
      backgroundColor: LeylekColors.feather,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('place-search-back'),
                    tooltip: 'Geri',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: LeylekColors.ink,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: LeylekColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                key: const Key('place-search-input'),
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  if (_results.isNotEmpty) _select(_results.first);
                },
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: LeylekColors.ink,
                ),
                decoration: const InputDecoration(
                  hintText: 'Şehir, havalimanı ya da ülke',
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
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const Divider(height: 1, color: LeylekColors.fieldLine),
            Expanded(child: typing ? _resultsList() : _recentList(context)),
          ],
        ),
      ),
    );
  }

  Widget _resultsList() {
    if (_searched && _results.isEmpty) {
      return const _Hint('Bu adla bir yer bulamadık. Başka bir yazım dene.');
    }
    final groups = [
      ('Şehirler', PlaceKind.city),
      ('Havalimanları', PlaceKind.airport),
      ('Ülkeler', PlaceKind.country),
    ];
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final (title, kind) in groups)
          if (_results.any((p) => p.kind == kind)) ...[
            _Section(title),
            for (final place in _results.where((p) => p.kind == kind))
              _PlaceTile(place: place, onTap: () => _select(place)),
          ],
      ],
    );
  }

  Widget _recentList(BuildContext context) {
    final recent = context.watch<RecentSearchesCubit>().state;
    final places = <Place>[
      for (final s in recent) ...[?s.toPlace, ?s.fromPlace],
    ];
    if (places.isEmpty) {
      return const _Hint(
        'Bir şehir, havalimanı ya da ülke adı yaz. "Ülke" seçersen '
        'o ülkenin tüm havalimanlarına bakarız.',
      );
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        const _Section('Son aramadan'),
        for (final place in places)
          _PlaceTile(
            place: place,
            onTap: () => _select(place),
            icon: Icons.history_rounded,
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: LeylekColors.muted,
      ),
    ),
  );
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.place, required this.onTap, this.icon});

  final Place place;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (place.kind) {
      PlaceKind.country => 'Ülke · tüm havalimanları',
      PlaceKind.airport => 'Havalimanı · ${place.countryName}',
      PlaceKind.city => place.countryName,
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(
        icon ??
            switch (place.kind) {
              PlaceKind.airport => Icons.local_airport_outlined,
              PlaceKind.country => Icons.public_rounded,
              PlaceKind.city => Icons.location_city_outlined,
            },
        color: LeylekColors.skyDeep,
      ),
      title: Text(
        place.name,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: LeylekColors.ink,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 13, color: LeylekColors.muted),
      ),
      trailing: place.iata == null
          ? null
          : Text(
              place.iata!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: LeylekColors.muted,
              ),
            ),
      onTap: onTap,
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14.5,
        height: 1.45,
        color: LeylekColors.muted,
      ),
    ),
  );
}
