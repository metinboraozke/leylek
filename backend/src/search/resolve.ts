import type { AirportIndex } from '../data/airport-index.js';
import type { Place, PlaceIndex } from '../data/place-index.js';
import type { Geocoder } from './ports.js';

/**
 * 01 · Yerleri çöz.
 *
 * Önce yerel dizin (kimlik, IATA kodu ya da ad). Bulunamazsa Transitous
 * geocode; sonucu 30 gün önbellekte (istemci tarafında). Bu yol nadir
 * olmalı: otomatik tamamlama zaten yerel dizinden kimlik gönderiyor.
 */
export async function resolvePlace(
  input: string,
  places: PlaceIndex,
  airports: AirportIndex,
  geocoder: Geocoder,
): Promise<Place | null> {
  const local = places.resolve(input);
  if (local) return local;

  const geo = await geocoder.geocode(input.trim()).catch(() => null);
  if (!geo) return null;
  const nearest = airports.within(geo, 400)[0];
  return {
    id: `geo:${geo.lat.toFixed(4)},${geo.lon.toFixed(4)}`,
    name: geo.name,
    country: geo.country.toUpperCase(),
    kind: 'CITY',
    lat: geo.lat,
    lon: geo.lon,
    iata: null,
    tz: nearest?.airport.tz ?? 'UTC',
    population: 0,
  };
}
