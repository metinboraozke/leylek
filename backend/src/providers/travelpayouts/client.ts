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
 *
 * Veri, Aviasales kullanıcılarının son 48 saatte yaptığı aramaların
 * önbelleği; ülke kısıtı yok ama kimsenin aramadığı gün boş döner
 * (İstanbul → Sevilla 24 Kasım: 0 uçuş, Kasım ayı: 16 gün). Seçilen gün
 * boşsa aynı yol ay olarak sorulur (ayın her günü için en ucuz uçuş, tek
 * istek) ve ±[FLEX_DAYS] gün içindeki en yakın günün uçuşu alınır.
 */
const PATH = '/aviasales/v3/prices_for_dates';
const TTL = 6 * HOUR;
export const FLEX_DAYS = 3;
const DAY_MS = 86_400_000;

/** `2026-11-24` ± n gün → `2026-11-27`. */
function shiftDay(day: string, n: number): string {
  return new Date(Date.parse(`${day}T00:00:00Z`) + n * DAY_MS).toISOString().slice(0, 10);
}

function dayDiff(a: string, b: string): number {
  return Math.round((Date.parse(`${a}T00:00:00Z`) - Date.parse(`${b}T00:00:00Z`)) / DAY_MS);
}

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

  /**
   * O günün uçuşları; o gün boşsa ±[FLEX_DAYS] gün içinde seçilen güne en
   * yakın günün uçuşları (önce ve sonra eşit uzaksa ikisi de).
   */
  async quotes(originCode: string, destCode: string, day: string): Promise<FlightQuote[]> {
    if (!this.token) {
      throw new UpstreamError('travelpayouts', 'status', 'TRAVELPAYOUTS_TOKEN tanımlı değil', 503);
    }
    const exact = await this.fetch(originCode, destCode, day);
    if (exact.length > 0) return exact;

    const months = [...new Set([shiftDay(day, -FLEX_DAYS), shiftDay(day, FLEX_DAYS)].map((d) => d.slice(0, 7)))];
    const now = this.now();
    const near = (await Promise.all(months.map((m) => this.fetch(originCode, destCode, m))))
      .flat()
      .filter((q) => q.departMs > now && Math.abs(dayDiff(q.departIso.slice(0, 10), day)) <= FLEX_DAYS);
    if (near.length === 0) return [];
    const closest = Math.min(...near.map((q) => Math.abs(dayDiff(q.departIso.slice(0, 10), day))));
    return near.filter((q) => Math.abs(dayDiff(q.departIso.slice(0, 10), day)) === closest);
  }

  monthQuotes(originCode: string, destCode: string, month: string): Promise<FlightQuote[]> {
    if (!this.token) {
      return Promise.reject(new UpstreamError('travelpayouts', 'status', 'TRAVELPAYOUTS_TOKEN tanımlı değil', 503));
    }
    return this.fetch(originCode, destCode, month);
  }

  /** `departure_at` gün (`2026-11-24`) ya da ay (`2026-11`); önbellekli. */
  private fetch(originCode: string, destCode: string, departure: string): Promise<FlightQuote[]> {
    const key = `tp:${originCode}:${destCode}:${departure}:EUR`;
    return this.cache.singleFlight(key, TTL, async () => {
      const query = new URLSearchParams({
        origin: originCode,
        destination: destCode,
        departure_at: departure,
        one_way: 'true',
        currency: 'eur',
        sorting: 'price',
        // Ay sorgusunda günde bir uçuş döner; 31 gün sığsın.
        limit: departure.length === 7 ? '31' : '30',
        token: this.token,
      });
      const body = await this.http.getJson<{ data?: RawQuote[] }>(`${this.baseUrl}${PATH}?${query}`);
      const now = this.now();
      return (body.data ?? [])
        .map((raw) => mapQuote(raw, originCode, destCode, now))
        .filter((q): q is FlightQuote => q !== null && q.departIso.startsWith(departure));
    });
  }
}
