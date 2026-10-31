import { normalize } from '../core/text.js';
import { haversineKm, type LatLon } from '../core/geo.js';
import type { AirportIndex } from './airport-index.js';
import { COUNTRY_ALIASES, countryNameEn, countryNameTr, DATA_COUNTRIES, TURKISH_CITY_NAMES } from './regions.js';
import type { Airport, City } from './types.js';

export interface Place extends LatLon {
  /** `city:<geonameid>`, `airport:<IATA>` ya da `country:<ISO>`. */
  id: string;
  name: string;
  country: string;
  kind: PlaceKind;
  /** Şehir için en yakın havalimanının şehir kodu, havalimanı için kendi kodu. */
  iata: string | null;
  tz: string;
  population: number;
}

export type PlaceKind = 'CITY' | 'AIRPORT' | 'COUNTRY';

export interface PlaceSuggestion {
  id: string;
  name: string;
  countryCode: string;
  countryName: string;
  kind: PlaceKind;
  iata: string | null;
}

interface Entry {
  place: Place;
  /** Asıl ad(lar): önekle eşleşmesi alternatif addan önce gelir. */
  primary: string[];
  keys: string[];
}

/** Ülke önerileri aynı türden eşleşmede şehirlerin önünde durur. */
const COUNTRY_BONUS = 0.5;

/**
 * Yerel yer dizini: otomatik tamamlama ve arama girdisini çözme.
 * Dış istek atmaz. Transitous geocode yalnızca bu dizin bulamazsa
 * çağrılır (bkz. search/resolve.ts).
 */
export class PlaceIndex {
  private readonly entries: Entry[];
  private readonly byId = new Map<string, Place>();

  constructor(cities: readonly City[], private readonly airports: AirportIndex) {
    this.entries = cities.map((c) => {
      const nearest = airports.within(c, 50)[0];
      // Veri dosyası eski bir sürümle üretildiyse Türkçe ad burada da uygulanır.
      const name = TURKISH_CITY_NAMES[`${c.name}|${c.country}`] ?? c.name;
      const place: Place = {
        id: `city:${c.id}`,
        name,
        country: c.country,
        kind: 'CITY',
        lat: c.lat,
        lon: c.lon,
        iata: nearest?.airport.cityCode ?? null,
        tz: c.tz,
        population: c.population,
      };
      this.byId.set(place.id, place);
      const primary = [...new Set([c.keys[0] ?? '', normalize(name)])].filter(Boolean);
      return { place, primary, keys: [...new Set([...primary, ...c.keys])] };
    });

    for (const a of airports.airports) {
      // Ad yalnızca şehir ("İstanbul"); kod ayrı alanda, uygulama yanına yazar.
      const place: Place = {
        id: `airport:${a.iata}`,
        name: this.cityForAirport(a)?.name ?? (a.municipality || a.name),
        country: a.country,
        kind: 'AIRPORT',
        lat: a.lat,
        lon: a.lon,
        iata: a.iata,
        tz: a.tz,
        population: 0,
      };
      this.byId.set(place.id, place);
      const keys = [a.iata.toLowerCase(), normalize(a.name)];
      this.entries.push({ place, primary: keys, keys });
    }

    for (const code of DATA_COUNTRIES) {
      const place = countryPlace(code, airports.inCountry(code));
      if (!place) continue;
      this.byId.set(place.id, place);
      const primary = [
        ...new Set([place.name, countryNameEn(code), ...(COUNTRY_ALIASES[code] ?? [])].map(normalize)),
      ];
      this.entries.push({ place, primary, keys: primary });
    }
  }

  get size(): number {
    return this.entries.length;
  }

  byPlaceId(id: string): Place | undefined {
    return this.byId.get(id);
  }

  /**
   * Öneki eşleşen yerler. Sıra: tam eşleşme, asıl adın öneki, alternatif
   * adın öneki; eşitlikte ülke önce, sonra nüfus. Alternatif adlar geride
   * kalır: "istan" yazınca eski adı "Istanos" olan Korkuteli değil
   * İstanbul gelir. Büyük şehrin semtleri ("Amsterdam-Zuid") atlanır.
   */
  search(query: string, limit = 8): Place[] {
    const q = normalize(query);
    if (q.length < 2) return [];
    const scored: { place: Place; rank: number }[] = [];
    for (const { place, primary, keys } of this.entries) {
      let rank = 0;
      if (primary.includes(q)) rank = 4;
      else if (keys.includes(q)) rank = 3;
      else if (primary.some((k) => k.startsWith(q))) rank = 2;
      else if (keys.some((k) => k.startsWith(q))) rank = 1;
      if (rank === 0) continue;
      // Üç harfli kod tam eşleşirse havalimanı şehirden önce gelsin.
      if (rank === 4 && place.kind === 'AIRPORT' && q.length === 3) rank = 5;
      if (place.kind === 'COUNTRY') rank += COUNTRY_BONUS;
      scored.push({ place, rank });
    }
    scored.sort((a, b) => b.rank - a.rank || b.place.population - a.place.population);

    const out: Place[] = [];
    for (const { place } of scored) {
      if (out.length >= limit) break;
      if (place.kind === 'CITY' && out.some((p) => isDistrictOf(place, p))) continue;
      out.push(place);
    }
    return out;
  }

