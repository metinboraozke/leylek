import 'dotenv/config';
import pino from 'pino';
import { buildApp } from './app.js';
import { loadConfig } from './config.js';
import { CircuitBreaker, RequestBudget } from './core/budget.js';
import { DAY, TtlCache } from './core/cache.js';
import { HttpClient } from './core/http.js';
import { loggerOptions } from './core/logger.js';
import { buildIndexes, importDataset, loadDataset, type Indexes } from './data/dataset.js';
import { EcbRates } from './providers/fx/ecb.js';
import { BudgetedGroundRouter, TransitousClient } from './providers/transitous/client.js';
import { TravelpayoutsClient } from './providers/travelpayouts/client.js';
import { SearchService } from './search/pipeline.js';

/**
 * Bileşim kökü: somut sınıflar yalnızca burada birbirine bağlanır.
 */
const config = loadConfig();
const log = pino(loggerOptions(config.logLevel, config.env === 'development'));

if (!config.contactConfigured) {
  log.warn('LEYLEK_CONTACT_EMAIL boş. Transitous koşulları User-Agent içinde iletişim bilgisi istiyor.');
}
if (!config.travelpayoutsToken) {
  log.warn('TRAVELPAYOUTS_TOKEN boş. Uçuş fiyatı alınamaz; /v1/search 503 döner.');
}

const cache = new TtlCache();
const http = (service: string, timeoutMs?: number) =>
  new HttpClient(service, fetch, config.userAgent, timeoutMs);

const transitous = new TransitousClient(http('transitous', 20_000), config.transitousBaseUrl, cache);
const budget = new RequestBudget(config.transitousPlanPerMinute, config.transitousPlanPerDay);
const breaker = new CircuitBreaker();
const ground = new BudgetedGroundRouter(transitous, cache, budget, breaker);

let indexes: Indexes | null = null;

async function refreshData(download: boolean): Promise<void> {
  try {
    const dataset = download
      ? await importDataset(http('data-import', 120_000), config.dataDir)
      : await loadDataset(config.dataDir);
    if (!dataset) {
      log.error('Veri dosyası yok. Önce `npm run data:import` çalıştır.');
      return;
    }
    indexes = buildIndexes(dataset);
    log.info(
      { airports: dataset.airports.length, cities: dataset.cities.length, generatedAt: dataset.generatedAt },
      'Veri yüklendi',
    );
  } catch (err) {
    // Yenileme başarısızsa eski veriyle devam.
    log.error({ err }, 'Veri yenilenemedi; eldeki veriyle devam ediliyor');
  }
}

await refreshData(false);
if (!indexes) await refreshData(true);
// Haftalık yenileme (OurAirports, şehir kodları, GeoNames).
setInterval(() => void refreshData(true), 7 * DAY).unref();

const search = new SearchService({
  indexes: () => indexes,
  flights: new TravelpayoutsClient(http('travelpayouts', 20_000), config.travelpayoutsToken, cache),
  ground,
  geocoder: transitous,
  stops: transitous,
  fx: new EcbRates(http('ecb'), cache),
  cache,
});

const app = await buildApp({
  config,
  search,
  indexes: () => indexes,
  status: () => ({
    transitous: {
      circuit: breaker.isOpen() ? 'open' : 'closed',
      budgetLeft: budget.remaining(),
      callsSinceStart: ground.calls,
    },
    cacheEntries: cache.size,
  }),
});

await app.listen({ port: config.port, host: config.host });
