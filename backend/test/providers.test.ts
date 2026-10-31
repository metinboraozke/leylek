import { describe, expect, it } from 'vitest';
import { CircuitBreaker, RequestBudget } from '../src/core/budget.js';
import { TtlCache } from '../src/core/cache.js';
import { UpstreamError } from '../src/core/errors.js';
import { HttpClient, type FetchFn } from '../src/core/http.js';
import { parseEcbXml } from '../src/providers/fx/ecb.js';
import {
  BudgetedGroundRouter,
  mapItinerary,
  pickAirportStop,
  pickCityStation,
  TransitousClient,
} from '../src/providers/transitous/client.js';
import { mapQuote, priceAgeDays, TravelpayoutsClient } from '../src/providers/travelpayouts/client.js';
import type { GroundRequest, GroundRouter } from '../src/search/ports.js';
import { NOW } from './helpers.js';

/** Gerçek ağa çıkmayan fetch: istenen URL'leri kaydeder. */
function fakeFetch(body: unknown, status = 200) {
  const urls: string[] = [];
  const headers: Record<string, string>[] = [];
  const fn = (async (input: string | URL | Request, init?: RequestInit) => {
    urls.push(String(input));
    headers.push((init?.headers ?? {}) as Record<string, string>);
    return new Response(typeof body === 'string' ? body : JSON.stringify(body), { status });
  }) as FetchFn;
  return { fn, urls, headers };
}

describe('Travelpayouts', () => {
  it('fiyat yaşını bağlantıdaki search_date alanından okur', () => {
    expect(priceAgeDays('/search/IST2011MUC1?t=x&search_date=20102026&expected_price=130', NOW)).toBe(2);
    expect(priceAgeDays(undefined, NOW)).toBeNull();
    expect(priceAgeDays('/search/x?t=1', NOW)).toBeNull();
  });

  it('iniş anını kalkış + duration_to ile hesaplar, bozuk kaydı atar', () => {
    const q = mapQuote(
      { price: 130, airline: 'tk', flight_number: 1629, departure_at: '2026-11-20T08:05:00+03:00', destination_airport: 'MUC', duration_to: 170, transfers: 0, link: '/x?search_date=21102026' },
      'IST',
      'MUC',
      NOW,
    );
    expect(q).toMatchObject({ airline: 'TK', flightNumber: '1629', priceEur: 130, priceAgeDays: 1 });
    expect(new Date(q!.arriveMs).toISOString()).toBe('2026-11-20T07:55:00.000Z');
    expect(mapQuote({ price: 0, departure_at: '2026-11-20T08:05:00+03:00', duration_to: 10 }, 'IST', 'MUC', NOW)).toBeNull();
  });

  it('one_way=true ile, ortaklık işareti olmadan sorar; sonucu önbellekler', async () => {
    const f = fakeFetch({
      data: [
        { price: 130, airline: 'TK', departure_at: '2026-11-20T08:05:00+03:00', destination_airport: 'MUC', duration_to: 170, link: '/x' },
        { price: 99, airline: 'XX', departure_at: '2026-11-21T08:05:00+03:00', destination_airport: 'MUC', duration_to: 170 },
      ],
    });
    const client = new TravelpayoutsClient(new HttpClient('tp', f.fn, 'Leylek/test'), 'tok', new TtlCache(), () => NOW);
    const quotes = await client.quotes('IST', 'MUC', '2026-11-20');
    await client.quotes('IST', 'MUC', '2026-11-20');

    expect(quotes).toHaveLength(1); // ertesi günün uçuşu süzülür
    expect(f.urls).toHaveLength(1);
    const url = new URL(f.urls[0]!);
    expect(url.searchParams.get('one_way')).toBe('true');
    expect(url.searchParams.get('departure_at')).toBe('2026-11-20');
    expect(url.searchParams.has('marker')).toBe(false);
  });

  it('token yoksa istek atmadan hata verir', async () => {
    const f = fakeFetch({});
    const client = new TravelpayoutsClient(new HttpClient('tp', f.fn, 'x'), '', new TtlCache());
    await expect(client.quotes('IST', 'MUC', '2026-11-20')).rejects.toBeInstanceOf(UpstreamError);
    expect(f.urls).toHaveLength(0);
  });
});