  /**
   * Bir ülkenin havalimanı şehir kodları, hizmet ettikleri şehrin
   * nüfusuna göre büyükten küçüğe (büyük havalimanları önce).
   * Türkiye → IST, ANK, IZM...; İtalya → ROM, MIL, NAP...
   */
  countryCityCodes(country: string, max: number): string[] {
    const best = new Map<string, number>();
    for (const a of this.airports.inCountry(country)) {
      // Belediyesi küçük olan ana havalimanları (Schiphol → Haarlemmermeer)
      // yakındaki büyük şehirle tartılır.
      const city = Math.max(this.cityForAirport(a)?.population ?? 0, this.cityNear(a, 30)?.population ?? 0);
      const people = city * (a.size === 'large' ? 1 : 0.25);
      best.set(a.cityCode, Math.max(best.get(a.cityCode) ?? 0, people));
    }
    return [...best.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, max)
      .map(([code]) => code);
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
    return this.cityNear(point, radiusKm)?.name ?? null;
  }

  /**
   * Havalimanının hizmet ettiği şehir.
   *
   * Önce OurAirports'taki belediye adı (40 km içinde aynı adlı şehir varsa):
   * Memmingen havalimanı "Memmingen", Ulm değil. Belediye küçük bir
   * kasabaysa (MXP → "Ferno") yakındaki en kalabalık şehre düşülür: Milano.
   */
  cityForAirport(airport: Airport): Place | null {
    const parts = airport.municipality
      .split(',')
      .map((p) => normalize(p.replace(/\(.*?\)/g, '')))
      .filter((p) => p.length > 0);
    let best: Place | null = null;
    for (const { place, keys } of this.entries) {
      if (place.kind !== 'CITY' || !parts.some((p) => keys.includes(p))) continue;
      if (haversineKm(airport, place) > 40) continue;
      if (!best || place.population > best.population) best = place;
    }
    return best ?? this.cityNear(airport);
  }

  /** Havalimanı kodunun şehri ("SAW" → "İstanbul"); bilinmiyorsa null. */
  cityNameForIata(iata: string): string | null {
    const a = this.airports.get(iata);
    return a ? (this.cityForAirport(a)?.name ?? a.municipality) : null;
  }

  /** Yakındaki en kalabalık şehir (havalimanının hizmet ettiği şehir). */
  cityNear(point: LatLon, radiusKm = 60): Place | null {
    let best: Place | null = null;
    for (const { place } of this.entries) {
      if (place.kind !== 'CITY') continue;
      if (Math.abs(place.lat - point.lat) > 1 || Math.abs(place.lon - point.lon) > 1.5) continue;
      if (haversineKm(point, place) > radiusKm) continue;
      if (!best || place.population > best.population) best = place;
    }
    return best;
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

/** Ülke: ad Türkçe, nokta büyük havalimanlarının ortası. */
function countryPlace(code: string, airports: readonly Airport[]): Place | null {
  if (airports.length === 0) return null;
  const main = airports.filter((a) => a.size === 'large');
  const pts = main.length > 0 ? main : airports;
  return {
    id: `country:${code}`,
    name: countryNameTr(code),
    country: code,
    kind: 'COUNTRY',
    lat: pts.reduce((sum, a) => sum + a.lat, 0) / pts.length,
    lon: pts.reduce((sum, a) => sum + a.lon, 0) / pts.length,
    iata: null,
    tz: pts[0]!.tz,
    // Aynı türden eşleşmede şehirlerin önüne geçsin.
    population: Number.MAX_SAFE_INTEGER,
  };
}

/** "Amsterdam-Zuid", listede zaten olan "Amsterdam"ın semti mi? */
function isDistrictOf(place: Place, other: Place): boolean {
  if (other.kind !== 'CITY' || other.iata !== place.iata) return false;
  return normalize(place.name).startsWith(`${normalize(other.name)} `);
}
