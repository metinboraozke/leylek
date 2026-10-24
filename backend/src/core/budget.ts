import type { Clock } from './cache.js';

/**
 * Sunucu geneli istek bütçesi: dakika ve gün kovası.
 *
 * Transitous koşulu "kaynakları az kullan". Arama başına sınır (K = 5)
 * tek bir aramayı korur; bu sınıf toplam yükü korur. Bütçe biterse
 * arama durmaz, kara bacakları tahminle ve uyarıyla döner.
 */
export class RequestBudget {
  private minuteWindow = 0;
  private minuteUsed = 0;
  private dayWindow = 0;
  private dayUsed = 0;

  constructor(
    private readonly perMinute: number,
    private readonly perDay: number,
    private readonly now: Clock = Date.now,
  ) {}

  private roll(): void {
    const t = this.now();
    const minute = Math.floor(t / 60_000);
    const day = Math.floor(t / 86_400_000);
    if (minute !== this.minuteWindow) {
      this.minuteWindow = minute;
      this.minuteUsed = 0;
    }
    if (day !== this.dayWindow) {
      this.dayWindow = day;
      this.dayUsed = 0;
    }
  }

  tryTake(): boolean {
    this.roll();
    if (this.minuteUsed >= this.perMinute || this.dayUsed >= this.perDay) return false;
    this.minuteUsed++;
    this.dayUsed++;
    return true;
  }

  remaining(): { minute: number; day: number } {
    this.roll();
    return { minute: this.perMinute - this.minuteUsed, day: this.perDay - this.dayUsed };
  }
}

/**
 * Sigorta: art arda hata ya da tek bir 429 gelirse çağrıları bir süre
 * keser. Zorlanan bir servise yüklenmeye devam etmemek için.
 */
export class CircuitBreaker {
  private failures = 0;
  private openUntil = 0;

  constructor(
    private readonly failureThreshold = 5,
    private readonly openMs = 10 * 60_000,
    private readonly now: Clock = Date.now,
  ) {}

  isOpen(): boolean {
    return this.now() < this.openUntil;
  }

  recordSuccess(): void {
    this.failures = 0;
  }

  recordFailure(rateLimited = false): void {
    this.failures++;
    if (rateLimited || this.failures >= this.failureThreshold) {
      this.openUntil = this.now() + this.openMs;
      this.failures = 0;
    }
  }
}
