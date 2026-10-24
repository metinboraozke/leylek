import type { LatLon } from '../core/geo.js';

/** Tarifeli seferi olan, IATA kodlu havalimanı (OurAirports). */
export interface Airport extends LatLon {
  iata: string;
  name: string;
  country: string;
  municipality: string;
  size: 'large' | 'medium';
  /** Travelpayouts şehir kodu (MXP → MIL). Bilinmiyorsa havalimanı kodu. */
  cityCode: string;
  /** En yakın GeoNames şehrinin saat dilimi. */
  tz: string;
}

/** Nüfusu 15.000'den büyük şehir (GeoNames cities15000). */
export interface City extends LatLon {
  id: string;
  name: string;
  country: string;
  population: number;
  tz: string;
  /** Aramada kullanılan sadeleştirilmiş adlar (asıl ad + alternatifler). */
  keys: string[];
}

export interface Dataset {
  airports: Airport[];
  cities: City[];
  generatedAt: string;
}
