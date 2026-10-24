import { TtlCache } from '../src/core/cache.js';
import { buildIndexes } from '../src/data/dataset.js';
import type { Airport, City, Dataset } from '../src/data/types.js';
import { normalize } from '../src/core/text.js';
import type {
  FlightPriceSource,
  FlightQuote,
  FxRates,
  Geocoder,
  GroundItinerary,
  GroundRequest,
  GroundRouter,
} from '../src/search/ports.js';
import { SearchService } from '../src/search/pipeline.js';

/** Testlerde kullanılan küçük, gerçek koordinatlı veri kümesi. */
const airport = (
  iata: string,
  lat: number,
  lon: number,
  country: string,
  tz: string,
  municipality: string,
  cityCode = iata,
  size: Airport['size'] = 'large',
): Airport => ({ iata, name: `${municipality} Airport`, lat, lon, country, tz, municipality, cityCode, size });

export const AIRPORTS: Airport[] = [
  airport('IST', 41.2753, 28.7519, 'TR', 'Europe/Istanbul', 'Istanbul'),
  airport('SAW', 40.8986, 29.3092, 'TR', 'Europe/Istanbul', 'Pendik, Istanbul', 'IST'),
  airport('MUC', 48.3538, 11.7861, 'DE', 'Europe/Berlin', 'Munich'),
  airport('SZG', 47.7933, 13.0043, 'AT', 'Europe/Vienna', 'Salzburg'),
  airport('INN', 47.2602, 11.344, 'AT', 'Europe/Vienna', 'Innsbruck'),
  airport('LNZ', 48.2332, 14.1875, 'AT', 'Europe/Vienna', 'Linz', 'LNZ', 'medium'),
  airport('FMM', 47.9888, 10.2395, 'DE', 'Europe/Berlin', 'Memmingen', 'FMM', 'medium'),
  airport('NUE', 49.4987, 11.078, 'DE', 'Europe/Berlin', 'Nuremberg'),
  airport('VIE', 48.1103, 16.5697, 'AT', 'Europe/Vienna', 'Vienna'),
];

const city = (id: string, name: string, lat: number, lon: number, country: string, population: number, tz: string, alts: string[] = []): City => ({
  id,
  name,
  lat,
  lon,
  country,
  population,
  tz,
  keys: [...new Set([name, ...alts].map(normalize))],
});

export const CITIES: City[] = [
  city('745044', 'İstanbul', 41.0138, 28.9497, 'TR', 14_804_116, 'Europe/Istanbul', ['Istanbul', 'Constantinople']),
  city('2766824', 'Salzburg', 47.7994, 13.044, 'AT', 145_871, 'Europe/Vienna'),
  city('2867714', 'Münih', 48.1374, 11.5755, 'DE', 1_260_391, 'Europe/Berlin', ['Munich', 'München']),
  city('2775220', 'Innsbruck', 47.2627, 11.3945, 'AT', 112_467, 'Europe/Vienna'),
  city('2772400', 'Linz', 48.3064, 14.2861, 'AT', 181_162, 'Europe/Vienna'),
  city('2761369', 'Viyana', 48.2085, 16.3721, 'AT', 1_691_468, 'Europe/Vienna', ['Vienna', 'Wien']),
  city('323786', 'Ankara', 39.9199, 32.8543, 'TR', 3_517_182, 'Europe/Istanbul'),
];

export const DATASET: Dataset = { airports: AIRPORTS, cities: CITIES, generatedAt: '2026-10-22T00:00:00.000Z' };
export const indexes = () => buildIndexes(DATASET);

export const NOW = Date.parse('2026-10-22T10:00:00Z');
export const DAY = '2026-11-20';

/** Travelpayouts biçiminde uçuş (EUR). */
export function quote(
  dest: string,
  priceEur: number,
  departIso: string,
  durationMin: number,
  opts: { origin?: string; transfers?: number; ageDays?: number | null } = {},
): FlightQuote {
  const departMs = Date.parse(departIso);
  return {
    originAirport: opts.origin ?? 'IST',
    destAirport: dest,
    departIso,
    departMs,
    arriveMs: departMs + durationMin * 60_000,
    priceEur,
    airline: 'TK',
    flightNumber: '1',
    transfers: opts.transfers ?? 0,
    priceAgeDays: opts.ageDays === undefined ? 1 : opts.ageDays,
  };
}

