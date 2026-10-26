import { overlapsNight } from '../core/time.js';
import type { Airport } from '../data/types.js';
import type { FlightQuote } from './ports.js';
import {
  PARAMS,
  type Badge,
  type Candidate,
  type Card,
  type CardGround,
  type Flag,
  type RankedCard,
  type Reason,
} from './types.js';

const MINUTE = 60_000;

/** Kart için uyarı etiketleri. */
export function flagsFor(
  flight: FlightQuote,
  ground: CardGround | null,
  airport: Airport,
  stopoverDays = 0,
): Set<Flag> {
  const flags = new Set<Flag>();
  if (flight.priceAgeDays !== null && flight.priceAgeDays * 24 > PARAMS.staleHours) flags.add('PRICE_STALE');
  if (!ground) return flags;

  flags.add('SEPARATE_TICKETS');
  if (!ground.verified) flags.add('GROUND_NOT_VERIFIED');
  if (ground.fareSource === 'estimated') flags.add('GROUND_FARE_ESTIMATED');
  if (ground.fareSource === 'partial') flags.add('GROUND_FARE_PARTIAL');
  if (stopoverDays > 0) {
    // Bilerek kalınan gece "gece beklemesi" değil; aktarma da dar değil.
    flags.add('STOPOVER');
  } else {
    if (ground.waitMin < PARAMS.tightConnectionMin) flags.add('TIGHT_CONNECTION');
    if (overlapsNight(flight.arriveMs, ground.departMs, airport.tz)) flags.add('OVERNIGHT_WAIT');
  }
  if (ground.legs.some((l) => l.mode === 'FERRY')) flags.add('FERRY');
  return flags;
}

/** Konaklamalı rotada inişten kara kalkışına kadar geçen, bilerek kalınan süre. */
function stayMinutes(flight: FlightQuote, ground: CardGround, stopoverDays: number): number {
  return stopoverDays > 0 ? Math.max(0, Math.round((ground.departMs - flight.arriveMs) / MINUTE)) : 0;
}

export function viaCard(
  candidate: Candidate,
  flight: FlightQuote,
  ground: CardGround,
  stopoverDays = 0,
): Card {
  return {
    kind: 'VIA',
    airport: candidate.airport,
    distanceKm: candidate.distanceKm,
    flight,
    ground,
    totalEur: flight.priceEur + ground.fareEur,
    doorToDoorMin: Math.round((ground.arriveMs - flight.departMs) / MINUTE),
    extraMin: 0,
    score: 0,
    flags: flagsFor(flight, ground, candidate.airport, stopoverDays),
    stopoverDays,
    stayMin: stayMinutes(flight, ground, stopoverDays),
  };
}

export function directCard(flight: FlightQuote, airport: Airport, distanceKm: number): Card {
  return {
    kind: 'DIRECT',
    airport,
    distanceKm,
    flight,
    ground: null,
    totalEur: flight.priceEur,
    doorToDoorMin: Math.round((flight.arriveMs - flight.departMs) / MINUTE) + PARAMS.directGroundMin,
    extraMin: 0,
    score: 0,
    flags: flagsFor(flight, null, airport),
    stopoverDays: 0,
    stayMin: 0,
  };
}

/**
 * Aynı havalimanının diğer uçuşu için kart: aynı kara yolculuğu, o uçuş
 * kara kalkışından tampon kadar önce iniyorsa kullanılabilir. Ek
 * Transitous isteği gerektirmez.
 */
export function alternateFlightCard(base: Card, other: FlightQuote, bufferMin: number): Card | null {
  const ground = base.ground;
  if (!ground || other === base.flight) return null;
  if (other.arriveMs + bufferMin * MINUTE > ground.departMs) return null;
  const shifted: CardGround = { ...ground, waitMin: Math.round((ground.departMs - other.arriveMs) / MINUTE) };
  return {
    ...base,
    flight: other,
    ground: shifted,
    totalEur: other.priceEur + ground.fareEur,
    doorToDoorMin: Math.round((ground.arriveMs - other.departMs) / MINUTE),
    flags: flagsFor(other, shifted, base.airport, base.stopoverDays),
    stayMin: stayMinutes(other, shifted, base.stopoverDays),
  };
}

/** Puan: fiyat + zaman değeri × fazla süre + cezalar (EUR). */
export function scoreCards(cards: Card[], directDoorToDoorMin: number | null): void {
  // Konaklama süresi bilerek geçirildiği için yolda geçen süreden düşülür;
  // aksi halde 1 günlük konaklama 24 saat "fazla süre" cezası alırdı.
  const travel = (c: Card) => c.doorToDoorMin - c.stayMin;
  const reference = directDoorToDoorMin ?? Math.min(...cards.map(travel));
  for (const card of cards) {
    card.extraMin = Math.max(0, travel(card) - reference);
    const g = card.ground;
    let penalty = 0;
    if (card.flags.has('OVERNIGHT_WAIT')) penalty += PARAMS.penalties.overnight;
    if (card.flags.has('TIGHT_CONNECTION')) penalty += PARAMS.penalties.tight;
    if (g) {
      penalty += PARAMS.penalties.extraTransfer * Math.max(0, g.transfers - 1);
      penalty += PARAMS.penalties.estimatedShare * g.estimatedEur;
    }
    card.score = card.totalEur + (PARAMS.vot * card.extraMin) / 60 + penalty;
  }
}

/**
 * 06 · Kartları seç, fiyata göre sırala, rozetleri ver.
 *
 *   • En fazla 4 kart: puanı en iyi olanlar, doğrudan uçuş her zaman içeride.
 *   • Sıra: toplam fiyata göre artan; eşitlikte kısa süren önde.
 *   • CHEAPEST ilk karta, FASTEST en kısa süreliye, RECOMMENDED puanı en
 *     iyi olana. Kara bacağı doğrulanmamış kart önerilen olamaz.
 */
export function rankCards(cards: Card[], directPriceEur: number | null): RankedCard[] {
  const byScore = [...cards].sort((a, b) => a.score - b.score);
  const chosen: Card[] = byScore.slice(0, PARAMS.maxCards);
  const direct = cards.find((c) => c.kind === 'DIRECT');
  if (direct && !chosen.includes(direct)) chosen[chosen.length - 1] = direct;

  const sorted = chosen.sort((a, b) => a.totalEur - b.totalEur || a.doorToDoorMin - b.doorToDoorMin);
  const fastest = [...sorted].sort((a, b) => a.doorToDoorMin - b.doorToDoorMin || a.totalEur - b.totalEur)[0];
  const recommended = [...sorted]
    .filter((c) => c.ground === null || c.ground.verified)
    .sort((a, b) => a.score - b.score)[0];

  return sorted.map((card, i) => {
    const badges: Badge[] = [];
    if (i === 0) badges.push('CHEAPEST');
    if (card === fastest) badges.push('FASTEST');
    let reason: Reason | null = null;
    if (card === recommended) {
      badges.push('RECOMMENDED');
      reason = i === 0 ? 'CHEAPEST' : card === fastest ? 'FASTEST' : 'BEST_BALANCE';
    }
    return {
      ...card,
      rank: i + 1,
      badges,
      reason,
      savingsEur: directPriceEur === null ? null : directPriceEur - card.totalEur,
    };
  });
}
