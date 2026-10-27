import { HOUR, TtlCache } from '../../core/cache.js';
import { UpstreamError } from '../../core/errors.js';
import type { HttpClient } from '../../core/http.js';
import { parseInstant } from '../../core/time.js';
import type { FlightPriceSource, FlightQuote } from '../../search/ports.js';

/**
 * Travelpayouts (Aviasales) önbellekli uçuş fiyatı istemcisi.
 *
 * PAX'teki istemciden uyarlandı; oradaki ölçülerek bulunmuş dersler:
 *   • `prices_for_dates` kullanılır. `get_latest_prices` tarih filtresini
 *     yok sayıyor ve havayolu alanı döndürmüyor.
 *   • `one_way=true` ZORUNLU: sağlayıcının varsayılanı gidiş-dönüş fiyatı
 *     ve tek yön sanılırsa fiyat iki katına kadar yanlış çıkıyor.
 *   • Yanıtta tazelik alanı yok; fiyatın yaşı `link` içindeki
 *     `search_date=GGAAYYYY` parametresinden okunur.
 *
 * Leylek'e özel: `link` (ortaklık bağlantısı) yalnızca yaş için okunur,
 * hiçbir zaman istemciye gitmez. Marker gönderilmez.
 */
const PATH = '/aviasales/v3/prices_for_dates';
const TTL = 6 * HOUR;

interface RawQuote {
  price?: number;
  airline?: string;
  flight_number?: string | number;
  departure_at?: string;
  origin_airport?: string;
  destination_airport?: string;
  duration_to?: number;
  duration?: number;
  transfers?: number;
  link?: string;
}

/** `search_date=GGAAYYYY` → kaç gün önce. */
export function priceAgeDays(link: string | undefined, now: number): number | null {
  if (!link) return null;
  const match = link.match(/[?&]search_date=(\d{2})(\d{2})(\d{4})/);
  if (!match) return null;
  const found = Date.UTC(Number(match[3]), Number(match[2]) - 1, Number(match[1]));
  if (!Number.isFinite(found)) return null;
  const today = new Date(now);
  const todayUtc = Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate());
  return Math.max(0, Math.round((todayUtc - found) / 86_400_000));
}

export function mapQuote(raw: RawQuote, origin: string, dest: string, now: number): FlightQuote | null {
  const price = Number(raw.price);
  if (!Number.isFinite(price) || price <= 0 || !raw.departure_at) return null;
  const departMs = parseInstant(raw.departure_at);
  const durationMin = Number(raw.duration_to ?? raw.duration ?? 0);
  if (departMs === null || !Number.isFinite(durationMin) || durationMin <= 0) return null;

  return {
    originAirport: (raw.origin_airport ?? origin).toUpperCase(),
    destAirport: (raw.destination_airport ?? dest).toUpperCase(),
    departIso: raw.departure_at,
    departMs,
    arriveMs: departMs + durationMin * 60_000,
    priceEur: price,
    airline: (raw.airline ?? '').trim().toUpperCase(),
    flightNumber: raw.flight_number != null ? String(raw.flight_number) : null,
    transfers: Number(raw.transfers ?? 0) || 0,
    priceAgeDays: priceAgeDays(raw.link, now),
  };
}

export class TravelpayoutsClient implements FlightPriceSource {
  constructor(
    private readonly http: HttpClient,
    private readonly token: string,
    private readonly cache: TtlCache,
    private readonly now: () => number = Date.now,
    private readonly baseUrl = 'https://api.travelpayouts.com',
  ) {}

  async quotes(originCode: string, destCode: string, day: string): Promise<FlightQuote[]> {
    if (!this.token) {
      throw new UpstreamError('travelpayouts', 'status', 'TRAVELPAYOUTS_TOKEN tanımlı değil', 503);
    }
    const key = `tp:${originCode}:${destCode}:${day}:EUR`;
    return this.cache.singleFlight(key, TTL, async () => {
      const query = new URLSearchParams({
        origin: originCode,
        destination: destCode,
        departure_at: day,
        one_way: 'true',
        currency: 'eur',
        sorting: 'price',
        limit: '30',
        token: this.token,
      });
      const body = await this.http.getJson<{ data?: RawQuote[] }>(`${this.baseUrl}${PATH}?${query}`);
      const now = this.now();
      return (body.data ?? [])
        .map((raw) => mapQuote(raw, originCode, destCode, now))
        .filter((q): q is FlightQuote => q !== null && q.departIso.startsWith(day));
    });
  }
}
