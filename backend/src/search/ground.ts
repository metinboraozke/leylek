import { haversineKm, type LatLon } from '../core/geo.js';
import { localTimeOnDay } from '../core/time.js';
import type { AirportIndex } from '../data/airport-index.js';
import type { Airport } from '../data/types.js';
import { SCHENGEN } from '../data/regions.js';
import type { FlightQuote, FxRates, GroundItinerary, GroundRouter, StopLocator } from './ports.js';
import { groundCostRate } from './prefilter.js';
import { PARAMS, type Candidate, type CardGround } from './types.js';

const MINUTE = 60_000;

/**
 * İnişten sonra sınır kontrolü, bagaj ve terminalden çıkış payı (dakika).
 *
 *   90  Schengen dışı → Schengen içi (İstanbul → Münih)
 *   60  Schengen dışı → Schengen dışı (İstanbul → Londra)
 *   45  Schengen içi  → Schengen içi
 *   +15 uçuş aktarmalıysa (rötar payı)
 */
export function bufferMinutes(originCountry: string, destCountry: string, flightTransfers: number): number {
  const fromSchengen = SCHENGEN.has(originCountry);
  const toSchengen = SCHENGEN.has(destCountry);
  let base: number;
  if (fromSchengen && toSchengen) base = 45;
  else if (toSchengen) base = 90;
  else if (fromSchengen) base = 60;
  else base = 60;
  return base + (flightTransfers > 0 ? 15 : 0);
}

/**
 * Önbellek isabeti için 15 dakikalık kovaya YUKARI yuvarlar.
 *
 * Plan aşağı yuvarlama + süzme diyordu; yukarı yuvarlamak tampona en
 * fazla 15 dakika ekler ama süzme gerektirmez: bulunan her yolculuk
 * zaten tampondan sonra kalkar.
 */
export function ceilTo15(ms: number): number {
  const step = 15 * MINUTE;
  return Math.ceil(ms / step) * step;
}

/**
 * Kara bacağının en erken kalkışı.
 *
 *   • Konaklamasız: inişten sonra tampon kadar (15 dakikaya yukarı yuvarlı).
 *   • N gün konaklamalı: inişin yerel gününden N gün sonra sabah 09:00;
 *     yolcu aktarma şehrinde kalıp ertesi sabahlardan biri yola çıkar.
 */
export function earliestGroundDepart(
  flight: FlightQuote,
  airport: { country: string; tz: string },
  originCountry: string,
  stopoverDays: number,
): number {
  if (stopoverDays > 0) {
    return localTimeOnDay(flight.arriveMs, airport.tz, stopoverDays, PARAMS.stopoverDepartHour);
  }
  const buffer = bufferMinutes(originCountry, airport.country, flight.transfers);
  return ceilTo15(flight.arriveMs + buffer * MINUTE);
}

export interface GroundOptions {
  maxGroundHours: number;
  stopoverDays: number;
  /** Varış şehrinin ana istasyonu (bulunduysa). */
  destStopId?: string;
}

export type GroundOutcome =
  | { status: 'verified'; ground: CardGround }
  | { status: 'impossible'; reason: 'NO_GROUND_CONNECTION' | 'GROUND_TOO_LONG' }
  | { status: 'unverified'; ground: CardGround };

/** Yolculuğun EUR fiyatı: bilinen ürünler + fiyatsız bacakların tahmini. */
async function priceItinerary(
  itin: GroundItinerary,
  country: string,
  fx: FxRates,
): Promise<{ fareEur: number; estimatedEur: number; source: CardGround['fareSource'] }> {
  let known = 0;
  for (const f of itin.fares) {
    known += f.amount / (await fx.perEur(f.currency));
  }
  const rate = groundCostRate(country);
  const unpriced = itin.legs.filter((l) => !l.priced);
  const estimated = unpriced.reduce(
    (sum, l) => sum + rate.perKm * haversineKm(l.from, l.to) * PARAMS.roadFactor,
    0,
  );

  if (itin.fares.length === 0) {
    const whole = itin.legs.reduce((s, l) => s + haversineKm(l.from, l.to) * PARAMS.roadFactor, 0);
    const est = rate.base + rate.perKm * whole;
    return { fareEur: est, estimatedEur: est, source: 'estimated' };
  }
  return {
    fareEur: known + estimated,
    estimatedEur: estimated,
    source: unpriced.length === 0 ? 'transitous' : 'partial',
  };
}

/** Tahmine dayalı (doğrulanmamış) kara bacağı. */
export function estimatedGround(candidate: Candidate, flight: FlightQuote, departMs: number): CardGround {
  const durationMs = (candidate.estimate.hours - PARAMS.egressHours) * 60 * MINUTE;
  return {
    departMs,
    arriveMs: departMs + durationMs,
    waitMin: Math.round((departMs - flight.arriveMs) / MINUTE),
    transfers: 0,
    legs: [],
    fareEur: candidate.estimate.costEur,
    estimatedEur: candidate.estimate.costEur,
    fareSource: 'estimated',
    verified: false,
  };
}

