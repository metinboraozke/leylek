import { describe, expect, it } from 'vitest';
import { transferPrices } from '../src/providers/transitous/fares.js';
import { bufferMinutes, ceilTo15, computeGround, stationAccess } from '../src/search/ground.js';
import { prefilter } from '../src/search/prefilter.js';
import { alternateFlightCard, directCard, rankCards, scoreCards, viaCard } from '../src/search/rank.js';
import type { AirportFlights, Candidate, Card, CardGround } from '../src/search/types.js';
import { AIRPORTS, FakeGround, fakeFx, indexes, quote } from './helpers.js';

const ix = indexes();
const salzburg = ix.places.resolve('Salzburg')!;
const ap = (iata: string) => AIRPORTS.find((a) => a.iata === iata)!;

function flights(iata: string, price: number, departIso = '2026-11-20T08:05:00+03:00', dur = 170): AirportFlights {
  const q = quote(iata, price, departIso, dur);
  const a = ap(iata);
  return { airport: a, distanceKm: 100, cheapest: q, earliest: q };
}

describe('05 · tampon süresi', () => {
  it('Schengen dışından girişte 90 dk, içeride 45 dk, aktarmada +15', () => {
    expect(bufferMinutes('TR', 'DE', 0)).toBe(90);
    expect(bufferMinutes('TR', 'GB', 0)).toBe(60);
    expect(bufferMinutes('DE', 'AT', 0)).toBe(45);
    expect(bufferMinutes('GB', 'FR', 0)).toBe(90);
    expect(bufferMinutes('TR', 'DE', 1)).toBe(105);
  });

  it('arama anı 15 dakikaya yukarı yuvarlanır, tampon hiç kısalmaz', () => {
    const landing = Date.parse('2026-11-20T08:55:00Z');
    const t = ceilTo15(landing + 90 * 60_000);
    expect(new Date(t).toISOString()).toBe('2026-11-20T10:30:00.000Z');
    expect(t).toBeGreaterThanOrEqual(landing + 90 * 60_000);
    expect(ceilTo15(Date.parse('2026-11-20T10:30:00Z'))).toBe(Date.parse('2026-11-20T10:30:00Z'));
  });
});

describe('04 · ağdan önce eleme', () => {
  it('kara süresi sınırı aşanı GROUND_TOO_LONG ile eler', () => {
    const r = prefilter([flights('NUE', 100)], salzburg, null, 2);
    expect(r.kept).toHaveLength(0);
    expect(r.dropped).toEqual([{ iata: 'NUE', reason: 'GROUND_TOO_LONG' }]);
  });

  it('doğrudandan pahalı görünen adayı elemez', () => {
    const direct = quote('SZG', 100, '2026-11-20T07:15:00+03:00', 385);
    const r = prefilter([flights('MUC', 400)], salzburg, direct, 5);
    expect(r.kept.map((c) => c.airport.iata)).toEqual(['MUC']);
  });

  it('en fazla 5 aday geçer, kalanlar yedekte ve NOT_IN_TOP_K', () => {
    const options = ['MUC', 'INN', 'LNZ', 'FMM', 'NUE', 'VIE'].map((iata, i) => flights(iata, 100 + i * 10));
    const r = prefilter(options, salzburg, null, 8);
    expect(r.kept).toHaveLength(5);
    expect(r.reserve).toHaveLength(1);
    expect(r.dropped.filter((d) => d.reason === 'NOT_IN_TOP_K')).toHaveLength(1);
    // Puan sırası: ucuz + yakın önde
    expect(r.kept[0]!.estimateScore).toBeLessThanOrEqual(r.kept[1]!.estimateScore);
  });
});

