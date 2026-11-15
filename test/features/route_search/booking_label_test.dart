import 'package:flutter_test/flutter_test.dart';
import 'package:leylek/features/route_search/domain/entities/route_option.dart';
import 'package:leylek/features/route_search/presentation/widgets/journey_cards.dart';

BookingLink _link(BookingKind kind, String url) => BookingLink(
  kind: kind,
  provider: 'X',
  url: Uri.parse(url),
  lines: const [],
);

void main() {
  test('düğme doğrudan bilet vaat etmez, gidilen siteyi yazar', () {
    expect(
      bookingButtonLabel(
        _link(
          BookingKind.flight,
          'https://www.google.com/travel/flights?q=Flights%20from%20SAW',
        ),
      ),
      "Google Flights'a git",
    );
    expect(
      bookingButtonLabel(_link(BookingKind.flight, 'https://www.flypgs.com')),
      'Sağlayıcının sitesine git',
    );
    expect(
      bookingButtonLabel(_link(BookingKind.ground, 'https://www.oebb.at/')),
      'İlgili siteye git',
    );
    expect(
      bookingButtonLabel(
        _link(BookingKind.route, 'https://www.google.com/maps/dir/?api=1'),
      ),
      "Google Haritalar'a git",
    );
  });
}
