import { MINUTE, TtlCache } from '../core/cache.js';
import { Errors } from '../core/errors.js';
import { haversineKm } from '../core/geo.js';
import type { Indexes } from '../data/dataset.js';
import type { Place } from '../data/place-index.js';
import { DESTINATION_COUNTRIES } from '../data/regions.js';
import { findCandidates } from './candidates.js';
import { fetchQuotes, groupByAirport, mapLimit } from './flights.js';
import { bufferMinutes, computeGround, earliestGroundDepart, estimatedGround } from './ground.js';
import type { FlightPriceSource, FlightQuote, FxRates, Geocoder, GroundRouter, StopLocator } from './ports.js';
import { prefilter } from './prefilter.js';
import { alternateFlightCard, directCard, rankCards, scoreCards, viaCard } from './rank.js';
import { resolvePlace } from './resolve.js';
import { toResponse, type SearchResponse } from './response.js';
import { PARAMS, type AirportFlights, type Candidate, type Card, type Dropped, type SearchQuery } from './types.js';

export interface SearchDeps {
  /** Veri henüz yüklenmediyse `null`. */
  indexes: () => Indexes | null;
  flights: FlightPriceSource;
  ground: GroundRouter;
  geocoder: Geocoder;
  /** Havalimanı durağı; verilmezse kara bacağı koordinatla aranır. */
  stops?: StopLocator;
  fx: FxRates;
  cache: TtlCache;
  now?: () => number;
}

const RESPONSE_TTL = 10 * MINUTE;

/**
 * Arama hattı: 01 yerleri çöz → 02 adaylar → 03 uçuşlar → 04 eleme →
 * 05 kara bacağı → 06 kartlar. Her adım ayrı bir saf fonksiyon; bu sınıf
 * yalnızca sıralar ve bağımlılıkları dağıtır.
 */
export class SearchService {
  private readonly now: () => number;

  constructor(private readonly deps: SearchDeps) {
    this.now = deps.now ?? Date.now;
  }

  search(query: SearchQuery): Promise<SearchResponse> {
    const key = `search:${query.from}|${query.to}|${query.date}|${query.radiusKm}|${query.maxGroundHours}|${query.currency}|${query.stopoverDays}`;
    // Aynı arama 10 dakika içinde gelirse hazır yanıt; aynı anda
    // gelenler tek hesaplamayı bekler.
    return this.deps.cache.singleFlight(key, RESPONSE_TTL, () => this.run(query));
  }

  private async run(query: SearchQuery): Promise<SearchResponse> {
    const indexes = this.deps.indexes();
    if (!indexes) throw Errors.dataNotReady();
    const { airports, places } = indexes;

    // 01 · Yerleri çöz
    const [from, to] = await Promise.all([
      resolvePlace(query.from, places, airports, this.deps.geocoder),
      resolvePlace(query.to, places, airports, this.deps.geocoder),
    ]);
    if (!from) throw Errors.placeNotFound('from', query.from);
    if (!to) throw Errors.placeNotFound('to', query.to);
    if (from.id === to.id || haversineKm(from, to) < 20) throw Errors.samePlace();
    // Ülke seçildiyse aynı ülkenin içi aranmaz: "Türkiye → İstanbul".
    if ((from.kind === 'COUNTRY' || to.kind === 'COUNTRY') && from.country === to.country) {
      throw Errors.samePlace();
    }
    if (!DESTINATION_COUNTRIES.has(to.country)) throw Errors.outOfCoverage(to.country);

    const originCodes =
      from.kind === 'AIRPORT' && from.iata
        ? [airports.get(from.iata)?.cityCode ?? from.iata]
        : from.kind === 'COUNTRY'
          ? places.countryCityCodes(from.country, PARAMS.countryOriginCodes)
          : airports.originCityCodes(from, PARAMS.originRadiusKm);
    if (originCodes.length === 0) throw Errors.noOriginAirport();

    if (to.kind === 'COUNTRY') return this.countrySearch(query, from, to, originCodes, indexes);

    // 02 · Aday havalimanları
    const set = findCandidates(to, query.radiusKm, airports, originCodes);

    // 03 · Uçuş fiyatları
    const quotes = await fetchQuotes(this.deps.flights, originCodes, set.destCodes, query.date);
    const directFlights = groupByAirport(quotes, set.direct);
    const viaFlights = groupByAirport(quotes, set.candidates);
    const dropped: Dropped[] = set.candidates
      .filter((h) => !viaFlights.some((v) => v.airport.iata === h.airport.iata))
      .map((h) => ({ iata: h.airport.iata, reason: 'NO_FLIGHT_DATA' as const }));

    const bestDirect = directFlights.reduce<(typeof directFlights)[number] | null>(
      (best, d) => (!best || d.cheapest.priceEur < best.cheapest.priceEur ? d : best),
      null,
    );

    // 04 · Ağdan önce ele
    const filtered = prefilter(viaFlights, to, bestDirect?.cheapest ?? null, query.maxGroundHours);
    dropped.push(...filtered.dropped);

    // 05 · Kara bacağı (en fazla K istek, bütçeli). Varış, şehrin ana
    // istasyonuna bağlanır (bulunamazsa şehir merkezinin koordinatına).
    const destStation =
      filtered.kept.length > 0 && this.deps.stops
        ? await this.deps.stops.cityStation(to).catch(() => null)
        : null;
    const outcomes = await mapLimit(filtered.kept, PARAMS.topK, (c) =>
      computeGround(
        c,
        to,
        {
          maxGroundHours: query.maxGroundHours,
          stopoverDays: query.stopoverDays,
          ...(destStation ? { destStopId: destStation.id } : {}),
        },
        {
          router: this.deps.ground,
          fx: this.deps.fx,
          airports,
          stops: this.deps.stops,
          cityNear: (a) => places.cityForAirport(a),
        },
      ),
    );

    // 06 · Kartlar
    const cards: Card[] = [];
    const unverified: Card[] = [];
    const alternates: Card[] = [];
    let partial = false;
    filtered.kept.forEach((candidate, i) => {
      const outcome = outcomes[i];
      if (!outcome || outcome.status === 'impossible') {
        dropped.push({ iata: candidate.airport.iata, reason: outcome?.reason ?? 'NO_GROUND_CONNECTION' });
        return;
      }
      const card = viaCard(candidate, candidate.cheapest, outcome.ground, query.stopoverDays);
      if (outcome.status === 'unverified') {
        partial = true;
        unverified.push(card);
        return;
      }
      cards.push(card);
      const alt = alternateFlightCard(
        card,
        candidate.earliest,
        query.stopoverDays > 0 ? 0 : this.bufferFor(candidate.earliest, candidate),
      );
      if (alt) alternates.push(alt);
    });
    if (bestDirect) cards.push(directCard(bestDirect.cheapest, bestDirect.airport, bestDirect.distanceKm));

    // Hedef 4 plan: a) aynı havalimanının diğer uçuşu, b) doğrulanamayanlar,
    // c) ilk 5'e giremeyenler (tahminle).
    const fillers: Card[] = [
      ...alternates,
      ...unverified,
      ...filtered.reserve.map((c) => this.reserveCard(c, query.stopoverDays)),
    ];
    for (const filler of fillers) {
      if (cards.length >= PARAMS.maxCards) break;
      cards.push(filler);
    }

    scoreCards(cards, cards.find((c) => c.kind === 'DIRECT')?.doorToDoorMin ?? null);
    const ranked = cards.length > 0 ? rankCards(cards, bestDirect?.cheapest.priceEur ?? null) : [];

    const warnings: string[] = [];
    if (ranked.length < PARAMS.minCards) warnings.push('FEWER_THAN_THREE');
    if (partial) warnings.push('PARTIAL_RESULTS');

    const rate = await this.deps.fx.perEur(query.currency);
    return toResponse({ query, from, to, cards: ranked, dropped, warnings, rate, places, now: this.now() });
  }

