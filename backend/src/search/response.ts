import { toOffsetIso } from '../core/time.js';
import type { Place, PlaceIndex } from '../data/place-index.js';
import { englishCityName, type Lang, localName } from '../data/regions.js';
import { bookingLinks } from './booking.js';
import type { Dropped, RankedCard, SearchQuery } from './types.js';

/**
 * Yanıt sözleşmesi. Uygulamadaki `SearchResultMapper` bu biçimi okur;
 * alan eklemek serbest, ad değiştirmek ya da silmek iki tarafı birden
 * değiştirmeyi gerektirir.
 */
export const ATTRIBUTION = [
  { name: 'Transitous', url: 'https://transitous.org/sources/' },
  { name: 'OpenStreetMap katkıcıları', url: 'https://www.openstreetmap.org/copyright' },
  { name: 'OurAirports', url: 'https://ourairports.com/data/' },
  { name: 'GeoNames', url: 'https://www.geonames.org/' },
  { name: 'Uçuş fiyatları: Aviasales verisi, son 48 saatte görülen', url: null },
];

const ATTRIBUTION_EN = [
  { name: 'Transitous', url: 'https://transitous.org/sources/' },
  { name: 'OpenStreetMap contributors', url: 'https://www.openstreetmap.org/copyright' },
  { name: 'OurAirports', url: 'https://ourairports.com/data/' },
  { name: 'GeoNames', url: 'https://www.geonames.org/' },
  { name: 'Flight prices: Aviasales data, seen in the last 48 hours', url: null },
];

export function attributionFor(lang: Lang) {
  return lang === 'en' ? ATTRIBUTION_EN : ATTRIBUTION;
}

export interface ResponseContext {
  query: SearchQuery;
  from: Place;
  to: Place;
  cards: RankedCard[];
  dropped: Dropped[];
  warnings: string[];
  /** 1 EUR kaç birim (seçilen para birimi). */
  rate: number;
  places: PlaceIndex;
  now: number;
}

function departureCity(ctx: ResponseContext, iata: string, lang: Lang): string | undefined {
  const name = ctx.places.cityNameForIata(iata);
  if (!name) return undefined;
  if (lang === 'tr') return name;
  // Kalkış şehirleri çoğunlukla Türkiye'de; tabloda yoksa ad aynen kalır.
  const country = ctx.places.countryForIata(iata);
  return country ? englishCityName(name, country) : name;
}

export function toResponse(ctx: ResponseContext) {
  const money = (eur: number) => Math.round(eur * ctx.rate);
  const lang: Lang = ctx.query.lang ?? 'tr';
  // Havalimanının şehri seçilen dilde ("Münih" / "Munich").
  const airportCity = (a: RankedCard['airport']) => {
    const city = ctx.places.cityForAirport(a);
    return city ? localName(city, lang) : a.municipality;
  };
  const recommended = ctx.cards.find((c) => c.badges.includes('RECOMMENDED'));

  return {
    query: {
      from: localName(ctx.from, lang),
      to: localName(ctx.to, lang),
      // Ülke seçildiyse uygulama her kartta inilen şehri gösterir.
      fromKind: ctx.from.kind,
      toKind: ctx.to.kind,
      date: ctx.query.date,
      radiusKm: ctx.query.radiusKm,
      stopoverDays: ctx.query.stopoverDays,
      currency: ctx.query.currency,
    },
    recommendedRank: recommended?.rank ?? null,
    options: ctx.cards.map((c) => ({
      rank: c.rank,
      kind: c.kind,
      badges: c.badges,
      reason: c.reason,
      via:
        c.kind === 'VIA'
          ? {
              iata: c.airport.iata,
              name: airportCity(c.airport),
              country: c.airport.country,
              distanceKm: Math.round(c.distanceKm),
            }
          : undefined,
      // Kalkılan şehir ("Ankara"); kalkış ülke olunca kartın kalkışı.
      departureCity: departureCity(ctx, c.flight.originAirport, lang),
      // Doğrudan uçuşta inilen şehir ("Milano"); varış ülke olunca kartın varışı.
      arrivalCity:
        c.kind === 'DIRECT'
          ? airportCity(c.airport)
          : undefined,
      flight: {
        airport: c.kind === 'DIRECT' ? c.airport.iata : undefined,
        fromAirport: c.flight.originAirport,
        toAirport: c.flight.destAirport,
        price: money(c.flight.priceEur),
        airline: c.flight.airline,
        flightNumber: c.flight.flightNumber,
        transfers: c.flight.transfers,
        departAt: c.flight.departIso,
        arriveAt: toOffsetIso(c.flight.arriveMs, c.airport.tz),
        priceSeenHoursAgo: c.flight.priceAgeDays === null ? null : c.flight.priceAgeDays * 24,
      },
      ground: c.ground
        ? {
            departAt: toOffsetIso(c.ground.departMs, c.airport.tz),
            arriveAt: toOffsetIso(c.ground.arriveMs, ctx.to.tz),
            durationMin: Math.round((c.ground.arriveMs - c.ground.departMs) / 60_000),
            waitMin: c.ground.waitMin,
            transfers: c.ground.transfers,
            legs: c.ground.legs.map((l) => ({
              mode: l.mode,
              from: l.fromName,
              to: l.toName,
              line: l.line,
              operator: l.operator,
              departAt: toOffsetIso(l.startMs, c.airport.tz),
              arriveAt: toOffsetIso(l.endMs, ctx.to.tz),
              walkBeforeMin: l.walkBeforeMin,
            })),
            access: c.ground.access,
            fare: {
              amount: money(c.ground.fareEur),
              currency: ctx.query.currency,
              source: c.ground.fareSource,
            },
          }
        : undefined,
      total: {
        price: money(c.totalEur),
        doorToDoorMin: c.doorToDoorMin,
        // Konaklama hariç yolda geçen süre.
        travelMin: c.doorToDoorMin - c.stayMin,
        extraMin: c.extraMin,
        savings: c.savingsEur === null ? null : money(c.savingsEur),
      },
      stopover:
        c.stopoverDays > 0
          ? { days: c.stopoverDays, city: airportCity(c.airport) }
          : undefined,
      score: Math.round(c.score * 100) / 100,
      flags: [...c.flags],
      booking: bookingLinks(c, ctx.query.date, ctx.to),
    })),
    dropped: ctx.dropped,
    warnings: ctx.warnings,
    attribution: attributionFor(lang),
    meta: { generatedAt: new Date(ctx.now).toISOString(), sample: false },
  };
}

export type SearchResponse = ReturnType<typeof toResponse>;
