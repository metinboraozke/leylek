import { haversineKm } from '../../core/geo.js';
import { normalize } from '../../core/text.js';
import { DATA_COUNTRIES, TURKISH_CITY_NAMES } from '../regions.js';
import type { Airport, City } from '../types.js';

/**
 * Ham veri dosyalarını dizin kayıtlarına çeviren saf fonksiyonlar.
 * İndirme `scripts/import-data.ts`'te; burası ağ bilmez, test edilir.
 */

/** RFC 4180 CSV: tırnak içindeki virgül ve çift tırnak desteklenir. */
export function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = '';
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i++;
        } else {
          quoted = false;
        }
      } else {
        field += c;
      }
    } else if (c === '"') {
      quoted = true;
    } else if (c === ',') {
      row.push(field);
      field = '';
    } else if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(field);
      rows.push(row);
      row = [];
      field = '';
    } else {
      field += c;
    }
  }
  if (field.length > 0 || row.length > 0) {
    row.push(field);
    rows.push(row);
  }
  return rows;
}

export interface RawAirport {
  iata: string;
  name: string;
  lat: number;
  lon: number;
  country: string;
  municipality: string;
  size: 'large' | 'medium';
}

/**
 * OurAirports `airports.csv`: IATA kodu olan, tarifeli seferi bulunan,
 * büyük ya da orta boy havalimanları; yalnızca veri ülkeleri.
 */
export function parseOurAirports(csv: string): RawAirport[] {
  const [header, ...rows] = parseCsv(csv);
  if (!header) return [];
  const col = (name: string) => {
    const i = header.indexOf(name);
    if (i === -1) throw new Error(`airports.csv içinde "${name}" sütunu yok`);
    return i;
  };
  const c = {
    type: col('type'),
    name: col('name'),
    lat: col('latitude_deg'),
    lon: col('longitude_deg'),
    country: col('iso_country'),
    municipality: col('municipality'),
    scheduled: col('scheduled_service'),
    iata: col('iata_code'),
  };

  const out: RawAirport[] = [];
  for (const r of rows) {
    const type = r[c.type];
    const iata = (r[c.iata] ?? '').trim().toUpperCase();
    const country = r[c.country] ?? '';
    if (type !== 'large_airport' && type !== 'medium_airport') continue;
    if (r[c.scheduled] !== 'yes' || !/^[A-Z]{3}$/.test(iata)) continue;
    if (!DATA_COUNTRIES.has(country)) continue;
    const lat = Number(r[c.lat]);
    const lon = Number(r[c.lon]);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;
    out.push({
      iata,
      name: r[c.name] ?? iata,
      lat,
      lon,
      country,
      municipality: r[c.municipality] ?? '',
      size: type === 'large_airport' ? 'large' : 'medium',
    });
  }
  return out;
}

/** Travelpayouts `airports.json`: havalimanı kodu → şehir kodu. */
export function parseCityCodes(json: unknown): Map<string, string> {
  const map = new Map<string, string>();
  if (!Array.isArray(json)) return map;
  for (const item of json) {
    if (item && typeof item === 'object') {
      const { code, city_code: cityCode } = item as { code?: unknown; city_code?: unknown };
      if (typeof code === 'string' && typeof cityCode === 'string' && cityCode.length === 3) {
        map.set(code.toUpperCase(), cityCode.toUpperCase());
      }
    }
  }
  return map;
}

const LATIN = /^[a-z0-9 ]+$/;
const MAX_ALT_KEYS = 80;

/**
 * GeoNames `cities15000.txt` (sekme ayrımlı). Sütunlar:
 * 0 id, 1 ad, 2 ascii ad, 3 alternatif adlar, 4 enlem, 5 boylam,
 * 8 ülke, 14 nüfus, 17 saat dilimi.
 */
export function parseGeoNames(tsv: string): City[] {
  const cities: City[] = [];
  for (const line of tsv.split('\n')) {
    const f = line.split('\t');
    if (f.length < 18) continue;
    const country = f[8] ?? '';
    if (!DATA_COUNTRIES.has(country)) continue;
    const lat = Number(f[4]);
    const lon = Number(f[5]);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;

    const englishName = f[1] ?? '';
    const name = TURKISH_CITY_NAMES[`${englishName}|${country}`] ?? englishName;
    const keys = new Set<string>([normalize(name), normalize(englishName), normalize(f[2] ?? '')]);
    for (const alt of (f[3] ?? '').split(',')) {
      if (keys.size >= MAX_ALT_KEYS) break;
      const key = normalize(alt);
      // Latin dışı yazılar ve kodlar (ör. "MUC") anahtar olmaz.
      if (key.length >= 3 && LATIN.test(key) && !/^[a-z]{3}$/.test(alt.trim().toLowerCase())) {
        keys.add(key);
      }
    }
    keys.delete('');

    cities.push({
      id: f[0] ?? '',
      name,
      country,
      lat,
      lon,
      population: Number(f[14]) || 0,
      tz: f[17]?.trim() || 'UTC',
      keys: [...keys],
    });
  }
  return cities;
}

/** Ham havalimanlarına şehir kodu ve (en yakın şehirden) saat dilimi ekler. */
export function enrichAirports(
  raw: RawAirport[],
  cityCodes: Map<string, string>,
  cities: City[],
): Airport[] {
  return raw.map((a) => {
    let tz = 'UTC';
    let best = Infinity;
    for (const c of cities) {
      if (Math.abs(c.lat - a.lat) > 2 || Math.abs(c.lon - a.lon) > 3) continue;
      const d = haversineKm(a, c);
      if (d < best) {
        best = d;
        tz = c.tz;
      }
    }
    return { ...a, cityCode: cityCodes.get(a.iata) ?? a.iata, tz };
  });
}