export class FakeFlights implements FlightPriceSource {
  calls: string[] = [];
  constructor(private readonly byDest: Record<string, FlightQuote[]>, private readonly fail = false) {}
  async quotes(origin: string, dest: string): Promise<FlightQuote[]> {
    this.calls.push(`${origin}-${dest}`);
    if (this.fail) throw new Error('token yok');
    return this.byDest[dest] ?? [];
  }
}

/**
 * Sahte Transitous: havalimanı koordinatına göre yolculuk üretir. İstenen
 * andan `waitMin` sonra kalkar, `durationMin` sürer.
 */
export class FakeGround implements GroundRouter {
  requests: GroundRequest[] = [];
  constructor(
    private readonly routes: Record<
      string,
      { waitMin: number; durationMin: number; fares?: { amount: number; currency: string }[]; priced?: boolean; fail?: boolean; none?: boolean; mode?: string }
    >,
  ) {}
  async plan(request: GroundRequest): Promise<GroundItinerary[]> {
    this.requests.push(request);
    const iata = AIRPORTS.find((a) => a.lat === request.from.lat && a.lon === request.from.lon)?.iata ?? '?';
    const r = this.routes[iata];
    if (!r || r.none) return [];
    if (r.fail) throw new Error('transitous 500');
    const startMs = request.earliestDepartMs + r.waitMin * 60_000;
    const endMs = startMs + r.durationMin * 60_000;
    const mid = startMs + (r.durationMin / 2) * 60_000;
    return [
      {
        startMs,
        endMs,
        transfers: 1,
        fares: r.fares ?? [],
        legs: [
          { mode: 'SUBURBAN', fromName: `${iata} Flughafen`, toName: 'Hbf', from: request.from, to: { lat: (request.from.lat + request.to.lat) / 2, lon: (request.from.lon + request.to.lon) / 2 }, startMs, endMs: mid, line: 'S8', operator: 'MVV', priced: r.priced ?? false },
          { mode: r.mode ?? 'REGIONAL_RAIL', fromName: 'Hbf', toName: 'Salzburg Hbf', from: { lat: (request.from.lat + request.to.lat) / 2, lon: (request.from.lon + request.to.lon) / 2 }, to: request.to, startMs: mid, endMs, line: 'RE 5', operator: 'BRB', priced: r.priced ?? false },
        ],
      },
    ];
  }
}

export const fakeFx: FxRates = { perEur: async (c) => (c === 'TRY' ? 40 : 1) };
export const fakeGeocoder: Geocoder = { geocode: async () => null };

export function service(flights: FlightPriceSource, ground: GroundRouter) {
  const ix = indexes();
  return new SearchService({
    indexes: () => ix,
    flights,
    ground,
    geocoder: fakeGeocoder,
    fx: fakeFx,
    cache: new TtlCache(),
    now: () => NOW,
  });
}

/** İstanbul → Salzburg senaryosu: SZG doğrudan pahalı, MUC ve INN ucuz. */
export function salzburgFlights(): Record<string, FlightQuote[]> {
  return {
    SZG: [quote('SZG', 245, '2026-11-20T07:15:00+03:00', 385, { transfers: 1 })],
    MUC: [
      quote('MUC', 130, '2026-11-20T08:05:00+03:00', 170),
      quote('MUC', 150, '2026-11-20T06:00:00+03:00', 170),
    ],
    INN: [quote('INN', 152, '2026-11-20T10:20:00+03:00', 165)],
    LNZ: [quote('LNZ', 210, '2026-11-20T09:00:00+03:00', 200, { transfers: 1 })],
    NUE: [quote('NUE', 140, '2026-11-20T12:00:00+03:00', 175)],
    FMM: [quote('FMM', 90, '2026-11-20T13:00:00+03:00', 180)],
  };
}
