import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { unzipSync, strFromU8 } from 'fflate';
import type { HttpClient } from '../core/http.js';
import { AirportIndex } from './airport-index.js';
import { enrichAirports, parseCityCodes, parseGeoNames, parseOurAirports } from './import/parse.js';
import { PlaceIndex } from './place-index.js';
import type { Dataset } from './types.js';

export const SOURCES = {
  ourAirports: 'https://davidmegginson.github.io/ourairports-data/airports.csv',
  cityCodes: 'https://api.travelpayouts.com/data/en/airports.json',
  geoNames: 'https://download.geonames.org/export/dump/cities15000.zip',
};

const FILE = 'generated/dataset.json';

export interface Indexes {
  airports: AirportIndex;
  places: PlaceIndex;
  generatedAt: string;
}

export function buildIndexes(dataset: Dataset): Indexes {
  const airports = new AirportIndex(dataset.airports);
  return { airports, places: new PlaceIndex(dataset.cities, airports), generatedAt: dataset.generatedAt };
}

/** Diskteki veri dosyasını okur; yoksa `null`. */
export async function loadDataset(dataDir: string): Promise<Dataset | null> {
  try {
    return JSON.parse(await readFile(join(dataDir, FILE), 'utf8')) as Dataset;
  } catch {
    return null;
  }
}

/**
 * Üç açık veri kaynağını indirip tek bir dosyaya yazar.
 * Yazma atomik: yarım kalan içe aktarım eski dosyayı bozmaz.
 */
export async function importDataset(http: HttpClient, dataDir: string, now = new Date()): Promise<Dataset> {
  const [csv, cityCodesJson, zip] = await Promise.all([
    http.getText(SOURCES.ourAirports),
    http.getJson<unknown>(SOURCES.cityCodes),
    http.getBytes(SOURCES.geoNames),
  ]);

  const files = unzipSync(zip);
  const tsv = files['cities15000.txt'];
  if (!tsv) throw new Error('cities15000.zip içinde cities15000.txt yok');

  const cities = parseGeoNames(strFromU8(tsv));
  const airports = enrichAirports(parseOurAirports(csv), parseCityCodes(cityCodesJson), cities);
  if (airports.length < 200 || cities.length < 1000) {
    throw new Error(`Veri beklenenden az: ${airports.length} havalimanı, ${cities.length} şehir`);
  }

  const dataset: Dataset = { airports, cities, generatedAt: now.toISOString() };
  const target = join(dataDir, FILE);
  await mkdir(join(dataDir, 'generated'), { recursive: true });
  await writeFile(`${target}.tmp`, JSON.stringify(dataset));
  await rename(`${target}.tmp`, target);
  return dataset;
}
