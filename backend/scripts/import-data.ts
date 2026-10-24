/**
 * Açık veri içe aktarımı: OurAirports (kamu malı), Travelpayouts şehir
 * kodları, GeoNames cities15000 (CC BY 4.0).
 *
 *   npm run data:import
 *
 * Sunucu da haftada bir aynı işi kendisi yapar; bu betik ilk kurulum ve
 * elle yenileme için.
 */
import 'dotenv/config';
import { loadConfig } from '../src/config.js';
import { HttpClient } from '../src/core/http.js';
import { importDataset } from '../src/data/dataset.js';

const config = loadConfig();
const http = new HttpClient('data-import', fetch, config.userAgent, 120_000);

const started = Date.now();
const dataset = await importDataset(http, config.dataDir);
console.log(
  `Veri yazıldı: ${dataset.airports.length} havalimanı, ${dataset.cities.length} şehir ` +
    `(${Math.round((Date.now() - started) / 1000)} sn) → ${config.dataDir}/generated/dataset.json`,
);
