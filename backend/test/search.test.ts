import { describe, expect, it } from 'vitest';
import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import { AppError } from '../src/core/errors.js';
import { DAY, FakeFlights, FakeGround, indexes, NOW, salzburgFlights, service } from './helpers.js';

const groundOk = () =>
  new FakeGround({
    MUC: { waitMin: 6, durationMin: 132 },
    INN: { waitMin: 12, durationMin: 118, fares: [{ amount: 36, currency: 'EUR' }], priced: true },
    LNZ: { waitMin: 10, durationMin: 80 },
    NUE: { waitMin: 10, durationMin: 200 },
    FMM: { waitMin: 15, durationMin: 210 },
  });

const query = { from: 'İstanbul', to: 'Salzburg', date: DAY, radiusKm: 250, maxGroundHours: 5, currency: 'TRY' as const };

describe('/search hattı uçtan uca (dış servisler sahte)', () => {
  it('İstanbul → Salzburg: en az 3 kart, fiyata göre sıralı, doğrudan uçuş dahil, bir önerilen', async () => {
    const ground = groundOk();
    const res = await service(new FakeFlights(salzburgFlights()), ground).search(query);

    expect(res.options.length).toBeGreaterThanOrEqual(3);
    expect(res.options.length).toBeLessThanOrEqual(4);
    const prices = res.options.map((o) => o.total.price);
    expect(prices).toEqual([...prices].sort((a, b) => a - b));
    expect(res.options.some((o) => o.kind === 'DIRECT')).toBe(true);
    expect(res.options.filter((o) => o.badges.includes('RECOMMENDED'))).toHaveLength(1);
    expect(res.options[0]!.badges).toContain('CHEAPEST');
    expect(res.recommendedRank).not.toBeNull();

    // Transitous'a en fazla K = 5 istek
    expect(ground.requests.length).toBeLessThanOrEqual(5);

    // Para birimi: 40 TRY/EUR sahte kurla
    const direct = res.options.find((o) => o.kind === 'DIRECT')!;
    expect(direct.total.price).toBe(245 * 40);
    expect(direct.flight.airport).toBe('SZG');

    // Atıf her yanıtta
    expect(res.attribution.map((a) => a.name)).toEqual(expect.arrayContaining(['Transitous', 'OpenStreetMap katkıcıları']));
  });

  it('kart alanları uygulamanın beklediği biçimde', async () => {
    const res = await service(new FakeFlights(salzburgFlights()), groundOk()).search(query);
    const via = res.options.find((o) => o.kind === 'VIA' && o.via?.iata === 'MUC')!;
    expect(via.via).toMatchObject({ iata: 'MUC', name: 'Münih', country: 'DE' });
    expect(via.flight.departAt).toBe('2026-11-20T08:05:00+03:00');
    expect(via.flight.arriveAt).toBe('2026-11-20T08:55:00+01:00');
    expect(via.ground!.legs.map((l) => l.line)).toEqual(['S8', 'RE 5']);
    expect(via.ground!.fare.currency).toBe('TRY');
    expect(via.flags).toContain('SEPARATE_TICKETS');
    // Rezervasyon: havayolunun sitesi + adresi bilinen işletmeci; ortaklık bağlantısı yok
    expect(via.booking).toEqual([
      { kind: 'FLIGHT', provider: 'Turkish Airlines', url: 'https://www.turkishairlines.com', lines: ['TK 1'] },
      { kind: 'GROUND', provider: 'MVV', url: 'https://www.mvv-muenchen.de/', lines: ['S8'] },
    ]);
    // İniş 07:55Z + 90 dk = 09:25Z → 09:30Z kovası; sahte yolculuk 6 dk sonra
    expect(via.ground!.departAt).toBe('2026-11-20T10:36:00+01:00');
    expect(via.ground!.waitMin).toBe(101);
  });

  it('kara bacakları doğrulanamazsa tahminle doldurur ve uyarır', async () => {
    const failing = new FakeGround({
      MUC: { waitMin: 0, durationMin: 0, fail: true },
      INN: { waitMin: 0, durationMin: 0, fail: true },
      LNZ: { waitMin: 0, durationMin: 0, fail: true },
      NUE: { waitMin: 0, durationMin: 0, fail: true },
      FMM: { waitMin: 0, durationMin: 0, fail: true },
    });
    const res = await service(new FakeFlights(salzburgFlights()), failing).search(query);
    expect(res.options.length).toBeGreaterThanOrEqual(3);
    expect(res.warnings).toContain('PARTIAL_RESULTS');
    const unverified = res.options.filter((o) => o.flags.includes('GROUND_NOT_VERIFIED'));
    expect(unverified.length).toBeGreaterThan(0);
    for (const o of unverified) expect(o.badges).not.toContain('RECOMMENDED');
  });

  it('tek aday varken 3 karta ulaşamazsa uyarı ekler', async () => {
    const flights = new FakeFlights({ SZG: salzburgFlights().SZG!, MUC: [salzburgFlights().MUC![0]!] });
    const res = await service(flights, groundOk()).search({ ...query, radiusKm: 150 });
    expect(res.options.length).toBe(2);
    expect(res.warnings).toContain('FEWER_THAN_THREE');
  });

  it('aynı arama ikinci kez dış servise gitmez', async () => {
    const flights = new FakeFlights(salzburgFlights());
    const ground = groundOk();
    const svc = service(flights, ground);
    await svc.search(query);
    const calls = [flights.calls.length, ground.requests.length];
    await svc.search(query);
    expect([flights.calls.length, ground.requests.length]).toEqual(calls);
  });

  it('Türkiye içi varışı kapsam dışı sayar', async () => {
    await expect(service(new FakeFlights({}), groundOk()).search({ ...query, to: 'Ankara' })).rejects.toMatchObject({
      code: 'OUT_OF_COVERAGE',
      status: 422,
    });
  });

  it('uçuş kaynağı tamamen çökerse 503', async () => {
    const err = await service(new FakeFlights({}, true), groundOk()).search(query).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(AppError);
    expect((err as AppError).status).toBe(503);
  });
});