/** MOTIS 2 `/api/v6/plan` yanıtından kısaltılmış örnek. */
const PLAN_RESPONSE = {
  itineraries: [
    {
      startTime: '2026-11-20T10:46:00Z',
      endTime: '2026-11-20T12:58:00Z',
      duration: 7920,
      transfers: 1,
      legs: [
        { mode: 'WALK', from: { name: 'Start', lat: 48.3538, lon: 11.7861 }, to: { name: 'München Flughafen Terminal', lat: 48.353, lon: 11.785 }, startTime: '2026-11-20T10:40:00Z', endTime: '2026-11-20T10:46:00Z' },
        { mode: 'SUBURBAN', from: { name: 'München Flughafen Terminal', lat: 48.353, lon: 11.785 }, to: { name: 'München Hbf', lat: 48.14, lon: 11.56 }, startTime: '2026-11-20T10:46:00Z', endTime: '2026-11-20T11:27:00Z', routeShortName: 'S8', agencyName: 'MVV', fareTransferIndex: 0, effectiveFareLegIndex: 0 },
        { mode: 'REGIONAL_RAIL', from: { name: 'München Hbf', lat: 48.14, lon: 11.56 }, to: { name: 'Salzburg Hbf', lat: 47.813, lon: 13.046 }, startTime: '2026-11-20T11:35:00Z', endTime: '2026-11-20T12:58:00Z', displayName: 'RE 5', agencyName: 'BRB' },
      ],
      fareTransfers: [
        { effectiveFareLegProducts: [[[{ name: 'Einzelfahrt', amount: 13.6, currency: 'EUR', riderCategory: { riderCategoryName: 'Erwachsene', isDefaultFareCategory: true } }]]] },
      ],
    },
  ],
};

describe('Transitous', () => {
  it('yürüme bacaklarını atar, hat adını ve fiyatlı bacakları işaretler', () => {
    const itin = mapItinerary(PLAN_RESPONSE.itineraries[0]!)!;
    expect(itin.legs.map((l) => [l.mode, l.line, l.priced])).toEqual([
      ['SUBURBAN', 'S8', true],
      ['REGIONAL_RAIL', 'RE 5', false],
    ]);
    expect(itin.fares).toEqual([{ amount: 13.6, currency: 'EUR' }]);
    // Atılan yürüyüş, ardından binilen bacağa dakika olarak yazılır.
    expect(itin.legs.map((l) => l.walkBeforeMin)).toEqual([6, undefined]);
  });

  it('plan isteğini koşullara uygun parametre ve User-Agent ile atar', async () => {
    const f = fakeFetch(PLAN_RESPONSE);
    const client = new TransitousClient(new HttpClient('transitous', f.fn, 'Leylek/0.1.0 (+repo; a@b.c)'), 'https://api.transitous.org', new TtlCache());
    const result = await client.plan({
      from: { lat: 48.3538, lon: 11.7861 },
      to: { lat: 47.7994, lon: 13.044 },
      earliestDepartMs: Date.parse('2026-11-20T10:30:00Z'),
      maxTravelMinutes: 780,
    });
    expect(result).toHaveLength(1);
    const url = new URL(f.urls[0]!);
    expect(url.origin + url.pathname).toBe('https://api.transitous.org/api/v6/plan');
    expect(url.searchParams.get('transitModes')).toBe('RAIL,COACH,BUS,FERRY,TRAM');
    // Transitous önerisi: timetableView varsayılanında, 1 saatlik pencere
    expect(url.searchParams.has('timetableView')).toBe(false);
    expect(url.searchParams.get('searchWindow')).toBe('3600');
    expect(url.searchParams.get('numItineraries')).toBe('3');
    expect(url.searchParams.get('maxTransfers')).toBe('2');
    expect(url.searchParams.get('withFares')).toBe('true');
    expect(url.searchParams.get('time')).toBe('2026-11-20T10:30:00.000Z');
    expect(f.headers[0]!['user-agent']).toBe('Leylek/0.1.0 (+repo; a@b.c)');
  });

  it('bütçeli yönlendirici: önbellek, bütçe ve 429 sigortası', async () => {
    let calls = 0;
    let status: 'ok' | 'limited' = 'ok';
    const inner: GroundRouter = {
      plan: async () => {
        calls++;
        if (status === 'limited') throw new UpstreamError('transitous', 'rate_limited', '429', 429);
        return [];
      },
    };
    const breaker = new CircuitBreaker();
    const router = new BudgetedGroundRouter(inner, new TtlCache(), new RequestBudget(2, 100), breaker);
    const req = (i: number): GroundRequest => ({ from: { lat: 48 + i, lon: 11 }, to: { lat: 47.8, lon: 13 }, earliestDepartMs: 0, maxTravelMinutes: 780 });

    await router.plan(req(0));
    await router.plan(req(0)); // önbellekten
    expect(calls).toBe(1);

    await router.plan(req(1));
    await expect(router.plan(req(2))).rejects.toMatchObject({ kind: 'budget' });
    expect(calls).toBe(2);

    status = 'limited';
    const router2 = new BudgetedGroundRouter(inner, new TtlCache(), new RequestBudget(10, 100), breaker);
    await expect(router2.plan(req(3))).rejects.toMatchObject({ kind: 'rate_limited' });
    expect(breaker.isOpen()).toBe(true);
    await expect(router2.plan(req(4))).rejects.toMatchObject({ kind: 'budget' });
  });
});

