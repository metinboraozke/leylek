import { toOffsetIso } from '../core/time.js';
import type { Place, PlaceIndex } from '../data/place-index.js';
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

export function toResponse(ctx: ResponseContext) {
  const money = (eur: number) => Math.round(eur * ctx.rate);
  const recommended = ctx.cards.find((c) => c.badges.includes('RECOMMENDED'));

  return {
    query: {
      from: ctx.from.name,
      to: ctx.to.name,
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
              name: ctx.places.cityForAirport(c.airport)?.name ?? c.airport.municipality,
              country: c.airport.country,
              distanceKm: Math.round(c.distanceKm),
            }
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
            })),
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
          ? { days: c.stopoverDays, city: ctx.places.cityForAirport(c.airport)?.name ?? c.airport.municipality }
          : undefined,
      score: Math.round(c.score * 100) / 100,
      flags: [...c.flags],
      booking: bookingLinks(c, ctx.query.date),
    })),
    dropped: ctx.dropped,
    warnings: ctx.warnings,
    attribution: ATTRIBUTION,
    meta: { generatedAt: new Date(ctx.now).toISOString(), sample: false },
  };
}

export type SearchResponse = ReturnType<typeof toResponse>;
