/**
 * İstemciye `{ error: { code, message } }` olarak dönen hata.
 * `message` Türkçe ve kullanıcıya olduğu gibi gösterilebilir.
 */
export class AppError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export const Errors = {
  placeNotFound: (field: 'from' | 'to', input: string) =>
    new AppError(422, 'PLACE_NOT_FOUND', `"${input}" bulunamadı. Listeden bir şehir seç.`),
  outOfCoverage: (country: string) =>
    new AppError(
      422,
      'OUT_OF_COVERAGE',
      country === 'TR'
        ? 'Türkiye içi rotalar kapsam dışında. Leylek Avrupa\'daki varışlar için çalışır.'
        : 'Bu ülke için kara yolu verisi henüz yok.',
    ),
  noOriginAirport: () =>
    new AppError(422, 'NO_ORIGIN_AIRPORT', 'Kalkış noktasına yakın tarifeli havalimanı bulunamadı.'),
  samePlace: () => new AppError(422, 'SAME_PLACE', 'Kalkış ve varış aynı olamaz.'),
  flightsUnavailable: () =>
    new AppError(503, 'FLIGHTS_UNAVAILABLE', 'Uçuş fiyatları şu an alınamıyor. Biraz sonra tekrar dene.'),
  dataNotReady: () =>
    new AppError(503, 'DATA_NOT_READY', 'Sunucu verileri henüz yüklenmedi. Biraz sonra tekrar dene.'),
};

/**
 * Hata kodlarının İngilizce mesajları; istek `lang=en` ise Türkçe mesajın
 * yerine bunlar gider. Kodu olmayan hata Türkçe kalır.
 */
export const ENGLISH_MESSAGES: Record<string, string> = {
  PLACE_NOT_FOUND: 'Place not found. Pick a city from the list.',
  OUT_OF_COVERAGE: 'Leylek works for destinations in Europe; this one is not covered yet.',
  NO_ORIGIN_AIRPORT: 'No scheduled airport found near the departure point.',
  SAME_PLACE: 'From and to cannot be the same.',
  FLIGHTS_UNAVAILABLE: "Flight prices aren't available right now. Try again in a moment.",
  DATA_NOT_READY: "Server data isn't loaded yet. Try again in a moment.",
  INVALID_QUERY: 'Invalid search. Check the fields and try again.',
  INTERNAL: 'Something went wrong. Try again in a moment.',
};

/** Dış servis çağrısı başarısız oldu. */
export class UpstreamError extends Error {
  constructor(
    readonly service: string,
    readonly kind: 'network' | 'status' | 'parse' | 'rate_limited' | 'budget',
    message: string,
    readonly status?: number,
    /** 429'da sunucunun `Retry-After` başlığı (ms); yoksa `undefined`. */
    readonly retryAfterMs?: number,
  ) {
    super(message);
    this.name = 'UpstreamError';
  }
}
