import { createServer, type IncomingMessage, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import { haversineKm } from '../../src/core/geo.js';

/**
 * Uçtan uca testler için sahte dış servisler: Travelpayouts, Transitous ve
 * ECB tek bir yerel HTTP sunucusunda. Backend gerçek HTTP istemcileriyle
 * buraya bağlanır; böylece istek kurma, yanıt okuma, önbellek ve yanıt
 * sözleşmesi ağa çıkmadan sınanır.
 *
 * Sunucu gelen istekleri kaydeder: testler User-Agent'ı, parametreleri ve
 * istek sayılarını (önbellek, Transitous bütçesi) buradan denetler.
 */

export interface RecordedRequest {
  path: string;
  query: URLSearchParams;
  userAgent: string;
}

export interface MockUpstreams {
  baseUrl: string;
  requests: RecordedRequest[];
  count(path: string): number;
  close(): Promise<void>;
}

/** İstanbul'dan uçuş verisi olan varış kodları: (kalkış saati +03, süre dk, fiyat €, aktarma). */
const FLIGHTS: Record<string, [string, number, number, number]> = {
  SZG: ['07:15', 385, 245, 1],
  MUC: ['08:05', 170, 130, 0],
  INN: ['10:20', 165, 152, 0],
  NUE: ['12:00', 175, 140, 0],
  LNZ: ['09:00', 200, 210, 1],
  FMM: ['13:00', 180, 90, 0],
};

/** Durak kimliğine koordinat gömülür: plan isteği nereden kalktığını bilsin. */
const stopId = (kind: string, lat: number, lon: number) => `${kind}:${lat.toFixed(4)}:${lon.toFixed(4)}`;

function placeOf(raw: string): { lat: number; lon: number } {
  const parts = raw.split(':');
  if (parts.length === 3) return { lat: Number(parts[1]), lon: Number(parts[2]) };
  const [lat, lon] = raw.split(',').map(Number);
  return { lat: lat ?? 0, lon: lon ?? 0 };
}

function flights(query: URLSearchParams) {
  const dest = query.get('destination') ?? '';
  const day = query.get('departure_at') ?? '';
  const f = FLIGHTS[dest];
  if (!f || query.get('one_way') !== 'true') return { success: true, data: [] };
  const [time, duration, price, transfers] = f;
  // Fiyatın yaşı bağlantıdaki search_date'ten okunur (1 gün önce).
  const seen = new Date(Date.now() - 86_400_000);
  const searchDate = `${String(seen.getUTCDate()).padStart(2, '0')}${String(seen.getUTCMonth() + 1).padStart(2, '0')}${seen.getUTCFullYear()}`;
  return {
    success: true,
    data: [
      {
        origin: 'IST',
        destination: dest,
        origin_airport: 'IST',
        destination_airport: dest,
        price,
        airline: 'TK',
        flight_number: 1000 + price,
        departure_at: `${day}T${time}:00+03:00`,
        transfers,
        duration_to: duration,
        link: `/search/IST${dest}1?t=e2e&search_date=${searchDate}&marker=SHOULD_NOT_LEAK`,
      },
    ],
  };
}

function plan(query: URLSearchParams) {
  const from = placeOf(query.get('fromPlace') ?? '0,0');
  const to = placeOf(query.get('toPlace') ?? '0,0');
  const time = Date.parse(query.get('time') ?? '');
  const km = haversineKm(from, to);
  if (!Number.isFinite(time) || km > 400) return { itineraries: [] };
  const start = time + 10 * 60_000;
  const firstLeg = 25 * 60_000;
  const secondLeg = Math.round(km * 0.75 + 20) * 60_000;
  const mid = { lat: (from.lat + to.lat) / 2, lon: (from.lon + to.lon) / 2 };
  const iso = (ms: number) => new Date(ms).toISOString();
  return {
    itineraries: [
      {
        startTime: iso(start),
        endTime: iso(start + firstLeg + 5 * 60_000 + secondLeg),
        transfers: 1,
        legs: [
          { mode: 'SUBURBAN', from: { name: 'Flughafen', ...from }, to: { name: 'Hauptbahnhof', ...mid }, startTime: iso(start), endTime: iso(start + firstLeg), routeShortName: 'S1', agencyName: 'Örnek S-Bahn', agencyUrl: 'https://www.example-sbahn.test', fareTransferIndex: 0 },
          { mode: 'REGIONAL_RAIL', from: { name: 'Hauptbahnhof', ...mid }, to: { name: 'Zielbahnhof', ...to }, startTime: iso(start + firstLeg + 5 * 60_000), endTime: iso(start + firstLeg + 5 * 60_000 + secondLeg), routeShortName: 'RE 1', agencyName: 'Örnek Bahn', agencyUrl: 'http://www.example-bahn.test' },
        ],
        fareTransfers: [{ effectiveFareLegProducts: [[[{ name: 'Einzel', amount: 4.5, currency: 'EUR', riderCategory: { isDefaultFareCategory: true } }]]] }],
      },
    ],
  };
}

function route(path: string, query: URLSearchParams): { status: number; body: unknown; type?: string } {
  switch (path) {
    case '/aviasales/v3/prices_for_dates':
      return { status: 200, body: flights(query) };
    case '/api/v6/map/stops': {
      const [minLat, minLon] = (query.get('min') ?? '0,0').split(',').map(Number);
      const [maxLat, maxLon] = (query.get('max') ?? '0,0').split(',').map(Number);
      const lat = ((minLat ?? 0) + (maxLat ?? 0)) / 2 - 0.004;
      const lon = ((minLon ?? 0) + (maxLon ?? 0)) / 2;
      return {
        status: 200,
        body: [
          // Gerçekte de görülen tuzak: havalimanının kendisi uçak durağı olarak.
          { stopId: stopId('plane', lat + 0.004, lon), name: 'Airport (plane feed)', lat: lat + 0.004, lon, modes: ['AIRPLANE'] },
          { stopId: stopId('airport', lat, lon), name: 'Flughafen', lat, lon, modes: ['SUBURBAN', 'BUS'] },
        ],
      };
    }
    case '/api/v1/geocode': {
      if (query.get('type') !== 'STOP') return { status: 200, body: [] };
      const [lat, lon] = (query.get('place') ?? '0,0').split(',').map(Number);
      return {
        status: 200,
        body: [{ id: stopId('station', lat ?? 0, lon ?? 0), name: `${query.get('text')} Hbf`, lat, lon, importance: 0.9, modes: ['LONG_DISTANCE'] }],
      };
    }
    case '/api/v6/plan':
      return { status: 200, body: plan(query) };
    case '/eurofxref-daily.xml':
      return {
        status: 200,
        type: 'application/xml',
        body: "<Cube><Cube time='2026-10-27'><Cube currency='USD' rate='1.08'/><Cube currency='TRY' rate='44.0'/></Cube></Cube>",
      };
    default:
      return { status: 404, body: { error: 'bilinmeyen yol' } };
  }
}

export async function startMockUpstreams(): Promise<MockUpstreams> {
  const requests: RecordedRequest[] = [];
  const server: Server = createServer((req: IncomingMessage, res) => {
    const url = new URL(req.url ?? '/', 'http://localhost');
    requests.push({ path: url.pathname, query: url.searchParams, userAgent: String(req.headers['user-agent'] ?? '') });
    const out = route(url.pathname, url.searchParams);
    res.writeHead(out.status, { 'content-type': out.type ?? 'application/json' });
    res.end(typeof out.body === 'string' ? out.body : JSON.stringify(out.body));
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address() as AddressInfo;
  return {
    baseUrl: `http://127.0.0.1:${port}`,
    requests,
    count: (path) => requests.filter((r) => r.path === path).length,
    close: () => new Promise((resolve) => server.close(() => resolve())),
  };
}
