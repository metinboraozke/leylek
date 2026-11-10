import type { LatLon } from '../core/geo.js';
import type { GroundLegData } from './ports.js';
import type { Card } from './types.js';

/**
 * "Rezervasyona git" bağlantıları.
 *
 * Hepsi ortaklık işaretsiz, doğrudan sağlayıcıya giden bağlantılar:
 * Leylek'in gelir kapısı yok. Travelpayouts'un `link` alanı (ortaklık
 * bağlantısı) burada da kullanılmaz.
 *
 *   • Uçuş: Google Flights araması, o gün ve o iki havalimanı önceden
 *     dolu; havayolunun kendi bileti de orada listelenir. Havayolu ana
 *     sayfası rota ve tarih almadığı için kullanıcıyı boş forma atıyordu.
 *   • Kara yolu (ROUTE): bütün kara yolculuğu Google Haritalar toplu
 *     taşıma yol tarifi olarak; ilk duraktan son durağa. Haritalar sefer
 *     saatlerini ve işletmecilerin bilet bağlantılarını gösterir.
 *     İşletmecilerin rezervasyon siteleri (bahn.de, ÖBB…) rota ve tarihi
 *     yalnızca kendi istasyon kimlikleriyle kabul ediyor; Transitous'ta o
 *     kimlikler yok.
 *   • Kara bacağı (GROUND): Transitous'un verdiği işletmeci adresi (ÖBB,
 *     FlixBus…), işletmecinin sitesi olarak. Adresi olmayan işletmeci için
 *     bağlantı üretilmez.
 */
export interface BookingLink {
  kind: 'FLIGHT' | 'GROUND' | 'ROUTE';
  provider: string;
  url: string;
  /** Bu bağlantıyla alınacak hatlar, ör. ["TK 1629"] ya da ["S8", "RJX 69"]. */
  lines: string[];
}

const AIRLINES: Record<string, { name: string; url: string }> = {
  TK: { name: 'Turkish Airlines', url: 'https://www.turkishairlines.com' },
  PC: { name: 'Pegasus', url: 'https://www.flypgs.com' },
  VF: { name: 'AJet', url: 'https://ajet.com' },
  XQ: { name: 'SunExpress', url: 'https://www.sunexpress.com' },
  LH: { name: 'Lufthansa', url: 'https://www.lufthansa.com' },
  OS: { name: 'Austrian Airlines', url: 'https://www.austrian.com' },
  LX: { name: 'SWISS', url: 'https://www.swiss.com' },
  EW: { name: 'Eurowings', url: 'https://www.eurowings.com' },
  FR: { name: 'Ryanair', url: 'https://www.ryanair.com' },
  W6: { name: 'Wizz Air', url: 'https://wizzair.com' },
  U2: { name: 'easyJet', url: 'https://www.easyjet.com' },
  AF: { name: 'Air France', url: 'https://www.airfrance.com' },
  KL: { name: 'KLM', url: 'https://www.klm.com' },
  BA: { name: 'British Airways', url: 'https://www.britishairways.com' },
  AZ: { name: 'ITA Airways', url: 'https://www.ita-airways.com' },
  A3: { name: 'Aegean', url: 'https://en.aegeanair.com' },
  IB: { name: 'Iberia', url: 'https://www.iberia.com' },
  VY: { name: 'Vueling', url: 'https://www.vueling.com' },
  TP: { name: 'TAP Air Portugal', url: 'https://www.flytap.com' },
  LO: { name: 'LOT', url: 'https://www.lot.com' },
  SN: { name: 'Brussels Airlines', url: 'https://www.brusselsairlines.com' },
  OU: { name: 'Croatia Airlines', url: 'https://www.croatiaairlines.com' },
  JU: { name: 'Air Serbia', url: 'https://www.airserbia.com' },
  RO: { name: 'TAROM', url: 'https://www.tarom.ro' },
  FB: { name: 'Bulgaria Air', url: 'https://www.air.bg' },
  SK: { name: 'SAS', url: 'https://www.flysas.com' },
  AY: { name: 'Finnair', url: 'https://www.finnair.com' },
  DY: { name: 'Norwegian', url: 'https://www.norwegian.com' },
  QS: { name: 'Smartwings', url: 'https://www.smartwings.com' },
};

/** Yalnızca https adresleri; geçersizse `null`. */
export function safeHttps(raw: string | null | undefined): string | null {
  if (!raw) return null;
  try {
    const url = new URL(raw.trim().startsWith('http') ? raw.trim() : `https://${raw.trim()}`);
    if (url.protocol === 'http:') url.protocol = 'https:';
    return url.protocol === 'https:' && url.hostname.includes('.') ? url.toString() : null;
  } catch {
    return null;
  }
}

export function flightLink(card: Card, day: string): BookingLink {
  const f = card.flight;
  const line = [f.airline, f.flightNumber].filter(Boolean).join(' ');
  // Uçuşun kendi günü: yakın günden gelen uçuşta aranan gün değil.
  const date = f.departIso.slice(0, 10) || day;
  const q = `Flights from ${f.originAirport} to ${f.destAirport} on ${date} one way`;
  return {
    kind: 'FLIGHT',
    provider: AIRLINES[f.airline]?.name ?? 'Google Flights',
    url: `https://www.google.com/travel/flights?hl=tr&curr=TRY&q=${encodeURIComponent(q)}`,
    lines: line ? [line] : [],
  };
}

const coord = (p: LatLon) => `${p.lat.toFixed(5)},${p.lon.toFixed(5)}`;

/**
 * Kara yolunun tamamı için Haritalar yol tarifi. Bacak yoksa (sefer
 * doğrulanamadı) havalimanından varış şehrine.
 */
export function routeLink(card: Card, destination: LatLon): BookingLink | null {
  const ground = card.ground;
  if (!ground) return null;
  const legs = ground.legs;
  // Durak adı ("München Hbf") Haritalar'da istasyonun kendisine çıkar;
  // koordinat ise yakındaki bir dükkâna. Ad yoksa koordinat.
  const first = legs[0];
  const last = legs.at(-1);
  const params = new URLSearchParams({
    api: '1',
    origin: first?.fromName || coord(first?.from ?? card.airport),
    destination: last?.toName || coord(last?.to ?? destination),
    travelmode: 'transit',
  });
  return {
    kind: 'ROUTE',
    provider: 'Google Haritalar',
    url: `https://www.google.com/maps/dir/?${params}`,
    lines: legs.map((l) => l.line).filter((l): l is string => !!l),
  };
}

export function groundLinks(legs: GroundLegData[]): BookingLink[] {
  const byProvider = new Map<string, BookingLink>();
  for (const leg of legs) {
    const url = safeHttps(leg.operatorUrl);
    if (!leg.operator || !url) continue;
    const existing = byProvider.get(leg.operator);
    const line = leg.line ?? '';
    if (existing) {
      if (line && !existing.lines.includes(line)) existing.lines.push(line);
    } else {
      byProvider.set(leg.operator, { kind: 'GROUND', provider: leg.operator, url, lines: line ? [line] : [] });
    }
  }
  return [...byProvider.values()];
}

export function bookingLinks(card: Card, day: string, destination: LatLon): BookingLink[] {
  const route = routeLink(card, destination);
  return [flightLink(card, day), ...(card.ground ? groundLinks(card.ground.legs) : []), ...(route ? [route] : [])];
}
