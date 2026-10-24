import type { AirportHit } from '../data/airport-index.js';
import { Errors } from '../core/errors.js';
import type { FlightPriceSource, FlightQuote } from './ports.js';
import type { AirportFlights } from './types.js';

const CONCURRENCY = 4;

/** Görevleri en fazla `limit` tanesi aynı anda çalışacak şekilde yürütür. */
export async function mapLimit<T, R>(items: T[], limit: number, fn: (item: T) => Promise<R>): Promise<R[]> {
  const results: R[] = new Array(items.length);
  let next = 0;
  async function worker() {
    while (next < items.length) {
      const i = next++;
      results[i] = await fn(items[i] as T);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}

/**
 * 03 · Uçuş fiyatlarını çek.
 *
 * Her kalkış kodu × varış kodu için bir istek (önbellekli, en fazla 4
 * aynı anda). Tek tek başarısız olan istekler atlanır; hiçbiri cevap
 * vermezse arama 503 ile biter.
 */
export async function fetchQuotes(
  source: FlightPriceSource,
  originCodes: string[],
  destCodes: string[],
  day: string,
): Promise<FlightQuote[]> {
  const pairs = originCodes.flatMap((o) => destCodes.map((d) => [o, d] as const));
  let failures = 0;
  const lists = await mapLimit(pairs, CONCURRENCY, async ([o, d]) => {
    try {
      return await source.quotes(o, d, day);
    } catch {
      failures++;
      return [];
    }
  });
  if (pairs.length > 0 && failures === pairs.length) throw Errors.flightsUnavailable();
  return lists.flat();
}

/**
 * Uçuşları iniş havalimanına göre toplar. Her havalimanı için iki uçuş
 * tutulur: en ucuz ve en erken inen (kara bacağına daha çok zaman bırakır).
 */
export function groupByAirport(quotes: FlightQuote[], hits: AirportHit[]): AirportFlights[] {
  const out: AirportFlights[] = [];
  for (const hit of hits) {
    const mine = quotes.filter((q) => q.destAirport === hit.airport.iata);
    if (mine.length === 0) continue;
    const cheapest = mine.reduce((a, b) =>
      b.priceEur < a.priceEur || (b.priceEur === a.priceEur && b.arriveMs < a.arriveMs) ? b : a,
    );
    const earliest = mine.reduce((a, b) =>
      b.arriveMs < a.arriveMs || (b.arriveMs === a.arriveMs && b.priceEur < a.priceEur) ? b : a,
    );
    out.push({ airport: hit.airport, distanceKm: hit.distanceKm, cheapest, earliest });
  }
  return out;
}
