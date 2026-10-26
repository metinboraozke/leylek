import type { Airport } from '../data/types.js';
import type { FlightQuote, GroundLegData } from './ports.js';

export interface SearchQuery {
  from: string;
  to: string;
  /** `YYYY-MM-DD`, kalkış yerinin yerel günü. */
  date: string;
  radiusKm: number;
  maxGroundHours: number;
  currency: 'TRY' | 'EUR';
  /** Aktarma şehrinde kaç gün kalınacak (0–3). */
  stopoverDays: number;
}

/**
 * Algoritmanın sabitleri. Plan belgesindeki değerlerle aynı; testler
 * bu değerlere göre yazıldı, değiştirilirse testler de güncellenmeli.
 */
export const PARAMS = {
  /** D'ye bu kadar yakın havalimanları "doğrudan" sayılır. */
  directRadiusKm: 40,
  /** Kalkış şehrinin havalimanları bu yarıçapta aranır. */
  originRadiusKm: 80,
  maxCandidateCodes: 12,
  /** Transitous'a gidecek en fazla aday (arama başına istek sınırı). */
  topK: 5,
  roadFactor: 1.3,
  avgSpeedKmh: 75,
  /** Havalimanından çıkış ve ilk sefere ulaşma payı. */
  egressHours: 0.75,
  /** Saat başı zaman değeri (EUR). */
  vot: 12,
  minCards: 3,
  /** Sonuç ekranı en fazla 4 slayt gösterir; hedef her zaman 4 plan. */
  maxCards: 4,
  /** Konaklamalı rotada kara bacağının en erken kalkış saati (yerel). */
  stopoverDepartHour: 9,
  maxStopoverDays: 3,
  /** Doğrudan uçuşta havalimanından şehre ulaşım tahmini. */
  directGroundMin: 45,
  tightConnectionMin: 120,
  /** Gece inişinde sabahki ilk sefere kadar bekleme payı. */
  overnightAllowanceMin: 480,
  staleHours: 36,
  penalties: { overnight: 25, extraTransfer: 8, estimatedShare: 0.15, tight: 20 },
} as const;

export type Flag =
  | 'SEPARATE_TICKETS'
  | 'TIGHT_CONNECTION'
  | 'OVERNIGHT_WAIT'
  | 'GROUND_FARE_ESTIMATED'
  | 'GROUND_FARE_PARTIAL'
  | 'GROUND_NOT_VERIFIED'
  | 'FERRY'
  | 'PRICE_STALE'
  | 'STOPOVER';

export type DropReason =
  | 'NO_FLIGHT_DATA'
  | 'GROUND_TOO_LONG'
  | 'NOT_IN_TOP_K'
  | 'NO_GROUND_CONNECTION';

export interface Dropped {
  iata: string;
  reason: DropReason;
}

/** Bir havalimanına giden uçuş seçenekleri. */
export interface AirportFlights {
  airport: Airport;
  distanceKm: number;
  cheapest: FlightQuote;
  earliest: FlightQuote;
}

/** Ağ isteği atmadan yapılan kara bacağı tahmini. */
export interface GroundEstimate {
  roadKm: number;
  hours: number;
  costEur: number;
}

export interface Candidate extends AirportFlights {
  estimate: GroundEstimate;
  /** Eleme sırası için kaba puan. */
  estimateScore: number;
}

export interface CardGround {
  departMs: number;
  arriveMs: number;
  waitMin: number;
  transfers: number;
  legs: GroundLegData[];
  fareEur: number;
  fareSource: 'transitous' | 'partial' | 'estimated';
  /** Tahmine dayanan kısım (EUR). */
  estimatedEur: number;
  verified: boolean;
}

export interface Card {
  kind: 'VIA' | 'DIRECT';
  airport: Airport;
  distanceKm: number;
  flight: FlightQuote;
  ground: CardGround | null;
  totalEur: number;
  doorToDoorMin: number;
  /** Sıralamadan sonra dolar. */
  extraMin: number;
  score: number;
  flags: Set<Flag>;
  /** Aktarma şehrinde kalınan gün; 0 ise konaklama yok. */
  stopoverDays: number;
  /** Bilerek geçirilen konaklama süresi (dk); süre karşılaştırmasından düşülür. */
  stayMin: number;
}

export type Badge = 'CHEAPEST' | 'FASTEST' | 'RECOMMENDED';
export type Reason = 'CHEAPEST' | 'BEST_BALANCE' | 'FASTEST';

export interface RankedCard extends Card {
  rank: number;
  badges: Badge[];
  reason: Reason | null;
  savingsEur: number | null;
}