describe('havalimanı durağı', () => {
  // Nürnberg: OurAirports noktası pistte, U2 durağı ~530 m güneyde
  const nue = { lat: 49.498699, lon: 11.078056 };
  const stop = (id: string, lat: number, lon: number, modes: string[]) => ({ id, name: id, lat, lon, modes });

  it('3 km içindeki raylı durağı yakındaki otobüs durağına tercih eder', () => {
    const picked = pickAirportStop(nue, [
      stop('kargo-bus', 49.49288, 11.083109, ['BUS']),
      stop('flughafen-u2', 49.49396, 11.078626, ['SUBWAY', 'BUS']),
    ]);
    expect(picked?.id).toBe('flughafen-u2');
  });

  it('yalnızca uçak türü olan durağı (havalimanının kendisi) seçmez', () => {
    const picked = pickAirportStop(nue, [
      stop('sardegna-NUE', 49.4987, 11.078, ['AIRPLANE']),
      stop('flughafen-u2', 49.49396, 11.078626, ['SUBWAY', 'BUS']),
    ]);
    expect(picked?.id).toBe('flughafen-u2');
    expect(pickAirportStop(nue, [stop('sardegna-NUE', 49.4987, 11.078, ['AIRPLANE'])])).toBeNull();
  });

  it('raylı yoksa 1,5 km içindeki en yakın durak, o da yoksa null', () => {
    expect(pickAirportStop(nue, [stop('bus', 49.4935, 11.08, ['BUS'])])?.id).toBe('bus');
    expect(pickAirportStop(nue, [stop('uzak', 49.45, 11.0, ['BUS'])])).toBeNull();
    expect(pickAirportStop(nue, [])).toBeNull();
  });

  it('bölgedeki durakları listeleyip seçer, önbelleğe alır ve plan isteğinde kullanır', async () => {
    const f = fakeFetch([
      { stopId: 'it-Sardegna-Planes-Cagliari-Airport_NUE', name: 'Aeroporto di Nuernberg (NUE)', lat: 49.4987, lon: 11.0781, modes: ['AIRPLANE'] },
      { stopId: 'de-DELFI_de:09564:1391', name: 'Nürnberg Flughafen', lat: 49.49396, lon: 11.078626, modes: ['SUBWAY', 'BUS'] },
    ]);
    const client = new TransitousClient(new HttpClient('transitous', f.fn, 'x'), 'https://api.transitous.org', new TtlCache());
    const found = await client.nearestStop(nue);
    await client.nearestStop(nue);
    expect(found?.id).toBe('de-DELFI_de:09564:1391');
    expect(f.urls).toHaveLength(1);
    expect(new URL(f.urls[0]!).pathname).toBe('/api/v6/map/stops');

    const g = fakeFetch({ itineraries: [] });
    const planner = new TransitousClient(new HttpClient('transitous', g.fn, 'x'), 'https://api.transitous.org', new TtlCache());
    await planner.plan({ from: nue, fromStopId: found!.id, to: { lat: 47.8, lon: 13.04 }, earliestDepartMs: 0, maxTravelMinutes: 780 });
    expect(new URL(g.urls[0]!).searchParams.get('fromPlace')).toBe('de-DELFI_de:09564:1391');
  });
});

