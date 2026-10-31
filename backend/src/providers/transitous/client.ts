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
 * `/api/v6/plan`, `/api/v1/geocode` ve `/api/v6/map/stops`.
 * Staging ya da iç uç nokta yok.
 *
 * Parametreler MOTIS 2.10.2 OpenAPI tanımından doğrulandı:
 *   • `RAIL` hızlı tren, şehirlerarası, gece treni, bölgesel, banliyö
 *     (S-Bahn) ve metroyu kapsar. Banliyö olmadan havalimanından şehre
 *     inen S-Bahn bulunamaz.
 *   • `timetableView` varsayılanında (true) bırakılır, 1 saatlik pencere ve
 *     en az 3 yolculuk istenir. Transitous ekibinin önerisi: `false` yalnızca
 *     en erken varışı arar, en geç kalkışı gözetmez ve kafa karıştırıcı
 *     sonuçlar verebilir. Pencere boşsa MOTIS en az 3 yolculuk bulana kadar
 *     aramayı genişletir; gece inişinde sabahki ilk sefer de böyle bulunur.
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

/** Şehrin ana istasyonunu ararken istenen ulaşım türleri. */
const STATION_MODES = 'HIGHSPEED_RAIL,LONG_DISTANCE,REGIONAL_RAIL,RAIL';

export interface StationMatch {
  id?: string;
  name?: string;
  lat?: number;
  lon?: number;
  modes?: string[];
  importance?: number;
}

/**
 * Şehrin ana istasyonu: 15 km içindeki eşleşmelerden "önemi" en yüksek
 * olan (MOTIS'in durak önem puanı; Hbf gibi büyük istasyonlar öne çıkar).
 */
export function pickCityStation(city: LatLon, matches: StationMatch[]): TransitStop | null {
  let best: { stop: TransitStop; importance: number } | null = null;
  for (const m of matches) {
    if (typeof m.id !== 'string' || typeof m.lat !== 'number' || typeof m.lon !== 'number') continue;
    const stop: TransitStop = { id: m.id, name: m.name ?? '', lat: m.lat, lon: m.lon, modes: m.modes ?? [] };
    if (haversineKm(city, stop) > 15) continue;
    const importance = m.importance ?? 0;
    if (!best || importance > best.importance) best = { stop, importance };
  }
  return best?.stop ?? null;
}

/**
 * Havalimanı için kullanılacak durak: 3 km içinde raylı sistemi olan en
 * yakın durak; yoksa 1,5 km içindeki en yakın durak; o da yoksa `null`
 * (koordinatla denenir). Raylı durak öncelikli, çünkü havalimanı
 * otobüsleri çoğu zaman yalnızca otoparka gider.
 */
export function pickAirportStop(point: LatLon, stops: TransitStop[]): TransitStop | null {
  const withDistance = stops
    // Yalnızca uçak türü olan "duraklar" elenir: bazı veri setleri
    // havalimanının kendisini durak olarak yayımlıyor (ör. Sardinya uçuş
    // verisindeki "Aeroporto di Nuernberg"). Ondan tren/otobüs kalkmaz.
    .filter((stop) => !(stop.modes.length > 0 && stop.modes.every((m) => m === 'AIRPLANE')))
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
  agencyUrl?: string;
  fareTransferIndex?: number;
}

interface RawItinerary {
  startTime?: string;
  endTime?: string;
  transfers?: number;
  legs?: RawLeg[];
  fareTransfers?: FareTransfer[];
}

/** Bundan kısa yürüyüşler yolculuk planında gösterilmez. */
const MIN_WALK_MIN = 3;

const STREET_MODES = new Set(['WALK', 'BIKE', 'CAR', 'RENTAL', 'CAR_PARKING', 'CAR_DROPOFF']);

export function mapItinerary(raw: RawItinerary): GroundItinerary | null {
  const startMs = raw.startTime ? parseInstant(raw.startTime) : null;
  const endMs = raw.endTime ? parseInstant(raw.endTime) : null;
  if (startMs === null || endMs === null) return null;

  const legs: GroundLegData[] = [];
  // Toplu taşıma bacakları arasındaki yürüyüş, sonraki bacağa yazılır.
  let walkMs = 0;
  for (const leg of raw.legs ?? []) {
    if (!leg.mode) continue;
    const s = leg.startTime ? parseInstant(leg.startTime) : null;
    const e = leg.endTime ? parseInstant(leg.endTime) : null;
    if (STREET_MODES.has(leg.mode)) {
      if (leg.mode === 'WALK' && s !== null && e !== null) walkMs += e - s;
      continue;
    }
    if (s === null || e === null) continue;
    const walkMin = Math.round(walkMs / 60_000);
    walkMs = 0;
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
      operatorUrl: leg.agencyUrl || null,
      priced: typeof leg.fareTransferIndex === 'number',
      ...(walkMin >= MIN_WALK_MIN ? { walkBeforeMin: walkMin } : {}),
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
      toPlace: request.toStopId ?? `${request.to.lat},${request.to.lon}`,
      time: new Date(request.earliestDepartMs).toISOString(),
      searchWindow: '3600',
      numItineraries: '3',
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

  /**
   * Havalimanının çevresindeki (~3 km) durakları `/api/v6/map/stops` ile
   * listeler ve aralarından en yakın raylı durağı seçer.
   *
   * Ters yer araması burada işe yaramıyordu: havalimanı noktasına en yakın
   * "duraklar" başka ülkelerin uçuş verilerindeki uçak durakları
   * (ör. "Aeroporto di Nuernberg"); ilk 20 sonucun içine U2 metro durağı
   * hiç girmiyordu. Bölge listesi tümünü getirir, seçim sonra yapılır.
   */
  async nearestStop(point: LatLon): Promise<TransitStop | null> {
    return this.cache.singleFlight(`stop:${coordKey(point)}`, STOP_TTL, async () => {
      const dLat = 0.03;
      const dLon = 0.045;
      const params = new URLSearchParams({
        min: `${point.lat - dLat},${point.lon - dLon}`,
        max: `${point.lat + dLat},${point.lon + dLon}`,
      });
      const places = await this.http.getJson<
        { stopId?: string; name?: string; lat?: number; lon?: number; modes?: string[] }[]
      >(`${this.baseUrl}/api/v6/map/stops?${params}`);
      const stops: TransitStop[] = (Array.isArray(places) ? places : [])
        .filter((m) => typeof m.stopId === 'string' && typeof m.lat === 'number' && typeof m.lon === 'number')
        .map((m) => ({ id: m.stopId!, name: m.name ?? '', lat: m.lat!, lon: m.lon!, modes: m.modes ?? [] }));
      return pickAirportStop(point, stops);
    });
  }

  async cityStation(city: LatLon & { name: string }): Promise<TransitStop | null> {
    return this.cache.singleFlight(`station:${coordKey(city)}`, STOP_TTL, async () => {
      const params = new URLSearchParams({
        text: city.name,
        type: 'STOP',
        mode: STATION_MODES,
        place: `${city.lat},${city.lon}`,
        placeBias: '3',
        numResults: '5',
      });
      const matches = await this.http.getJson<StationMatch[]>(`${this.baseUrl}/api/v1/geocode?${params}`);
      return pickCityStation(city, Array.isArray(matches) ? matches : []);
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
    const key = `plan:${request.fromStopId ?? coordKey(request.from)}:${request.toStopId ?? coordKey(request.to)}:${request.earliestDepartMs}:${request.maxTravelMinutes}`;
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