  /**
   * Varış bir ülke: kara bacağı yok. Ülkenin en büyük havalimanı
   * şehirlerine uçuşlar sorulur, her şehir için en ucuz uçuş bir kart
   * olur; kartlar fiyata göre sıralanır. Kullanıcı kartta indiği şehri
   * görür ("Milano", "Roma").
   */
  private async countrySearch(
    query: SearchQuery,
    from: Place,
    to: Place,
    originCodes: string[],
    indexes: Indexes,
  ): Promise<SearchResponse> {
    const { airports, places } = indexes;
    const destCodes = places
      .countryCityCodes(to.country, PARAMS.countryDestCodes + originCodes.length)
      .filter((c) => !originCodes.includes(c))
      .slice(0, PARAMS.countryDestCodes);
    const hits = airports
      .inCountry(to.country)
      .filter((a) => destCodes.includes(a.cityCode))
      .map((airport) => ({ airport, distanceKm: 0 }));

    const quotes = await fetchQuotes(this.deps.flights, originCodes, destCodes, query.date);
    // Şehir başına tek kart: MXP, LIN ve BGY'den en ucuzu Milano kartı olur.
    const byCity = new Map<string, AirportFlights>();
    for (const g of groupByAirport(quotes, hits)) {
      const prev = byCity.get(g.airport.cityCode);
      if (!prev || g.cheapest.priceEur < prev.cheapest.priceEur) byCity.set(g.airport.cityCode, g);
    }
    const dropped: Dropped[] = destCodes
      .filter((c) => !byCity.has(c))
      .map((c) => ({ iata: c, reason: 'NO_FLIGHT_DATA' as const }));

    const cards = [...byCity.values()]
      .sort((a, b) => a.cheapest.priceEur - b.cheapest.priceEur)
      .slice(0, PARAMS.maxCards)
      .map((g) => directCard(g.cheapest, g.airport, 0));
    scoreCards(cards, null);
    const ranked = cards.length > 0 ? rankCards(cards, null) : [];

    const warnings: string[] = [];
    if (ranked.length < PARAMS.minCards) warnings.push('FEWER_THAN_THREE');
    const rate = await this.deps.fx.perEur(query.currency);
    return toResponse({ query, from, to, cards: ranked, dropped, warnings, rate, places, now: this.now() });
  }

  private bufferFor(flight: FlightQuote, candidate: Candidate): number {
    const origin = this.deps.indexes()?.airports.get(flight.originAirport);
    return bufferMinutes(origin?.country ?? 'TR', candidate.airport.country, flight.transfers);
  }

  private reserveCard(candidate: Candidate, stopoverDays: number): Card {
    const flight = candidate.cheapest;
    const origin = this.deps.indexes()?.airports.get(flight.originAirport);
    const departMs = earliestGroundDepart(flight, candidate.airport, origin?.country ?? 'TR', stopoverDays);
    return viaCard(candidate, flight, estimatedGround(candidate, flight, departMs), stopoverDays);
  }
}