describe('ECB kurları', () => {
  it('XML içinden kurları okur', () => {
    const rates = parseEcbXml("<Cube currency='USD' rate='1.0812'/><Cube currency='TRY' rate='44.1205'/>");
    expect(rates.get('TRY')).toBe(44.1205);
    expect(rates.get('EUR')).toBe(1);
  });
});

describe('şehrin ana istasyonu', () => {
  const salzburg = { lat: 47.7994, lon: 13.044, name: 'Salzburg' };

  it('15 km içindeki en önemli istasyonu seçer', () => {
    const picked = pickCityStation(salzburg, [
      { id: 'sud', name: 'Salzburg Süd', lat: 47.78, lon: 13.07, modes: ['REGIONAL_RAIL'], importance: 0.3 },
      { id: 'hbf', name: 'Salzburg Hbf', lat: 47.813, lon: 13.0451, modes: ['LONG_DISTANCE'], importance: 0.9 },
      { id: 'uzak', name: 'Freilassing', lat: 47.84, lon: 12.98, modes: ['REGIONAL_RAIL'], importance: 0.95 },
      { id: 'cok-uzak', name: 'Linz Hbf', lat: 48.29, lon: 14.29, modes: ['LONG_DISTANCE'], importance: 1 },
    ]);
    // Freilassing ~6 km: 15 km içinde ve daha önemli görünse de Salzburg Hbf'den
    // önce gelir; bu testte önemi bilerek yüksek verildi.
    expect(picked?.id).toBe('uzak');
    expect(pickCityStation(salzburg, [])).toBeNull();
  });

  it('ad, tren türü ve konum eğilimiyle arar; sonucu önbellekler', async () => {
    const f = fakeFetch([{ id: 'at:Hbf', name: 'Salzburg Hbf', lat: 47.813, lon: 13.0451, importance: 0.9 }]);
    const client = new TransitousClient(new HttpClient('transitous', f.fn, 'x'), 'https://api.transitous.org', new TtlCache());
    expect((await client.cityStation(salzburg))?.id).toBe('at:Hbf');
    await client.cityStation(salzburg);
    expect(f.urls).toHaveLength(1);
    const url = new URL(f.urls[0]!);
    expect(url.pathname).toBe('/api/v1/geocode');
    expect(url.searchParams.get('type')).toBe('STOP');
    expect(url.searchParams.get('mode')).toContain('LONG_DISTANCE');
  });

  it('plan isteğinde varış durak kimliğiyle gider', async () => {
    const f = fakeFetch({ itineraries: [] });
    const client = new TransitousClient(new HttpClient('transitous', f.fn, 'x'), 'https://api.transitous.org', new TtlCache());
    await client.plan({ from: { lat: 48.35, lon: 11.79 }, to: salzburg, toStopId: 'at:Hbf', earliestDepartMs: 0, maxTravelMinutes: 780 });
    expect(new URL(f.urls[0]!).searchParams.get('toPlace')).toBe('at:Hbf');
  });
});
