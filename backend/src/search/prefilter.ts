import { haversineKm, type LatLon } from '../core/geo.js';
import { GROUND_COST } from '../data/regions.js';
import type { FlightQuote } from './ports.js';
import { PARAMS, type AirportFlights, type Candidate, type Dropped, type GroundEstimate } from './types.js';

export function groundCostRate(country: string) {
  return GROUND_COST.byCountry[country] ?? GROUND_COST.default;
}

/** Kuş uçuşu mesafeden kaba kara bacağı tahmini. Ağ isteği yok. */
export function estimateGround(from: LatLon, to: LatLon, country: string): GroundEstimate {
  const roadKm = haversineKm(from, to) * PARAMS.roadFactor;
  const rate = groundCostRate(country);
  return {
    roadKm,
    hours: PARAMS.egressHours + roadKm / PARAMS.avgSpeedKmh,
    costEur: rate.base + rate.perKm * roadKm,
  };
}

const durationHours = (f: FlightQuote) => (f.arriveMs - f.departMs) / 3_600_000;

/**
 * 04 · Ağdan önce ele.
 *
 *   Kural 1: tahmini kara süresi > maxGroundHours → GROUND_TOO_LONG
 *   Kural 2: doğrudandan pahalı görünenler ELENMEZ (ekranda en az 3 rota
 *            olacak); yalnızca sırada geriye düşer.
 *   Kural 3: tahmini puana göre ilk K = 5 aday Transitous'a gider; diğerleri
 *            `reserve` olarak tutulur, gerekirse 06'da boşluk doldurur.
 */
export function prefilter(
  options: AirportFlights[],
  destination: LatLon & { country: string },
  direct: FlightQuote | null,
  maxGroundHours: number,
): { kept: Candidate[]; reserve: Candidate[]; dropped: Dropped[] } {
  const dropped: Dropped[] = [];
  const directHours = direct ? durationHours(direct) + PARAMS.directGroundMin / 60 : null;

  const scored: Candidate[] = [];
  for (const option of options) {
    const estimate = estimateGround(option.airport, destination, destination.country);
    if (estimate.hours > maxGroundHours) {
      dropped.push({ iata: option.airport.iata, reason: 'GROUND_TOO_LONG' });
      continue;
    }
    const total = durationHours(option.cheapest) + estimate.hours;
    const extra = directHours === null ? 0 : Math.max(0, total - directHours);
    scored.push({
      ...option,
      estimate,
      estimateScore: option.cheapest.priceEur + estimate.costEur + PARAMS.vot * extra,
    });
  }

  scored.sort((a, b) => a.estimateScore - b.estimateScore);
  const kept = scored.slice(0, PARAMS.topK);
  const reserve = scored.slice(PARAMS.topK);
  for (const r of reserve) dropped.push({ iata: r.airport.iata, reason: 'NOT_IN_TOP_K' });
  return { kept, reserve, dropped };
}
