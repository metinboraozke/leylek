import { boundingBox, haversineKm, inBox, type LatLon } from '../core/geo.js';
import type { Airport } from './types.js';

export interface AirportHit {
  airport: Airport;
  distanceKm: number;
}

/**
 * Havalimanı dizini. ~2.000 kayıt bellekte düz bir dizi; önce sınır
 * kutusuyla kaba eleme, sonra haversine. Bu boyutta mekânsal indeks
 * gerekmiyor, tek arama milisaniyenin altında.
 */
export class AirportIndex {
  private readonly byIata = new Map<string, Airport>();
  private readonly byCity = new Map<string, Airport[]>();

  constructor(readonly airports: readonly Airport[]) {
    for (const a of airports) {
      this.byIata.set(a.iata, a);
      const list = this.byCity.get(a.cityCode) ?? [];
      list.push(a);
      this.byCity.set(a.cityCode, list);
    }
  }

  get(iata: string): Airport | undefined {
    return this.byIata.get(iata.toUpperCase());
  }

  inCity(cityCode: string): Airport[] {
    return this.byCity.get(cityCode.toUpperCase()) ?? [];
  }

  /** Yarıçap içindeki havalimanları, yakından uzağa. */
  within(center: LatLon, radiusKm: number): AirportHit[] {
    const box = boundingBox(center, radiusKm);
    const hits: AirportHit[] = [];
    for (const airport of this.airports) {
      if (!inBox(airport, box)) continue;
      const distanceKm = haversineKm(center, airport);
      if (distanceKm <= radiusKm) hits.push({ airport, distanceKm });
    }
    return hits.sort((a, b) => a.distanceKm - b.distanceKm);
  }

  /**
   * Bir noktanın kalkış şehir kodları: yakındaki büyük havalimanları
   * önce. İstanbul için IST (IST ve SAW aynı koda bağlı).
   */
  originCityCodes(center: LatLon, radiusKm = 80, max = 2): string[] {
    const hits = this.within(center, radiusKm).sort(
      (a, b) =>
        (a.airport.size === 'large' ? 0 : 1) - (b.airport.size === 'large' ? 0 : 1) ||
        a.distanceKm - b.distanceKm,
    );
    const codes: string[] = [];
    for (const { airport } of hits) {
      if (!codes.includes(airport.cityCode)) codes.push(airport.cityCode);
      if (codes.length >= max) break;
    }
    return codes;
  }
}