describe('HTTP katmanı', () => {
  async function app(rateLimit = 20) {
    const config = loadConfig({ NODE_ENV: 'test', RATE_LIMIT_PER_MINUTE: String(rateLimit) });
    const ix = indexes();
    return buildApp({
      config,
      search: service(new FakeFlights(salzburgFlights()), groundOk()),
      indexes: () => ix,
      status: () => ({}),
      now: () => NOW,
    });
  }

  it('GET /v1/search 200 ve güvenlik başlıkları', async () => {
    const a = await app();
    const res = await a.inject({ method: 'GET', url: `/v1/search?from=city:745044&to=Salzburg&date=${DAY}` });
    expect(res.statusCode).toBe(200);
    expect(res.json().options.length).toBeGreaterThanOrEqual(3);
    expect(res.headers['content-security-policy']).toContain("default-src 'none'");
    expect(res.headers['permissions-policy']).toContain('geolocation=()');
  });

  it('geçmiş tarih ve eksik alan 400, Türkçe mesajla', async () => {
    const a = await app();
    const past = await a.inject({ method: 'GET', url: '/v1/search?from=Istanbul&to=Salzburg&date=2026-01-01' });
    expect(past.statusCode).toBe(400);
    expect(past.json().error).toMatchObject({ code: 'INVALID_QUERY', field: 'date', message: 'Geçmiş bir tarih seçilemez.' });
    const missing = await a.inject({ method: 'GET', url: `/v1/search?from=Istanbul&date=${DAY}` });
    expect(missing.statusCode).toBe(400);
  });

  it('kapsam dışı varış 422', async () => {
    const res = await (await app()).inject({ method: 'GET', url: `/v1/search?from=Istanbul&to=Ankara&date=${DAY}` });
    expect(res.statusCode).toBe(422);
    expect(res.json().error.code).toBe('OUT_OF_COVERAGE');
  });

  it('GET /v1/places dış istek atmadan öneri döner', async () => {
    const res = await (await app()).inject({ method: 'GET', url: '/v1/places?q=m%C3%BCn' });
    expect(res.json().places[0]).toEqual({
      id: 'city:2867714',
      name: 'Münih',
      countryCode: 'DE',
      countryName: 'Almanya',
      kind: 'CITY',
      iata: 'MUC',
    });
  });

  it('hız sınırı aşılınca 429, sağlık uç noktası sınırsız', async () => {
    const a = await app(2);
    const url = '/v1/places?q=salz';
    const codes = [];
    for (let i = 0; i < 3; i++) codes.push((await a.inject({ method: 'GET', url })).statusCode);
    expect(codes).toEqual([200, 200, 429]);
    const health = await a.inject({ method: 'GET', url: '/health' });
    expect(health.statusCode).toBe(200);
    expect(health.json().status).toBe('ok');
  });
});