describe('MOTIS ücret kuralları', () => {
  const p = (amount: number, isDefault = true) => ({ amount, currency: 'EUR', riderCategory: { isDefaultFareCategory: isDefault } });

  it('A_AB_B: her bacak + aktarma ürünü', () => {
    expect(transferPrices({ rule: 'A_AB_B', transferProducts: [p(1)], effectiveFareLegProducts: [[[p(10)]], [[p(20)]]] }))
      .toEqual([{ amount: 10, currency: 'EUR' }, { amount: 20, currency: 'EUR' }, { amount: 1, currency: 'EUR' }]);
  });

  it('A_AB: yalnızca ilk bacak + aktarma ürünü', () => {
    expect(transferPrices({ rule: 'A_AB', effectiveFareLegProducts: [[[p(10)]], [[p(20)]]] }))
      .toEqual([{ amount: 10, currency: 'EUR' }]);
  });

  it('AB: yalnızca aktarma ürünü; ürün yoksa çözülemez', () => {
    expect(transferPrices({ rule: 'AB', transferProducts: [p(15)], effectiveFareLegProducts: [[[p(10)]]] }))
      .toEqual([{ amount: 15, currency: 'EUR' }]);
    expect(transferPrices({ rule: 'AB', effectiveFareLegProducts: [[[p(10)]]] })).toBeNull();
  });

  it('seçenekler arasında varsayılan yolcu kategorisinin en ucuzunu seçer', () => {
    expect(transferPrices({ effectiveFareLegProducts: [[[p(5, false)], [p(30)], [p(25)]]] }))
      .toEqual([{ amount: 25, currency: 'EUR' }]);
  });
});

describe('05 · kara bacağı hesabı', () => {
  const candidate = (): Candidate => ({ ...flights('MUC', 130), estimate: { roadKm: 150, hours: 2.75, costEur: 20 }, estimateScore: 150 });
  const deps = (router: FakeGround) => ({ router, fx: fakeFx, airports: ix.airports });

  it('isteği inişten 90 dk sonra, 15 dakikaya yuvarlanmış anla atar', async () => {
    const router = new FakeGround({ MUC: { waitMin: 6, durationMin: 132 } });
    const c = candidate();
    await computeGround(c, salzburg, { maxGroundHours: 5, stopoverDays: 0 }, deps(router));
    const req = router.requests[0]!;
    expect(req.earliestDepartMs).toBe(ceilTo15(c.cheapest.arriveMs + 90 * 60_000));
    expect(req.maxTravelMinutes).toBe(5 * 60 + 480);
  });

  it('fiyatsız yolculukta tahmini ücret, fiyatlıda gerçek ücret', async () => {
    const est = await computeGround(candidate(), salzburg, { maxGroundHours: 5, stopoverDays: 0 }, deps(new FakeGround({ MUC: { waitMin: 6, durationMin: 132 } })));
    expect(est.status).toBe('verified');
    if (est.status !== 'verified') return;
    expect(est.ground.fareSource).toBe('estimated');

    const real = await computeGround(candidate(), salzburg, { maxGroundHours: 5, stopoverDays: 0 }, deps(new FakeGround({ MUC: { waitMin: 6, durationMin: 132, fares: [{ amount: 32.5, currency: 'EUR' }], priced: true } })));
    if (real.status !== 'verified') throw new Error('doğrulanmalıydı');
    expect(real.ground.fareSource).toBe('transitous');
    expect(real.ground.fareEur).toBe(32.5);
    expect(real.ground.estimatedEur).toBe(0);
  });

  it('bağlantı yoksa impossible, servis hata verirse tahminle unverified', async () => {
    expect(await computeGround(candidate(), salzburg, { maxGroundHours: 5, stopoverDays: 0 }, deps(new FakeGround({ MUC: { waitMin: 0, durationMin: 0, none: true } }))))
      .toEqual({ status: 'impossible', reason: 'NO_GROUND_CONNECTION' });
    const failed = await computeGround(candidate(), salzburg, { maxGroundHours: 5, stopoverDays: 0 }, deps(new FakeGround({ MUC: { waitMin: 0, durationMin: 0, fail: true } })));
    expect(failed.status).toBe('unverified');
    if (failed.status === 'unverified') expect(failed.ground.verified).toBe(false);
  });

  it('durak bulunursa kimliğiyle, bulunamazsa ya da hata verirse koordinatla sorar', async () => {
    const router = new FakeGround({ MUC: { waitMin: 6, durationMin: 132 } });
    const withStop = { cityStation: async () => null, nearestStop: async () => ({ id: 'stop:muc', name: 'München Flughafen Terminal', lat: 48.354, lon: 11.785, modes: ['SUBURBAN'] }) };
    await computeGround(candidate(), salzburg, { maxGroundHours: 5, stopoverDays: 0 }, { ...deps(router), stops: withStop });
    expect(router.requests[0]!.fromStopId).toBe('stop:muc');

    const failing = { cityStation: async () => null, nearestStop: async () => { throw new Error('geocode 500'); } };
    await computeGround(candidate(), salzburg, { maxGroundHours: 5, stopoverDays: 0 }, { ...deps(router), stops: failing });
    expect(router.requests[1]!.fromStopId).toBeUndefined();
  });

  it('kara süresi sınırı aşan yolculuğu kullanmaz', async () => {
    const r = await computeGround(candidate(), salzburg, { maxGroundHours: 2, stopoverDays: 0 }, deps(new FakeGround({ MUC: { waitMin: 0, durationMin: 200 } })));
    expect(r).toEqual({ status: 'impossible', reason: 'GROUND_TOO_LONG' });
  });
});

