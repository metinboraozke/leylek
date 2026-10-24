export interface LatLon {
  lat: number;
  lon: number;
}

const EARTH_RADIUS_KM = 6371;
const KM_PER_DEGREE_LAT = 111.32;

const toRad = (deg: number) => (deg * Math.PI) / 180;

/** İki nokta arasındaki kuş uçuşu mesafe (km). */
export function haversineKm(a: LatLon, b: LatLon): number {
  const dLat = toRad(b.lat - a.lat);
  const dLon = toRad(b.lon - a.lon);
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.min(1, Math.sqrt(h)));
}

/**
 * Merkezi ve yarıçapı verilen dairenin enlem/boylam sınır kutusu.
 * Haversine'den önce kaba eleme için: boylam derecesi enleme göre daralır.
 */
export function boundingBox(center: LatLon, radiusKm: number) {
  const dLat = radiusKm / KM_PER_DEGREE_LAT;
  const cos = Math.max(0.01, Math.cos(toRad(center.lat)));
  const dLon = radiusKm / (KM_PER_DEGREE_LAT * cos);
  return {
    minLat: center.lat - dLat,
    maxLat: center.lat + dLat,
    minLon: center.lon - dLon,
    maxLon: center.lon + dLon,
  };
}

export function inBox(p: LatLon, box: ReturnType<typeof boundingBox>): boolean {
  return p.lat >= box.minLat && p.lat <= box.maxLat && p.lon >= box.minLon && p.lon <= box.maxLon;
}

/** Önbellek anahtarı için koordinatı 3 ondalığa (~100 m) yuvarlar. */
export function coordKey(p: LatLon): string {
  return `${p.lat.toFixed(3)},${p.lon.toFixed(3)}`;
}
