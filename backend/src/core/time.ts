/**
 * Saat dilimi yardımcıları. Hesaplar hep UTC milisaniye ile yapılır;
 * yerel saat yalnızca gösterim ve "gece mi" kararı için hesaplanır.
 */

const MINUTE_MS = 60_000;
const DAY_MS = 86_400_000;

const offsetFormatters = new Map<string, Intl.DateTimeFormat>();

/** Verilen anda o saat diliminin UTC'ye göre farkı (dakika). */
export function offsetMinutes(instantMs: number, timeZone: string): number {
  let fmt = offsetFormatters.get(timeZone);
  if (!fmt) {
    fmt = new Intl.DateTimeFormat('en-US', { timeZone, timeZoneName: 'longOffset' });
    offsetFormatters.set(timeZone, fmt);
  }
  const part = fmt.formatToParts(new Date(instantMs)).find((p) => p.type === 'timeZoneName');
  // "GMT+01:00", "GMT-04:30" ya da tam UTC'de yalnızca "GMT".
  const match = part?.value.match(/GMT([+-])(\d{2}):(\d{2})/);
  if (!match) return 0;
  const sign = match[1] === '-' ? -1 : 1;
  return sign * (Number(match[2]) * 60 + Number(match[3]));
}

/** `2026-11-20T09:55:00+01:00` biçimi. */
export function toOffsetIso(instantMs: number, timeZone: string): string {
  const offset = offsetMinutes(instantMs, timeZone);
  const wall = new Date(instantMs + offset * MINUTE_MS).toISOString().slice(0, 19);
  const sign = offset < 0 ? '-' : '+';
  const abs = Math.abs(offset);
  const hh = String(Math.floor(abs / 60)).padStart(2, '0');
  const mm = String(abs % 60).padStart(2, '0');
  return `${wall}${sign}${hh}:${mm}`;
}

/** Ofsetli ISO metnini UTC milisaniyeye çevirir; geçersizse `null`. */
export function parseInstant(iso: string): number | null {
  const ms = Date.parse(iso);
  return Number.isFinite(ms) ? ms : null;
}

/**
 * Aşağı yuvarlar. Önbellek isabeti için arama anı 15 dakikalık kovalara
 * indirilir; aşağı yuvarlandığı için sonuçlar sonradan süzülmelidir.
 */
export function floorToMinutes(instantMs: number, minutes: number): number {
  const step = minutes * MINUTE_MS;
  return Math.floor(instantMs / step) * step;
}

/**
 * [start, end) aralığı yerel saatle 00:00–05:00 arasına giriyor mu?
 * Ofset aralık boyunca sabit kabul edilir (bekleme birkaç saat sürer;
 * yaz saati geçişi bu kararı değiştirmez).
 */
export function overlapsNight(
  startMs: number,
  endMs: number,
  timeZone: string,
  nightEndHour = 5,
): boolean {
  if (endMs <= startMs) return false;
  const offset = offsetMinutes(startMs, timeZone) * MINUTE_MS;
  const start = startMs + offset;
  const end = endMs + offset;
  for (let day = Math.floor(start / DAY_MS); day <= Math.floor(end / DAY_MS); day++) {
    const nightStart = day * DAY_MS;
    const nightEnd = nightStart + nightEndHour * 60 * MINUTE_MS;
    if (start < nightEnd && end > nightStart) return true;
  }
  return false;
}

/** Bir saat dilimindeki yerel günü `YYYY-MM-DD` olarak verir. */
export function localDay(instantMs: number, timeZone: string): string {
  return new Date(instantMs + offsetMinutes(instantMs, timeZone) * MINUTE_MS).toISOString().slice(0, 10);
}