describe('06 · puan, sıra ve rozetler', () => {
  const ground = (fareEur: number, departIso: string, durationMin: number, verified = true): CardGround => {
    const departMs = Date.parse(departIso);
    return {
      departMs,
      arriveMs: departMs + durationMin * 60_000,
      waitMin: 0,
      transfers: 1,
      legs: [],
      fareEur,
      estimatedEur: verified ? 0 : fareEur,
      fareSource: verified ? 'transitous' : 'estimated',
      verified,
    };
  };
  const cand = (iata: string, price: number, departIso: string) =>
    ({ ...flights(iata, price, departIso), estimate: { roadKm: 0, hours: 0, costEur: 0 }, estimateScore: 0 }) as Candidate;

  function scenario(): Card[] {
    const muc = cand('MUC', 130, '2026-11-20T08:05:00+03:00');
    const inn = cand('INN', 152, '2026-11-20T10:20:00+03:00');
    const lnz = cand('LNZ', 140, '2026-11-20T05:00:00+03:00');
    const cards = [
      viaCard(muc, muc.cheapest, ground(32, '2026-11-20T10:46:00Z', 132)),
      viaCard(inn, inn.cheapest, ground(36, '2026-11-20T12:42:00Z', 118)),
      viaCard(lnz, lnz.cheapest, ground(10, '2026-11-20T06:00:00Z', 60, false)),
      directCard(quote('SZG', 245, '2026-11-20T07:15:00+03:00', 385, { transfers: 1 }), ap('SZG'), 3),
    ];
    scoreCards(cards, cards[3]!.doorToDoorMin);
    return cards;
  }

  it('kartları en ucuzdan en pahalıya dizer ve sıra numarası verir', () => {
    const ranked = rankCards(scenario(), 245);
    expect(ranked.map((c) => c.totalEur)).toEqual([...ranked.map((c) => c.totalEur)].sort((a, b) => a - b));
    expect(ranked.map((c) => c.rank)).toEqual([1, 2, 3, 4]);
    expect(ranked[0]!.badges).toContain('CHEAPEST');
  });

  it('doğrulanmamış kart en ucuz olsa da önerilen olamaz', () => {
    const ranked = rankCards(scenario(), 245);
    const cheapest = ranked[0]!;
    expect(cheapest.airport.iata).toBe('LNZ');
    expect(cheapest.badges).not.toContain('RECOMMENDED');
    const recommended = ranked.filter((c) => c.badges.includes('RECOMMENDED'));
    expect(recommended).toHaveLength(1);
    expect(recommended[0]!.airport.iata).toBe('MUC');
    expect(recommended[0]!.reason).toBe('BEST_BALANCE');
  });

  it('en hızlı rozeti kapıdan kapıya en kısa karta', () => {
    const ranked = rankCards(scenario(), 245);
    const fastest = ranked.filter((c) => c.badges.includes('FASTEST'));
    expect(fastest).toHaveLength(1);
    expect(fastest[0]!.doorToDoorMin).toBe(Math.min(...ranked.map((c) => c.doorToDoorMin)));
  });

  it('tasarruf doğrudan uçuşa göre; pahalı kartta negatif', () => {
    const ranked = rankCards(scenario(), 150);
    expect(ranked.find((c) => c.airport.iata === 'MUC')!.savingsEur).toBe(150 - 162);
    expect(rankCards(scenario(), null)[0]!.savingsEur).toBeNull();
  });

  it('4 karttan fazlası puanla kırpılır, doğrudan uçuş her zaman kalır', () => {
    const cards = scenario();
    const extra = ['FMM', 'NUE', 'VIE'].map((iata) => {
      const c = cand(iata, 100, '2026-11-20T08:00:00+03:00');
      return viaCard(c, c.cheapest, ground(10, '2026-11-20T10:00:00Z', 60));
    });
    const all = [...cards, ...extra];
    for (const c of all) c.score = c.kind === 'DIRECT' ? 9999 : c.totalEur;
    const ranked = rankCards(all, 245);
    expect(ranked).toHaveLength(4);
    expect(ranked.some((c) => c.kind === 'DIRECT')).toBe(true);
  });

  it('gece beklemesi, dar aktarma ve ayrı bilet etiketleri', () => {
    const c = cand('MUC', 130, '2026-11-20T21:00:00+03:00'); // 21:50 UTC iniş (22:50 yerel)
    const card = viaCard(c, c.cheapest, ground(32, '2026-11-21T05:10:00Z', 132));
    expect(card.flags.has('OVERNIGHT_WAIT')).toBe(true);
    expect(card.flags.has('SEPARATE_TICKETS')).toBe(true);
    const tight = viaCard(c, c.cheapest, { ...ground(32, '2026-11-20T23:00:00Z', 60), waitMin: 70 });
    expect(tight.flags.has('TIGHT_CONNECTION')).toBe(true);
  });

  it('aynı havalimanının erken inen uçuşu aynı kara yolculuğunu kullanabilir', () => {
    const c = cand('MUC', 130, '2026-11-20T08:05:00+03:00');
    const base = viaCard(c, c.cheapest, ground(32, '2026-11-20T10:46:00Z', 132));
    const early = quote('MUC', 150, '2026-11-20T06:00:00+03:00', 170);
    const late = quote('MUC', 110, '2026-11-20T09:30:00+03:00', 170);
    expect(alternateFlightCard(base, early, 90)?.totalEur).toBe(182);
    expect(alternateFlightCard(base, late, 90)).toBeNull();
  });
});

