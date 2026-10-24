import { coordKey, haversineKm, type LatLon } from '../../core/geo.js';
import { DAY, HOUR, MINUTE, TtlCache } from '../../core/cache.js';
import { UpstreamError } from '../../core/errors.js';
import type { HttpClient } from '../../core/http.js';
import { parseInstant } from '../../core/time.js';
import type {
  Geocoder,
  GroundItinerary,
  GroundLegData,
  GroundRequest,
  GroundRouter,
  Price,
  StopLocator,
  TransitStop,
} from '../../search/ports.js';
import { transferPrices, type FareTransfer } from './fares.js';

/**
 * Transitous (MOTIS 2) istemcisi. Yalnızca herkese açık API:
 * `/api/v6/plan`, `/api/v1/geocode` ve `/api/v1/reverse-geocode`.
 * Staging ya da iç uç nokta yok.
 *
 * Parametreler MOTIS 2.10.2 OpenAPI tanımından doğrulandı:
 *   • `RAIL` hızlı tren, şehirlerarası, gece treni, bölgesel, banliyö
 *     (S-Bahn) ve metroyu kapsar. Banliyö olmadan havalimanından şehre
 *     inen S-Bahn bulunamaz.
 *   • `timetableView=false`: verilen andan sonra en erken varan yolculuk;
 *     bekleme yolculuğa sayılır. Varsayılan arama penceresi yalnızca
 *     15 dakika olduğu için gece inişinde sabahki ilk sefer de böyle bulunur.
 */
export const TRANSIT_MODES = 'RAIL,COACH,BUS,FERRY,TRAM';
const PLAN_TTL = 6 * HOUR;
const PLAN_ERROR_TTL = 10 * MINUTE;
const GEOCODE_TTL = 30 * DAY;
const STOP_TTL = 30 * DAY;

const RAIL_MODES = new Set([
  'RAIL', 'SUBWAY', 'SUBURBAN', 'REGIONAL_RAIL', 'REGIONAL_FAST_RAIL',
  'LONG_DISTANCE', 'HIGHSPEED_RAIL', 'NIGHT_RAIL', 'METRO', 'TRAM',
]);

/**
 * Havalimanı için kullanılacak durak: 3 km içinde raylı sistemi olan en
 * yakın durak; yoksa 1,5 km içindeki en yakın durak; o da yoksa `null`
 * (koordinatla denenir). Raylı durak öncelikli, çünkü havalimanı
 * otobüsleri çoğu zaman yalnızca otoparka gider.
 */
export function pickAirportStop(point: LatLon, stops: TransitStop[]): TransitStop | null {
  const withDistance = stops
    .map((stop) => ({ stop, km: haversineKm(point, stop) }))
    .sort((a, b) => a.km - b.km);
  const rail = withDistance.find((s) => s.km <= 3 && s.stop.modes.some((m) => RAIL_MODES.has(m)));
  if (rail) return rail.stop;
  return withDistance.find((s) => s.km <= 1.5)?.stop ?? null;
}

interface RawPlace {
  name?: string;
  lat?: number;
  lon?: number;
}

interface RawLeg {
  mode?: string;
  from?: RawPlace;
  to?: RawPlace;
  startTime?: string;
  endTime?: string;
  routeShortName?: string;
  displayName?: string;
  tripShortName?: string;
  agencyName?: string;
  fareTransferIndex?: number;
}

interface RawItinerary {
  startTime?: string;
  endTime?: string;
  transfers?: number;
  legs?: RawLeg[];
  fareTransfers?: FareTransfer[];
}

const STREET_MODES = new Set(['WALK', 'BIKE', 'CAR', 'RENTAL', 'CAR_PARKING', 'CAR_DROPOFF']);

export function mapItinerary(raw: RawItinerary): GroundItinerary | null {
  const startMs = raw.startTime ? parseInstant(raw.startTime) : null;
  const endMs = raw.endTime ? parseInstant(raw.endTime) : null;
  if (startMs === null || endMs === null) return null;

  const legs: GroundLegData[] = [];
  for (const leg of raw.legs ?? []) {
    if (!leg.mode || STREET_MODES.has(leg.mode)) continue;
    const s = leg.startTime ? parseInstant(leg.startTime) : null;
    const e = leg.endTime ? parseInstant(leg.endTime) : null;
    if (s === null || e === null) continue;
    legs.push({
      mode: leg.mode,
      fromName: leg.from?.name ?? '',
      toName: leg.to?.name ?? '',
      from: { lat: leg.from?.lat ?? 0, lon: leg.from?.lon ?? 0 },
      to: { lat: leg.to?.lat ?? 0, lon: leg.to?.lon ?? 0 },
      startMs: s,
      endMs: e,
      line: leg.routeShortName || leg.displayName || leg.tripShortName || null,
      operator: leg.agencyName || null,
      priced: typeof leg.fareTransferIndex === 'number',
    });
  }

  const fares: Price[] = [];
  for (const transfer of raw.fareTransfers ?? []) {
    const prices = transferPrices(transfer);
    if (prices) fares.push(...prices);
  }
  // Bir ücret grubu çözülemediyse o grubun bacaklarını fiyatsız say.
  const resolved = (raw.fareTransfers ?? []).map((t) => transferPrices(t) !== null);
  let i = 0;
  for (const leg of raw.legs ?? []) {
    if (!leg.mode || STREET_MODES.has(leg.mode)) continue;
    const mapped = legs[i++];
    if (mapped && typeof leg.fareTransferIndex === 'number' && !resolved[leg.fareTransferIndex]) {
      mapped.priced = false;
    }
  }

  return { startMs, endMs, transfers: raw.transfers ?? Math.max(0, legs.length - 1), legs, fares };
}

