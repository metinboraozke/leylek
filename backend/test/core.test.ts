import { describe, expect, it } from 'vitest';
import { CircuitBreaker, RequestBudget } from '../src/core/budget.js';
import { TtlCache } from '../src/core/cache.js';
import { boundingBox, haversineKm, inBox } from '../src/core/geo.js';
import { requestSerializer } from '../src/core/logger.js';
import { normalize } from '../src/core/text.js';
import { offsetMinutes, overlapsNight, toOffsetIso } from '../src/core/time.js';

describe('haversine ve sınır kutusu', () => {
  it('bilinen şehir çiftlerinde ±1 km doğru', () => {
    expect(haversineKm({ lat: 51.5074, lon: -0.1278 }, { lat: 48.8566, lon: 2.3522 })).toBeCloseTo(343.5, 0);
    expect(haversineKm({ lat: 48.1374, lon: 11.5755 }, { lat: 47.7994, lon: 13.044 })).toBeGreaterThan(114);
    expect(haversineKm({ lat: 48.1374, lon: 11.5755 }, { lat: 47.7994, lon: 13.044 })).toBeLessThan(118);
  });

  it('aynı nokta için sıfır', () => {
    expect(haversineKm({ lat: 47, lon: 13 }, { lat: 47, lon: 13 })).toBe(0);
  });

  it('kutu yarıçaptaki noktaları kapsar, uzaktakileri dışarıda bırakır', () => {
    const box = boundingBox({ lat: 47.8, lon: 13.04 }, 150);
    expect(inBox({ lat: 48.35, lon: 11.79 }, box)).toBe(true); // MUC ~ 110 km
    expect(inBox({ lat: 48.11, lon: 16.57 }, box)).toBe(false); // VIE ~ 265 km
  });
});

describe('saat dilimi', () => {
  it('kış ve yaz saatini ayırır', () => {
    expect(offsetMinutes(Date.parse('2026-11-20T12:00:00Z'), 'Europe/Vienna')).toBe(60);
    expect(offsetMinutes(Date.parse('2026-07-01T12:00:00Z'), 'Europe/Vienna')).toBe(120);
    expect(offsetMinutes(Date.parse('2026-07-01T12:00:00Z'), 'Europe/Istanbul')).toBe(180);
  });

  it('yerel ofsetli ISO metin üretir', () => {
    expect(toOffsetIso(Date.parse('2026-11-20T08:55:00Z'), 'Europe/Berlin')).toBe('2026-11-20T09:55:00+01:00');
    expect(toOffsetIso(Date.parse('2026-11-20T08:55:00Z'), 'UTC')).toBe('2026-11-20T08:55:00+00:00');
  });

  it('gece beklemesini yerel saate göre tanır', () => {
    const tz = 'Europe/Berlin';
    // 23:30 → 06:10 yerel: gece
    expect(overlapsNight(Date.parse('2026-11-20T22:30:00Z'), Date.parse('2026-11-21T05:10:00Z'), tz)).toBe(true);
    // 09:55 → 11:46 yerel: gündüz
    expect(overlapsNight(Date.parse('2026-11-20T08:55:00Z'), Date.parse('2026-11-20T10:46:00Z'), tz)).toBe(false);
    // 05:30 → 07:00 yerel: gece bitti
    expect(overlapsNight(Date.parse('2026-11-20T04:30:00Z'), Date.parse('2026-11-20T06:00:00Z'), tz)).toBe(false);
  });
});

describe('metin sadeleştirme', () => {
  it('Türkçe ve Avrupa harflerini aynı anahtara indirir', () => {
    expect(normalize('MÜNİH')).toBe('munih');
    expect(normalize('München')).toBe('munchen');
    expect(normalize('İstanbul')).toBe('istanbul');
    expect(normalize('ISPARTA')).toBe('isparta');
    expect(normalize('Kraków Główny')).toBe('krakow glowny');
    expect(normalize('Straße')).toBe('strasse');
  });
});

describe('önbellek', () => {
  it('aynı anahtarda eşzamanlı istekleri tek hesaplamada birleştirir', async () => {
    const cache = new TtlCache();
    let runs = 0;
    const compute = async () => {
      runs++;
      await new Promise((r) => setTimeout(r, 5));
      return 42;
    };
    const results = await Promise.all([1, 2, 3].map(() => cache.singleFlight('k', 1000, compute)));
    expect(results).toEqual([42, 42, 42]);
    expect(runs).toBe(1);
  });

  it('süresi dolanı düşürür, sınırı aşınca en az kullanılanı atar', () => {
    let t = 0;
    const cache = new TtlCache(2, () => t);
    cache.set('a', 1, 100);
    cache.set('b', 2, 100);
    cache.get('a'); // a son kullanılan
    cache.set('c', 3, 100);
    expect(cache.get('b')).toBeUndefined();
    expect(cache.get('a')).toBe(1);
    t = 200;
    expect(cache.get('a')).toBeUndefined();
  });

  it('hatayı istenirse kısa süre saklar, istenmezse saklamaz', async () => {
    const cache = new TtlCache();
    let runs = 0;
    const fail = async () => {
      runs++;
      throw new Error('x');
    };
    await expect(cache.singleFlight('e', 1000, fail)).rejects.toThrow();
    await expect(cache.singleFlight('e', 1000, fail)).rejects.toThrow();
    expect(runs).toBe(2);
    await expect(cache.singleFlight('f', 1000, fail, { errorTtlMs: 1000 })).rejects.toThrow();
    await expect(cache.singleFlight('f', 1000, fail, { errorTtlMs: 1000 })).rejects.toThrow();
    expect(runs).toBe(3);
  });
});

describe('bütçe ve sigorta', () => {
  it('dakika kovası dolunca reddeder, yeni dakikada açılır', () => {
    let t = 0;
    const budget = new RequestBudget(2, 100, () => t);
    expect([budget.tryTake(), budget.tryTake(), budget.tryTake()]).toEqual([true, true, false]);
    t = 60_000;
    expect(budget.tryTake()).toBe(true);
  });

  it('günlük sınır dakikadan bağımsız işler', () => {
    let t = 0;
    const budget = new RequestBudget(10, 2, () => t);
    budget.tryTake();
    t = 120_000;
    budget.tryTake();
    t = 240_000;
    expect(budget.tryTake()).toBe(false);
  });

  it('art arda 5 hatada ya da tek 429da açılır', () => {
    let t = 0;
    const breaker = new CircuitBreaker(5, 1000, () => t);
    for (let i = 0; i < 4; i++) breaker.recordFailure();
    expect(breaker.isOpen()).toBe(false);
    breaker.recordFailure();
    expect(breaker.isOpen()).toBe(true);
    t = 2000;
    expect(breaker.isOpen()).toBe(false);
    breaker.recordFailure(true);
    expect(breaker.isOpen()).toBe(true);
  });
});

describe('log gizliliği', () => {
  it('istek kaydında IP ve sorgu dizesi yok', () => {
    const logged = requestSerializer({
      method: 'GET',
      url: '/v1/search?from=Istanbul&to=Salzburg&date=2026-11-20',
      id: 'req-1',
      // Fastify isteğinde bulunan ama yazılmaması gereken alanlar
      ...({ ip: '203.0.113.7', headers: { 'user-agent': 'x' } } as object),
    });
    expect(logged).toEqual({ method: 'GET', path: '/v1/search', reqId: 'req-1' });
    expect(JSON.stringify(logged)).not.toContain('203.0.113.7');
    expect(JSON.stringify(logged)).not.toContain('Salzburg');
  });
});
