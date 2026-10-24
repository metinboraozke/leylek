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

/** Dış servis çağrısı başarısız oldu. */
export class UpstreamError extends Error {
  constructor(
    readonly service: string,
    readonly kind: 'network' | 'status' | 'parse' | 'rate_limited' | 'budget',
    message: string,
    readonly status?: number,
  ) {
    super(message);
    this.name = 'UpstreamError';
  }
}
