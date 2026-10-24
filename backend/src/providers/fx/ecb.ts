import { DAY, TtlCache } from '../../core/cache.js';
import type { HttpClient } from '../../core/http.js';
import type { FxRates } from '../../search/ports.js';

/**
 * ECB günlük referans kurları (EUR bazlı, TRY dahil). 24 saat önbellek.
 * Alınamazsa son bilinen kur kullanılır; hiç yoksa hata.
 */
const URL_DAILY = 'https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml';

export function parseEcbXml(xml: string): Map<string, number> {
  const rates = new Map<string, number>([['EUR', 1]]);
  for (const m of xml.matchAll(/currency=['"]([A-Z]{3})['"]\s+rate=['"]([\d.]+)['"]/g)) {
    const rate = Number(m[2]);
    if (m[1] && Number.isFinite(rate) && rate > 0) rates.set(m[1], rate);
  }
  return rates;
}

export class EcbRates implements FxRates {
  private lastKnown: Map<string, number> | null = null;

  constructor(
    private readonly http: HttpClient,
    private readonly cache: TtlCache,
  ) {}

  async perEur(currency: string): Promise<number> {
    if (currency === 'EUR') return 1;
    const rates = await this.rates();
    const rate = rates.get(currency);
    if (!rate) throw new Error(`Kur bulunamadı: ${currency}`);
    return rate;
  }

  private async rates(): Promise<Map<string, number>> {
    try {
      const rates = await this.cache.singleFlight('fx:ecb', DAY, async () =>
        parseEcbXml(await this.http.getText(URL_DAILY)),
      );
      this.lastKnown = rates;
      return rates;
    } catch (error) {
      if (this.lastKnown) return this.lastKnown;
      throw error;
    }
  }
}
