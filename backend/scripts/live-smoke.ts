/**
 * CANLI DENEME — gerçek ağ çağrısı yapan TEK yer.
 *
 *   LIVE=1 npm run live -- "İstanbul" "Salzburg" 2026-11-20
 *
 * Travelpayouts'a birkaç, Transitous'a en fazla 5 istek atar. Transitous
 * koşulları gereği .env'de LEYLEK_CONTACT_EMAIL dolu olmadan çalışmaz.
 * Testler bu betiği hiçbir zaman çağırmaz.
 */
import 'dotenv/config';
import { loadConfig } from '../src/config.js';
import { CircuitBreaker, RequestBudget } from '../src/core/budget.js';
import { TtlCache } from '../src/core/cache.js';
import { HttpClient } from '../src/core/http.js';
import { buildIndexes, loadDataset } from '../src/data/dataset.js';
import { EcbRates } from '../src/providers/fx/ecb.js';
import { BudgetedGroundRouter, TransitousClient } from '../src/providers/transitous/client.js';
import { TravelpayoutsClient } from '../src/providers/travelpayouts/client.js';
import { SearchService } from '../src/search/pipeline.js';

if (process.env.LIVE !== '1') {
  console.error('Bu betik gerçek ağ çağrısı yapar. Çalıştırmak için LIVE=1 ver.');
  process.exit(1);
}

const config = loadConfig();
if (!config.contactConfigured) {
  console.error('LEYLEK_CONTACT_EMAIL boş. Transitous koşulları User-Agent içinde iletişim bilgisi istiyor.');
  process.exit(1);
}
if (!config.travelpayoutsToken) {
  console.error('TRAVELPAYOUTS_TOKEN boş.');
  process.exit(1);
}

const [from = 'İstanbul', to = 'Salzburg', date] = process.argv.slice(2);
const day = date ?? new Date(Date.now() + 28 * 86_400_000).toISOString().slice(0, 10);

const dataset = await loadDataset(config.dataDir);
if (!dataset) {
  console.error('Veri yok. Önce `npm run data:import`.');
  process.exit(1);
}
const indexes = buildIndexes(dataset);
const cache = new TtlCache();
const http = (s: string) => new HttpClient(s, fetch, config.userAgent, 20_000);
const transitous = new TransitousClient(http('transitous'), config.transitousBaseUrl, cache);
// Canlı denemede de arama başına sınır geçerli: en fazla 5 /plan.
const ground = new BudgetedGroundRouter(transitous, cache, new RequestBudget(5, 5), new CircuitBreaker());

const service = new SearchService({
  indexes: () => indexes,
  flights: new TravelpayoutsClient(http('travelpayouts'), config.travelpayoutsToken, cache),
  ground,
  geocoder: transitous,
  stops: transitous,
  fx: new EcbRates(http('ecb'), cache),
  cache,
});

console.log(`${from} → ${to}, ${day}  (User-Agent: ${config.userAgent})\n`);
const started = Date.now();
const res = await service.search({ from, to, date: day, radiusKm: 250, maxGroundHours: 5, currency: 'TRY' });

for (const o of res.options) {
  const title = o.kind === 'DIRECT' ? `Doğrudan ${o.flight.airport}` : `${o.via?.name} (${o.via?.iata}) üzerinden`;
  const legs = o.ground?.legs.map((l) => l.line ?? l.mode).join(' + ') ?? '';
  console.log(
    `${o.rank}. ${String(o.total.price).padStart(6)} TRY  ${title.padEnd(26)} ` +
      `${Math.round(o.total.doorToDoorMin / 6) / 10} sa  ${legs}  [${o.badges.join(', ')}]  ${o.flags.join(' ')}`,
  );
}
console.log(`\nUyarılar: ${res.warnings.join(', ') || 'yok'}`);
console.log(`Elenen: ${res.dropped.map((d) => `${d.iata}:${d.reason}`).join(' ') || 'yok'}`);
console.log(`Transitous /plan isteği: ${ground.calls}, süre: ${Date.now() - started} ms`);