describe('rezervasyon bağlantıları', async () => {
  const { flightLink, groundLinks, safeHttps } = await import('../src/search/booking.js');
  const { directCard } = await import('../src/search/rank.js');

  it('tanınmayan havayolunda Google Flights araması, ortaklık işareti yok', () => {
    const q = { ...quote('MUC', 130, '2026-11-20T08:05:00+03:00', 170), airline: 'ZZ', flightNumber: '9' };
    const link = flightLink(directCard(q, ap('MUC'), 0), '2026-11-20');
    expect(link.provider).toBe('Google Flights');
    const url = new URL(link.url);
    expect(url.hostname).toBe('www.google.com');
    expect(url.searchParams.get('q')).toBe('Flights from IST to MUC on 2026-11-20 one way');
    expect(link.url).not.toMatch(/marker|aviasales|travelpayouts/);
  });

  it('işletmeciye göre toplar, adresi olmayanı atlar, yalnızca https', () => {
    const leg = (operator: string | null, operatorUrl: string | null, line: string) => ({
      mode: 'RAIL', fromName: '', toName: '', from: { lat: 0, lon: 0 }, to: { lat: 0, lon: 0 }, startMs: 0, endMs: 0,
      line, operator, operatorUrl, priced: false,
    });
    const links = groundLinks([leg('ÖBB', 'http://www.oebb.at', 'RJX 69'), leg('ÖBB', 'http://www.oebb.at', 'REX 1'), leg('Stadtbus', null, '170')]);
    expect(links).toEqual([{ kind: 'GROUND', provider: 'ÖBB', url: 'https://www.oebb.at/', lines: ['RJX 69', 'REX 1'] }]);
    expect(safeHttps('javascript:alert(1)')).toBeNull();
    expect(safeHttps('www.flixbus.de')).toBe('https://www.flixbus.de/');
  });
});

