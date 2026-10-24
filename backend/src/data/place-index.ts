import { normalize } from '../core/text.js';
import { haversineKm, type LatLon } from '../core/geo.js';
import type { AirportIndex } from './airport-index.js';
import { countryNameTr } from './regions.js';
import type { City } from './types.js';

export interface Place extends LatLon {
  /** `city:<geonameid>` ya da `airport:<IATA>`. */
  id: string;
  name: string;
  country: string;
  kind: 'CITY' | 'AIRPORT';
  /** Şehir için en yakın havalimanının şehir kodu, havalimanı için kendi kodu. */
  iata: string | null;
  tz: string;
  population: number;
}

export interface PlaceSuggestion {
  id: string;
  name: string;
  countryCode: string;
  countryName: string;
  kind: 'CITY' | 'AIRPORT';
  iata: string | null;
}

/**
 * Yerel yer dizini: otomatik tamamlama ve arama girdisini çözme.
 * Dış istek atmaz. Transitous geocode yalnızca bu dizin bulamazsa
 * çağrılır (bkz. search/resolve.ts).
 */
export class PlaceIndex {
  private readonly entries: { place: Place; keys: string[] }[];
  private readonly byId = new Map<string, Place>();

  constructor(cities: readonly City[], private readonly airports: AirportIndex) {
    this.entries = cities.map((c) => {
      const nearest = airports.within(c, 50)[0];
      const place: Place = {
        id: `city:${c.id}`,
        name: c.name,
        country: c.country,
        kind: 'CITY',
        lat: c.lat,
        lon: c.lon,
        iata: nearest?.airport.cityCode ?? null,
        tz: c.tz,
        population: c.population,
      };
      this.byId.set(place.id, place);
      return { place, keys: c.keys };
    });

    for (const a of airports.airports) {
      const place: Place = {
        id: `airport:${a.iata}`,
        name: a.municipality ? `${a.municipality} ${a.iata}` : a.name,
        country: a.country,
        kind: 'AIRPORT',
        lat: a.lat,
        lon: a.lon,
        iata: a.iata,
        tz: a.tz,
        population: 0,
      };
      this.byId.set(place.id, place);
      this.entries.push({ place, keys: [a.iata.toLowerCase(), normalize(a.name)] });
    }
  }

  get size(): number {
    return this.entries.length;
  }

  byPlaceId(id: string): Place | undefined {
    return this.byId.get(id);
  }

  /** Öneki eşleşen yerler: tam eşleşme önce, sonra nüfus. */
  search(query: string, limit = 8): Place[] {
    const q = normalize(query);
    if (q.length < 2) return [];
    const scored: { place: Place; rank: number }[] = [];
    for (const { place, keys } of this.entries) {
      let rank = -1;
      for (const key of keys) {
        if (key === q) {
          rank = 2;
          break;
        }
        if (key.startsWith(q)) rank = 1;
      }
      // Üç harfli kod tam eşleşirse havalimanı şehirden önce gelsin.
      if (rank === 2 && place.kind === 'AIRPORT' && q.length === 3) rank = 3;
      if (rank > 0) scored.push({ place, rank });
    }
    return scored
      .sort((a, b) => b.rank - a.rank || b.place.population - a.place.population)
      .slice(0, limit)
      .map((s) => s.place);
  }

  /** Arama girdisini (kimlik, IATA ya da ad) bir yere çevirir. */
  resolve(input: string): Place | undefined {
    const trimmed = input.trim();
    const byId = this.byId.get(trimmed);
    if (byId) return byId;
    if (/^[A-Za-z]{3}$/.test(trimmed)) {
      const airport = this.byId.get(`airport:${trimmed.toUpperCase()}`);
      if (airport) return airport;
      const inCity = this.airports.inCity(trimmed)[0];
      if (inCity) return this.byId.get(`airport:${inCity.iata}`);
    }
    return this.search(trimmed, 1)[0];
  }

  /**
   * Bir havalimanının kartta görünecek şehir adı: yakındaki en kalabalık
   * şehir. MXP'nin belediyesi "Ferno"; kullanıcı "Milano" görmeli.
   */
  cityNameNear(point: LatLon, radiusKm = 60): string | null {
    let best: Place | null = null;
    for (const { place } of this.entries) {
      if (place.kind !== 'CITY') continue;
      if (Math.abs(place.lat - point.lat) > 1 || Math.abs(place.lon - point.lon) > 1.5) continue;
      if (haversineKm(point, place) > radiusKm) continue;
      if (!best || place.population > best.population) best = place;
    }
    return best?.name ?? null;
  }

  static toSuggestion(place: Place): PlaceSuggestion {
    return {
      id: place.id,
      name: place.name,
      countryCode: place.country,
      countryName: countryNameTr(place.country),
      kind: place.kind,
      iata: place.iata,
    };
  }
}
