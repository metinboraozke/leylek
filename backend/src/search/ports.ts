import type { LatLon } from '../core/geo.js';

/**
 * Arama hattının dış dünyaya açılan kapıları.
 *
 * Hat bu arayüzlere bağlıdır, somut istemcilere değil (DIP). Testte sahte
 * uygulamalar verilir; Transitous'u kendi MOTIS sunucumuzla değiştirmek
 * (F4) yalnızca bir uygulamayı değiştirmek demek.
 */

/** Travelpayouts'tan gelen tek yön uçuş, EUR. */
export interface FlightQuote {
  originAirport: string;
  destAirport: string;
  /** Sağlayıcının verdiği, kalkış yerinin ofsetiyle ISO metin. */
  departIso: string;
  departMs: number;
  arriveMs: number;
  priceEur: number;
  airline: string;
  flightNumber: string | null;
  transfers: number;
  /** Fiyatın kaç gün önce görüldüğü; bilinmiyorsa `null`. */
  priceAgeDays: number | null;
}

export interface FlightPriceSource {
  /** `originCode` → `destCode` için o günün en ucuz tek yön uçuşları. */
  quotes(originCode: string, destCode: string, day: string): Promise<FlightQuote[]>;
}

export interface GroundRequest {
  from: LatLon;
  /**
   * Varsa koordinat yerine bu durak kimliğinden başlanır. Havalimanı
   * koordinatı çoğu zaman pistin ortasına düşer ve oradan yürüme yolu
   * bulunamaz (bkz. StopLocator).
   */
  fromStopId?: string;
  to: LatLon;
  /** Bu andan sonra kalkan yolculuklar (UTC ms). */
  earliestDepartMs: number;
  maxTravelMinutes: number;
}

export interface Price {
  amount: number;
  currency: string;
}

export interface GroundLegData {
  mode: string;
  fromName: string;
  toName: string;
  from: LatLon;
  to: LatLon;
  startMs: number;
  endMs: number;
  line: string | null;
  operator: string | null;
  /** İşletmecinin sitesi (Transitous `agencyUrl`); rezervasyon kartı için. */
  operatorUrl: string | null;
  /** Bu bacağın fiyatı bir ücret grubunda var mı. */
  priced: boolean;
}

export interface GroundItinerary {
  startMs: number;
  endMs: number;
  transfers: number;
  /** Yalnızca toplu taşıma bacakları (yürüme hariç). */
  legs: GroundLegData[];
  /** Bilinen ücret ürünleri; hiç yoksa boş. */
  fares: Price[];
}

export interface GroundRouter {
  /** Hata durumunda `UpstreamError` fırlatır. */
  plan(request: GroundRequest): Promise<GroundItinerary[]>;
}

export interface TransitStop extends LatLon {
  id: string;
  name: string;
  modes: string[];
}

/**
 * Bir havalimanının toplu taşıma durağını bulur.
 *
 * OurAirports koordinatı havalimanının referans noktasıdır (genelde pist
 * ortası). Transitous bu noktadan terminale yürüme yolu bulamayınca hiç
 * yolculuk döndürmüyor: Nürnberg ve Memmingen canlı denemede bu yüzden
 * "bağlantı yok" çıktı. Durak kimliğiyle aynı istek sonuç veriyor.
 */
export interface StopLocator {
  nearestStop(point: LatLon): Promise<TransitStop | null>;
}

export interface Geocoder {
  geocode(text: string): Promise<{ name: string; lat: number; lon: number; country: string } | null>;
}

export interface FxRates {
  /** 1 EUR kaç birim eder. */
  perEur(currency: string): Promise<number>;
}