describe('aktarma şehrinde konaklama', async () => {
  const { earliestGroundDepart } = await import('../src/search/ground.js');

  it('N gün konaklamada kara bacağı inişin yerel gününden N gün sonra 09:00\'da başlar', () => {
    const q = quote('MUC', 130, '2026-11-20T08:05:00+03:00', 170); // 07:55Z iniş
    expect(new Date(earliestGroundDepart(q, ap('MUC'), 'TR', 1)).toISOString()).toBe('2026-11-21T08:00:00.000Z');
    expect(new Date(earliestGroundDepart(q, ap('MUC'), 'TR', 2)).toISOString()).toBe('2026-11-22T08:00:00.000Z');
    // Konaklamasız: 90 dk tampon, 15 dakikaya yukarı
    expect(new Date(earliestGroundDepart(q, ap('MUC'), 'TR', 0)).toISOString()).toBe('2026-11-20T09:30:00.000Z');
  });

  it('konaklamalıda şehrin istasyonundan çıkar; dar aktarma ve gece etiketi almaz', async () => {
    const router = new FakeGround({ MUC: { waitMin: 10, durationMin: 132 } });
    const c: Candidate = { ...flights('MUC', 130), estimate: { roadKm: 150, hours: 2.75, costEur: 20 }, estimateScore: 150 };
    const stops = {
      nearestStop: async () => ({ id: 'airport-stop', name: '', lat: 0, lon: 0, modes: [] }),
      cityStation: async () => ({ id: 'muenchen-hbf', name: 'München Hbf', lat: 48.14, lon: 11.56, modes: ['LONG_DISTANCE'] }),
    };
    const cityNear = () => ({ name: 'Münih', lat: 48.1374, lon: 11.5755 });
    const r = await computeGround(c, salzburg, { maxGroundHours: 5, stopoverDays: 1, destStopId: 'salzburg-hbf' }, { router, fx: fakeFx, airports: ix.airports, stops, cityNear });
    const req = router.requests[0]!;
    expect(req.fromStopId).toBe('muenchen-hbf');
    expect(req.toStopId).toBe('salzburg-hbf');
    expect(new Date(req.earliestDepartMs).toISOString()).toBe('2026-11-21T08:00:00.000Z');
    if (r.status !== 'verified') throw new Error('doğrulanmalıydı');

    const card = viaCard(c, c.cheapest, r.ground, 1);
    expect(card.flags.has('STOPOVER')).toBe(true);
    expect(card.flags.has('TIGHT_CONNECTION')).toBe(false);
    expect(card.flags.has('OVERNIGHT_WAIT')).toBe(false);
    expect(card.stayMin).toBeGreaterThan(20 * 60);
  });

  it('konaklama süresi puana "fazla süre" olarak yansımaz', () => {
    const c: Candidate = { ...flights('MUC', 130), estimate: { roadKm: 0, hours: 0, costEur: 0 }, estimateScore: 0 };
    const g = (departIso: string): CardGround => ({
      departMs: Date.parse(departIso), arriveMs: Date.parse(departIso) + 132 * 60_000, waitMin: 0, transfers: 1,
      legs: [], fareEur: 32, estimatedEur: 0, fareSource: 'transitous', verified: true,
    });
    const sameDay = viaCard(c, c.cheapest, g('2026-11-20T10:46:00Z'), 0);
    const nextDay = viaCard(c, c.cheapest, g('2026-11-21T08:10:00Z'), 1);
    const direct = directCard(quote('SZG', 245, '2026-11-20T07:15:00+03:00', 385, { transfers: 1 }), ap('SZG'), 3);
    scoreCards([sameDay, nextDay, direct], direct.doorToDoorMin);
    expect(nextDay.extraMin).toBeLessThanOrEqual(sameDay.extraMin + 30);
    expect(nextDay.score).toBeLessThan(sameDay.score + 20);
  });
});

describe('havalimanından istasyona erişim', () => {
  const bgy = { lat: 45.6739, lon: 9.7042 };

  it('uzaktaki durağı adı, uzaklığı ve yürüme süresiyle verir', () => {
    const a = stationAccess(bgy, { name: 'Seriate', lat: 45.6853, lon: 9.7261 });
    expect(a?.stop).toBe('Seriate');
    expect(a!.distanceKm).toBeGreaterThan(1.5);
    expect(a!.distanceKm).toBeLessThan(2.5);
    expect(a!.walkMin).toBeGreaterThan(25);
  });

  it('yakındaki ya da adı havalimanı olan durağı yazmaz', () => {
    expect(stationAccess(bgy, { name: 'Orio', lat: 45.676, lon: 9.706 })).toBeUndefined();
    expect(stationAccess(bgy, { name: 'München Flughafen Terminal', lat: 45.69, lon: 9.73 })).toBeUndefined();
  });
});
