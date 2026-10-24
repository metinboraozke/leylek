import type { AirportHit, AirportIndex } from '../data/airport-index.js';
import type { Place } from '../data/place-index.js';
import { PARAMS } from './types.js';

export interface CandidateSet {
  /** D'ye çok yakın havalimanları: doğrudan uçuş karşılaştırması. */
  direct: AirportHit[];
  /** Aktarmalı rota için aday havalimanları. */
  candidates: AirportHit[];
  /** Travelpayouts'a sorulacak şehir kodları (doğrudan + aday). */
  destCodes: string[];
}

/**
 * 02 · Aday havalimanlarını bul. Dış istek yok.
 *
 *   • Doğrudan grubu: D'ye 40 km içinde ya da D ile aynı şehir koduna bağlı.
 *   • Adaylar: R km içindeki diğerleri. Türkiye'deki havalimanları aday
 *     olamaz (kara bacağı Türkiye içinde kalırdı) ve kalkış şehrinin
 *     kendi kodu aday olmaz.
 *   • Adaylar şehir koduna toplanır (MXP, LIN, BGY → MIL); en fazla 12 kod,
 *     önce büyük havalimanları, sonra yakın olanlar.
 */
export function findCandidates(
  destination: Place,
  radiusKm: number,
  airports: AirportIndex,
  originCodes: string[],
): CandidateSet {
  const hits = airports.within(destination, radiusKm);
  const directCodes = new Set<string>();
  if (destination.kind === 'AIRPORT' && destination.iata) {
    const a = airports.get(destination.iata);
    if (a) directCodes.add(a.cityCode);
  }

  const direct: AirportHit[] = [];
  const rest: AirportHit[] = [];
  for (const hit of hits) {
    if (hit.distanceKm <= PARAMS.directRadiusKm || directCodes.has(hit.airport.cityCode)) {
      direct.push(hit);
      directCodes.add(hit.airport.cityCode);
    } else {
      rest.push(hit);
    }
  }

  const candidates = rest
    .filter((h) => h.airport.country !== 'TR' && !originCodes.includes(h.airport.cityCode))
    .filter((h) => !directCodes.has(h.airport.cityCode));

  const ordered = [...candidates].sort(
    (a, b) =>
      (a.airport.size === 'large' ? 0 : 1) - (b.airport.size === 'large' ? 0 : 1) ||
      a.distanceKm - b.distanceKm,
  );
  const candidateCodes: string[] = [];
  for (const h of ordered) {
    if (candidateCodes.length >= PARAMS.maxCandidateCodes) break;
    if (!candidateCodes.includes(h.airport.cityCode)) candidateCodes.push(h.airport.cityCode);
  }

  return {
    direct,
    candidates: candidates.filter((h) => candidateCodes.includes(h.airport.cityCode)),
    destCodes: [...directCodes, ...candidateCodes],
  };
}
