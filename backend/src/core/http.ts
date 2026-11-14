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
  private last = 0;
  private queue: Promise<void> = Promise.resolve();

  /**
   * [minIntervalMs] > 0 ise istekler sırayla ve aralarında en az bu kadar
   * süre bırakılarak başlar. Transitous ani istek patlamasına 429 dönüyor;
   * bir aramanın 5 adayı aynı anda sorulunca sigorta 10 dakika açılıyordu.
   */
  constructor(
    private readonly service: string,
    private readonly fetchFn: FetchFn,
    private readonly userAgent: string,
    private readonly timeoutMs = 15_000,
    private readonly minIntervalMs = 0,
    private readonly now: () => number = Date.now,
  ) {}

  /** Sıradaki isteğin başlama anına kadar bekler. */
  private async slot(): Promise<void> {
    if (this.minIntervalMs <= 0) return;
    const previous = this.queue;
    let release!: () => void;
    this.queue = new Promise((resolve) => (release = resolve));
    await previous;
    const wait = this.last + this.minIntervalMs - this.now();
    if (wait > 0) await new Promise((resolve) => setTimeout(resolve, wait));
    this.last = this.now();
    release();
  }

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
    await this.slot();
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
      const seconds = Number(response.headers.get('retry-after'));
      const retryAfterMs = Number.isFinite(seconds) && seconds > 0 ? seconds * 1000 : undefined;
      throw new UpstreamError(this.service, 'rate_limited', 'Hız sınırı aşıldı', 429, retryAfterMs);
    }
    if (!response.ok) {
      throw new UpstreamError(this.service, 'status', `HTTP ${response.status}`, response.status);
    }
    return response;
  }
}
