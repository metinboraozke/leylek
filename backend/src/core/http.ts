import { UpstreamError } from './errors.js';

export type FetchFn = typeof fetch;

/**
 * Dış servislere GET isteği atıp JSON ya da metin döndüren küçük istemci.
 *
 * Sağlayıcılar `fetch`'i doğrudan çağırmaz, bunu kullanır: zaman aşımı,
 * User-Agent ve hata çevirisi tek yerde. Testte sahte bir `fetch` verilir;
 * testler hiçbir zaman gerçek ağa çıkmaz.
 */
export class HttpClient {
  constructor(
    private readonly service: string,
    private readonly fetchFn: FetchFn,
    private readonly userAgent: string,
    private readonly timeoutMs = 15_000,
  ) {}

  async getJson<T>(url: string): Promise<T> {
    const response = await this.request(url, 'application/json');
    try {
      return (await response.json()) as T;
    } catch {
      throw new UpstreamError(this.service, 'parse', 'Yanıt JSON olarak okunamadı');
    }
  }

  async getText(url: string): Promise<string> {
    return (await this.request(url, '*/*')).text();
  }

  async getBytes(url: string): Promise<Uint8Array> {
    return new Uint8Array(await (await this.request(url, '*/*')).arrayBuffer());
  }

  private async request(url: string, accept: string): Promise<Response> {
    let response: Response;
    try {
      response = await this.fetchFn(url, {
        signal: AbortSignal.timeout(this.timeoutMs),
        headers: { accept, 'user-agent': this.userAgent },
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : 'bilinmeyen ağ hatası';
      throw new UpstreamError(this.service, 'network', message);
    }
    if (response.status === 429) {
      throw new UpstreamError(this.service, 'rate_limited', 'Hız sınırı aşıldı', 429);
    }
    if (!response.ok) {
      throw new UpstreamError(this.service, 'status', `HTTP ${response.status}`, response.status);
    }
    return response;
  }
}