export class TransitousClient implements GroundRouter, Geocoder, StopLocator {
  constructor(
    private readonly http: HttpClient,
    private readonly baseUrl: string,
    private readonly cache: TtlCache,
  ) {}

  /** Ham istek; önbellek ve bütçe dışarıda (bkz. BudgetedGroundRouter). */
  async plan(request: GroundRequest): Promise<GroundItinerary[]> {
    const params = new URLSearchParams({
      fromPlace: request.fromStopId ?? `${request.from.lat},${request.from.lon}`,
      toPlace: `${request.to.lat},${request.to.lon}`,
      time: new Date(request.earliestDepartMs).toISOString(),
      timetableView: 'false',
      transitModes: TRANSIT_MODES,
      maxTransfers: '2',
      maxTravelTime: String(request.maxTravelMinutes),
      maxPreTransitTime: '1200',
      maxPostTransitTime: '1200',
      withFares: 'true',
      language: 'tr',
    });
    const body = await this.http.getJson<{ itineraries?: RawItinerary[] }>(
      `${this.baseUrl}/api/v6/plan?${params}`,
    );
    return (body.itineraries ?? []).map(mapItinerary).filter((x): x is GroundItinerary => x !== null);
  }

  async nearestStop(point: LatLon): Promise<TransitStop | null> {
    return this.cache.singleFlight(`stop:${coordKey(point)}`, STOP_TTL, async () => {
      const params = new URLSearchParams({ place: `${point.lat},${point.lon}`, type: 'STOP', numResults: '10' });
      const matches = await this.http.getJson<
        { id?: string; name?: string; lat?: number; lon?: number; modes?: string[] }[]
      >(`${this.baseUrl}/api/v1/reverse-geocode?${params}`);
      const stops: TransitStop[] = (Array.isArray(matches) ? matches : [])
        .filter((m) => typeof m.id === 'string' && typeof m.lat === 'number' && typeof m.lon === 'number')
        .map((m) => ({ id: m.id!, name: m.name ?? '', lat: m.lat!, lon: m.lon!, modes: m.modes ?? [] }));
      return pickAirportStop(point, stops);
    });
  }

  async geocode(text: string) {
    const key = `geo:${text.toLowerCase()}`;
    return this.cache.singleFlight(key, GEOCODE_TTL, async () => {
      const params = new URLSearchParams({ text, type: 'PLACE', numResults: '3', language: 'tr,en' });
      const matches = await this.http.getJson<
        { name?: string; lat?: number; lon?: number; country?: string }[]
      >(`${this.baseUrl}/api/v1/geocode?${params}`);
      const best = Array.isArray(matches) ? matches[0] : undefined;
      if (!best || typeof best.lat !== 'number' || typeof best.lon !== 'number') return null;
      return { name: best.name ?? text, lat: best.lat, lon: best.lon, country: best.country ?? '' };
    });
  }
}

/**
 * Önbellek + bütçe + sigorta katmanı (dekoratör).
 *
 * Asıl istemciye dokunmadan eklenir (OCP). Bütçe biter ya da sigorta
 * açıksa `UpstreamError('budget')` fırlatır; arama hattı bunu yakalayıp
 * o adayı "doğrulanamadı" olarak işaretler.
 */
export class BudgetedGroundRouter implements GroundRouter {
  calls = 0;

  constructor(
    private readonly inner: GroundRouter,
    private readonly cache: TtlCache,
    private readonly budget: { tryTake(): boolean },
    private readonly breaker: { isOpen(): boolean; recordSuccess(): void; recordFailure(rateLimited?: boolean): void },
  ) {}

  plan(request: GroundRequest): Promise<GroundItinerary[]> {
    const key = `plan:${request.fromStopId ?? coordKey(request.from)}:${coordKey(request.to)}:${request.earliestDepartMs}:${request.maxTravelMinutes}`;
    return this.cache.singleFlight(
      key,
      PLAN_TTL,
      async () => {
        if (this.breaker.isOpen()) throw new UpstreamError('transitous', 'budget', 'Sigorta açık');
        if (!this.budget.tryTake()) throw new UpstreamError('transitous', 'budget', 'Bütçe doldu');
        this.calls++;
        try {
          const result = await this.inner.plan(request);
          this.breaker.recordSuccess();
          return result;
        } catch (error) {
          this.breaker.recordFailure(error instanceof UpstreamError && error.kind === 'rate_limited');
          throw error;
        }
      },
      { errorTtlMs: PLAN_ERROR_TTL },
    );
  }
}