/**
 * 05 · Kara bacağını hesapla.
 *
 * Aday başına tek Transitous isteği (önbellekli ve bütçeli yönlendirici
 * üzerinden). Bütçe biterse ya da servis hata verirse aday tahminle kalır
 * ve "doğrulanamadı" etiketi alır. Hiç bağlantı yoksa aday düşer.
 */
export async function computeGround(
  candidate: Candidate,
  destination: LatLon & { country: string },
  options: GroundOptions,
  deps: {
    router: GroundRouter;
    fx: FxRates;
    airports: AirportIndex;
    stops?: StopLocator;
    /** Konaklamalı rotada aktarma şehrinin kendisi (havalimanı değil). */
    cityNear?: (airport: Airport) => (LatLon & { name: string }) | null;
  },
): Promise<GroundOutcome> {
  const { maxGroundHours, stopoverDays } = options;
  const flight = candidate.cheapest;
  const origin = deps.airports.get(flight.originAirport);
  const earliestDepartMs = earliestGroundDepart(
    flight,
    candidate.airport,
    origin?.country ?? 'TR',
    stopoverDays,
  );

  // Kalkış durağı: konaklamasızda havalimanının durağı; konaklamalıda
  // aktarma şehrinin ana istasyonu (yolcu şehirde kalıp oradan çıkar).
  // Bulunamazsa koordinatla denenir. İkisi de 30 gün önbellekli.
  let from: LatLon = candidate.airport;
  let fromStopId: string | undefined;
  if (stopoverDays > 0) {
    const city = deps.cityNear?.(candidate.airport) ?? null;
    if (city) from = city;
    const station = city && deps.stops ? await deps.stops.cityStation(city).catch(() => null) : null;
    fromStopId = station?.id;
  } else {
    const stop = deps.stops ? await deps.stops.nearestStop(candidate.airport).catch(() => null) : null;
    fromStopId = stop?.id;
  }

  let itineraries: GroundItinerary[];
  try {
    itineraries = await deps.router.plan({
      from,
      ...(fromStopId ? { fromStopId } : {}),
      to: destination,
      ...(options.destStopId ? { toStopId: options.destStopId } : {}),
      earliestDepartMs,
      // Konaklamalıda sabah kalkış: gece beklemesi payı gerekmez.
      maxTravelMinutes:
        Math.round(maxGroundHours * 60) + (stopoverDays > 0 ? 120 : PARAMS.overnightAllowanceMin),
    });
  } catch {
    // Bütçe, sigorta ya da servis hatası: aday tahminle kalır.
    return { status: 'unverified', ground: estimatedGround(candidate, flight, earliestDepartMs) };
  }

  let best: { ground: CardGround; score: number } | null = null;
  let tooLong = false;
  for (const itin of itineraries) {
    if (itin.startMs < earliestDepartMs - MINUTE) continue;
    if ((itin.endMs - itin.startMs) / 3_600_000 > maxGroundHours) {
      tooLong = true;
      continue;
    }
    if (itin.legs.length === 0) continue;
    const price = await priceItinerary(itin, destination.country, deps.fx);
    const ground: CardGround = {
      departMs: itin.startMs,
      arriveMs: itin.endMs,
      waitMin: Math.round((itin.startMs - flight.arriveMs) / MINUTE),
      transfers: itin.transfers,
      legs: itin.legs,
      fareEur: price.fareEur,
      estimatedEur: price.estimatedEur,
      fareSource: price.source,
      verified: true,
    };
    // Varışa kadar geçen süre (bekleme dahil) ve fiyat birlikte. Konaklamalı
    // rotada sayaç, bilerek kalınan sabahtan başlar.
    const clockStart = stopoverDays > 0 ? earliestDepartMs : flight.arriveMs;
    const score =
      price.fareEur +
      (PARAMS.vot * (itin.endMs - clockStart)) / 3_600_000 +
      PARAMS.penalties.extraTransfer * Math.max(0, itin.transfers - 1);
    if (!best || score < best.score) best = { ground, score };
  }

  if (best) return { status: 'verified', ground: best.ground };
  // Yolculuk var ama süre sınırını aşıyor (ör. Nürnberg → Salzburg yalnızca
  // 6,5 saatlik otobüs) ile hiç yolculuk yok ayrı raporlanır.
  return { status: 'impossible', reason: tooLong ? 'GROUND_TOO_LONG' : 'NO_GROUND_CONNECTION' };
}
