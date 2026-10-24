/**
 * Bellek içi TTL önbelleği.
 *
 * PAX'teki `MemoryCache`'ten uyarlandı. Farklar:
 *   • Redis yok: Leylek tek süreç, durumsuz bir sunucu.
 *   • LRU: okunan kayıt sona taşınır, sınır aşılınca en az kullanılan düşer.
 *   • `singleFlight`: aynı anahtar için aynı anda gelen istekler tek bir
 *     hesaplamayı bekler. Aynı anda 20 kişi aynı rotayı ararsa
 *     Transitous'a 20 kez gitmeyiz.
 *
 * Anahtarlarda kişisel veri yok: yalnızca kodlar, koordinatlar ve gün.
 */
interface Entry {
  value: unknown;
  expiresAt: number;
}

export type Clock = () => number;

export class TtlCache {
  private readonly store = new Map<string, Entry>();
  private readonly inFlight = new Map<string, Promise<unknown>>();

  constructor(
    private readonly maxEntries = 20_000,
    private readonly now: Clock = Date.now,
  ) {}

  get size(): number {
    return this.store.size;
  }

  get<T>(key: string): T | undefined {
    const entry = this.store.get(key);
    if (!entry) return undefined;
    if (entry.expiresAt <= this.now()) {
      this.store.delete(key);
      return undefined;
    }
    // LRU: son okunanı sona taşı.
    this.store.delete(key);
    this.store.set(key, entry);
    return entry.value as T;
  }

  set<T>(key: string, value: T, ttlMs: number): void {
    this.store.delete(key);
    this.store.set(key, { value, expiresAt: this.now() + Math.max(1, ttlMs) });
    while (this.store.size > this.maxEntries) {
      const oldest = this.store.keys().next().value;
      if (oldest === undefined) break;
      this.store.delete(oldest);
    }
  }

  /**
   * Önbellekte varsa döner; yoksa `compute` bir kez çalışır, sonucu
   * `ttlMs` süreyle saklanır. Hata önbelleğe alınmaz, ama `errorTtlMs`
   * verilirse hata o süre boyunca tekrar denenmeden döner (çöken bir
   * servise her istekte yüklenmemek için).
   */
  async singleFlight<T>(
    key: string,
    ttlMs: number,
    compute: () => Promise<T>,
    options: { errorTtlMs?: number } = {},
  ): Promise<T> {
    const cached = this.get<{ ok: true; value: T } | { ok: false; error: unknown }>(key);
    if (cached) {
      if (cached.ok) return cached.value;
      throw cached.error;
    }

    const pending = this.inFlight.get(key);
    if (pending) return pending as Promise<T>;

    const run = (async () => {
      try {
        const value = await compute();
        this.set(key, { ok: true, value }, ttlMs);
        return value;
      } catch (error) {
        if (options.errorTtlMs) this.set(key, { ok: false, error }, options.errorTtlMs);
        throw error;
      } finally {
        this.inFlight.delete(key);
      }
    })();
    this.inFlight.set(key, run);
    return run;
  }
}

export const MINUTE = 60_000;
export const HOUR = 60 * MINUTE;
export const DAY = 24 * HOUR;
