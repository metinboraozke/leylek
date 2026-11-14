import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/l10n/language_cubit.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/leylek_colors.dart';
import '../route_search/presentation/widgets/booking_card.dart';

/// Ayarlar ve Hakkında: dil seçimi, uygulamanın ne yaptığı, gizlilik
/// politikası, kaynak kod, veri kaynakları ve açık kaynak lisansları.
///
/// Hesap ve sunucu tarafı ayar yok; dil seçimi yalnızca cihazda saklanır.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const String version = '1.0.0';
  static const String repoUrl = 'https://github.com/metinboraozke/leylek';
  static const String privacyUrl = '$repoUrl/blob/main/PRIVACY.md';

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageCubit>().state;
    return Scaffold(
      backgroundColor: LeylekColors.mist,
      appBar: AppBar(
        backgroundColor: LeylekColors.mist,
        surfaceTintColor: Colors.transparent,
        foregroundColor: LeylekColors.ink,
        title: Text(
          S.t('Ayarlar', 'Settings'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: LeylekColors.ink,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Section(S.t('Dil', 'Language')),
          _Card(
            children: [
              for (final (code, name) in const [
                ('tr', 'Türkçe'),
                ('en', 'English'),
              ])
                ListTile(
                  key: Key('language-$code'),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: LeylekColors.ink,
                    ),
                  ),
                  trailing: lang == code
                      ? const Icon(
                          Icons.check_rounded,
                          color: LeylekColors.skyDeep,
                        )
                      : null,
                  onTap: () => context.read<LanguageCubit>().select(code),
                ),
            ],
          ),
          _Section(S.t('Hakkında', 'About')),
          _Card(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Text(
                  S.t(
                    'Leylek, doğrudan uçuş pahalıyken yakındaki bir havalimanına '
                        'uçup trenle ya da otobüsle devam eden rotaları bulur. '
                        'Bilet satmaz, hesap istemez, reklam ve ortaklık '
                        'bağlantısı yoktur. Açık kaynak ve kâr amacı gütmez.',
                    'Leylek finds routes that fly to a nearby airport and '
                        'continue by train or bus when the direct flight is '
                        'expensive. It sells no tickets, needs no account, and '
                        'has no ads or affiliate links. Open source and '
                        'non-commercial.',
                  ),
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: LeylekColors.ink,
                  ),
                ),
              ),
              _LinkTile(
                key: const Key('privacy-link'),
                icon: Icons.privacy_tip_outlined,
                title: S.t('Gizlilik politikası', 'Privacy policy'),
                url: privacyUrl,
              ),
              _LinkTile(
                icon: Icons.code_rounded,
                title: S.t('Kaynak kod (GitHub)', 'Source code (GitHub)'),
                url: repoUrl,
              ),
              ListTile(
                leading: const Icon(
                  Icons.description_outlined,
                  color: LeylekColors.skyDeep,
                ),
                title: Text(
                  S.t('Açık kaynak lisansları', 'Open source licences'),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Leylek',
                  applicationVersion: version,
                ),
              ),
            ],
          ),
          _Section(S.t('Veri kaynakları', 'Data sources')),
          _Card(
            children: [
              const _LinkTile(
                icon: Icons.train_outlined,
                title: 'Transitous',
                url: 'https://transitous.org/sources/',
              ),
              _LinkTile(
                icon: Icons.map_outlined,
                title: S.t(
                  'OpenStreetMap katkıcıları',
                  'OpenStreetMap contributors',
                ),
                url: 'https://www.openstreetmap.org/copyright',
              ),
              const _LinkTile(
                icon: Icons.local_airport_outlined,
                title: 'OurAirports',
                url: 'https://ourairports.com/data/',
              ),
              const _LinkTile(
                icon: Icons.location_city_outlined,
                title: 'GeoNames',
                url: 'https://www.geonames.org/',
              ),
              ListTile(
                leading: const Icon(
                  Icons.sell_outlined,
                  color: LeylekColors.skyDeep,
                ),
                title: Text(
                  S.t(
                    'Uçuş fiyatları: Aviasales verisi',
                    'Flight prices: Aviasales data',
                  ),
                ),
                subtitle: Text(
                  S.t(
                    'Son 48 saatte görülen fiyatlar; satın alırken değişebilir.',
                    'Prices seen in the last 48 hours; they may change at '
                        'checkout.',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              '${S.t('Sürüm', 'Version')} $version',
              style: const TextStyle(fontSize: 12.5, color: LeylekColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: LeylekColors.muted,
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: LeylekColors.feather,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: Column(mainAxisSize: MainAxisSize.min, children: children),
  );
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.url,
    super.key,
  });

  final IconData icon;
  final String title;
  final String url;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: LeylekColors.skyDeep),
    title: Text(title),
    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
    onTap: () => openBookingLink(Uri.parse(url)),
  );
}
