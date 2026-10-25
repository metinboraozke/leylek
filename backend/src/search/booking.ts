import type { GroundLegData } from './ports.js';
import type { Card } from './types.js';

/**
 * "Rezervasyona git" bağlantıları.
 *
 * Hepsi ortaklık işaretsiz, doğrudan sağlayıcıya giden bağlantılar:
 * Leylek'in gelir kapısı yok. Travelpayouts'un `link` alanı (ortaklık
 * bağlantısı) burada da kullanılmaz.
 *
 *   • Uçuş: havayolunun kendi sitesi; tanınmayan havayolunda Google
 *     Flights araması (o gün, o iki havalimanı).
 *   • Kara bacağı: Transitous'un verdiği işletmeci adresi (ÖBB, FlixBus…).
 *     Adresi olmayan işletmeci için bağlantı üretilmez.
 */
export interface BookingLink {
  kind: 'FLIGHT' | 'GROUND';
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
  const airline = AIRLINES[f.airline];
  if (airline) return { kind: 'FLIGHT', provider: airline.name, url: airline.url, lines: line ? [line] : [] };
  const q = `Flights from ${f.originAirport} to ${f.destAirport} on ${day} one way`;
  return {
    kind: 'FLIGHT',
    provider: 'Google Flights',
    url: `https://www.google.com/travel/flights?hl=tr&q=${encodeURIComponent(q)}`,
    lines: line ? [line] : [],
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

export function bookingLinks(card: Card, day: string): BookingLink[] {
  return [flightLink(card, day), ...(card.ground ? groundLinks(card.ground.legs) : [])];
}
