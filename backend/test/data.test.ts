import { describe, expect, it } from 'vitest';
import { parseCityCodes, parseCsv, parseGeoNames, parseOurAirports } from '../src/data/import/parse.js';
import { findCandidates } from '../src/search/candidates.js';
import { CITIES, indexes } from './helpers.js';

describe('CSV ve içe aktarım', () => {
  it('tırnak içindeki virgül ve çift tırnağı okur', () => {
    expect(parseCsv('a,"b, c","d ""e"""\n1,2,3')).toEqual([
      ['a', 'b, c', 'd "e"'],
      ['1', '2', '3'],
    ]);
  });

  it('OurAirports: yalnızca IATA kodlu, tarifeli, büyük/orta ve veri ülkesindeki havalimanları', () => {
    const csv = [
      '"id","ident","type","name","latitude_deg","longitude_deg","elevation_ft","continent","iso_country","iso_region","municipality","scheduled_service","icao_code","iata_code","gps_code","local_code","home_link","wikipedia_link","keywords"',
      '1,"EDDM","large_airport","Munich Airport",48.35,11.78,1487,"EU","DE","DE-BY","Munich","yes","EDDM","MUC","","","","",""',
      '2,"LOWS","medium_airport","Salzburg Airport",47.79,13.00,1411,"EU","AT","AT-5","Salzburg","yes","LOWS","SZG","","","","",""',
      '3,"EDXX","small_airport","Küçük Pist",48.0,11.0,0,"EU","DE","DE-BY","Köy","yes","","XXA","","","","",""',
      '4,"EDYY","large_airport","Kargo",48.0,11.0,0,"EU","DE","DE-BY","Köy","no","","YYA","","","","",""',
      '5,"KJFK","large_airport","JFK",40.6,-73.7,13,"NA","US","US-NY","New York","yes","KJFK","JFK","","","","",""',
      '6,"EDZZ","large_airport","Kodsuz",48.0,11.0,0,"EU","DE","DE-BY","Köy","yes","","","","","","",""',
    ].join('\n');
    const airports = parseOurAirports(csv);
    expect(airports.map((a) => a.iata)).toEqual(['MUC', 'SZG']);
    expect(airports[1]?.size).toBe('medium');
  });

  it('Travelpayouts şehir kodlarını eşler', () => {
    const map = parseCityCodes([
      { code: 'MXP', city_code: 'MIL' },
      { code: 'SAW', city_code: 'IST' },
      { code: 'BAD', city_code: null },
    ]);
    expect(map.get('MXP')).toBe('MIL');
    expect(map.get('SAW')).toBe('IST');
    expect(map.has('BAD')).toBe(false);
  });

  it('GeoNames satırından Türkçe adlı şehir ve arama anahtarları üretir', () => {
    const line = [
      '2867714', 'Munich', 'Munich', 'MUC,Minga,Monaco di Baviera,München,Мюнхен', '48.13743', '11.57549',
      'P', 'PPLA', 'DE', '', '02', '091', '09162', '09162000', '1260391', '', '524', 'Europe/Berlin', '2023-10-12',
    ].join('\t');
    const [c] = parseGeoNames(line);
    expect(c?.name).toBe('Münih');
    expect(c?.tz).toBe('Europe/Berlin');
    expect(c?.keys).toEqual(expect.arrayContaining(['munih', 'munich', 'munchen', 'monaco di baviera']));
    expect(c?.keys).not.toContain('muc');
    expect(c?.keys.some((k) => /[а-я]/.test(k))).toBe(false);
  });
});

describe('yer dizini', () => {
  const ix = indexes();

  it('Türkçe, İngilizce ve yerel adla bulur', () => {
    expect(ix.places.search('münih')[0]?.name).toBe('Münih');
    expect(ix.places.search('munchen')[0]?.name).toBe('Münih');
    expect(ix.places.search('salz')[0]?.name).toBe('Salzburg');
    expect(ix.places.search('istanbul')[0]?.name).toBe('İstanbul');
  });

  it('üç harfli kodda havalimanını öne alır', () => {
    expect(ix.places.search('muc')[0]?.id).toBe('airport:MUC');
    expect(ix.places.resolve('MUC')?.kind).toBe('AIRPORT');
  });

  it('kimlikle çözer ve öneri biçimine Türkçe ülke adı koyar', () => {
    const place = ix.places.resolve('city:2766824');
    expect(place?.name).toBe('Salzburg');
    expect(place?.iata).toBe('SZG');
  });

  it('İstanbul için tek kalkış kodu IST (IST ve SAW aynı şehir)', () => {
    const istanbul = CITIES[0]!;
    expect(ix.airports.originCityCodes(istanbul)).toEqual(['IST']);
  });

  it('havalimanı için kartta görünecek şehir adı', () => {
    expect(ix.places.cityNameNear(ix.airports.get('MUC')!)).toBe('Münih');
  });
});

describe('02 · aday havalimanları', () => {
  const ix = indexes();
  const salzburg = ix.places.resolve('Salzburg')!;

  it('250 km içinde doğrudan ve aday grubunu ayırır', () => {
    const set = findCandidates(salzburg, 250, ix.airports, ['IST']);
    expect(set.direct.map((h) => h.airport.iata)).toEqual(['SZG']);
    const candidates = set.candidates.map((h) => h.airport.iata).sort();
    expect(candidates).toEqual(['FMM', 'INN', 'LNZ', 'MUC', 'NUE']);
    expect(candidates).not.toContain('VIE'); // ~265 km
    expect(set.destCodes[0]).toBe('SZG');
  });

  it('yarıçap küçülünce uzak adaylar düşer', () => {
    const set = findCandidates(salzburg, 150, ix.airports, ['IST']);
    expect(set.candidates.map((h) => h.airport.iata).sort()).toEqual(['INN', 'LNZ', 'MUC']);
  });

  it('Türkiye havalimanları ve kalkış kodu aday olmaz', () => {
    const ankara = ix.places.resolve('Ankara')!;
    const set = findCandidates(ankara, 400, ix.airports, ['IST']);
    expect(set.candidates).toHaveLength(0);
  });
});
