/**
 * Uçtan uca test çalıştırıcısı.
 *
 *   npm run e2e                 sahte dış servislerle (ağa çıkmaz)
 *   LIVE=1 npm run e2e -- --live   gerçek Travelpayouts ve Transitous ile
 *
 * Gerçek sunucuyu (src/server.ts) ayrı bir süreç olarak başlatır, HTTP
 * üzerinden dener, ardından uygulamanın kendi veri katmanını
 * (`tool/e2e_api_contract.dart`) aynı sunucuya bağlayıp çalıştırır.
 * Sonuç `e2e-reports/` altına JSON olarak yazılır; bir kontrol bile
 * düşerse çıkış kodu 1.
 *
 * Canlı kipte Transitous'a arama başına en fazla 5 /plan isteği gider;
 * şehir çiftleri bilerek az tutuldu.
 */
import { spawn, spawnSync, type ChildProcess } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:net';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { startMockUpstreams, type MockUpstreams } from './e2e/mock-upstreams.js';

const live = process.argv.includes('--live');
if (live && process.env.LIVE !== '1') {
  console.error('Canlı kip gerçek ağ çağrısı yapar. Çalıştırmak için LIVE=1 ver.');
  process.exit(1);
}

const backendDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const appDir = resolve(backendDir, '..');

interface Check {
  name: string;
  ok: boolean;
  detail: string;
  ms: number;
}
const checks: Check[] = [];

async function check(name: string, fn: () => Promise<string | void>): Promise<void> {
  const started = Date.now();
  try {
    const detail = (await fn()) ?? '';
    checks.push({ name, ok: true, detail, ms: Date.now() - started });
    console.log(`  ✓ ${name}${detail ? ` — ${detail}` : ''}`);
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    checks.push({ name, ok: false, detail, ms: Date.now() - started });
    console.log(`  ✗ ${name} — ${detail}`);
  }
}

function assert(cond: unknown, message: string): asserts cond {
  if (!cond) throw new Error(message);
}

function freePort(): Promise<number> {
  return new Promise((res, rej) => {
    const srv = createServer();
    srv.listen(0, '127.0.0.1', () => {
      const port = (srv.address() as { port: number }).port;
      srv.close(() => res(port));
    });
    srv.on('error', rej);
  });
}

const day = (offset: number) => new Date(Date.now() + offset * 86_400_000).toISOString().slice(0, 10);

// ── Sunucuyu başlat ───────────────────────────────────────────────
const mocks: MockUpstreams | null = live ? null : await startMockUpstreams();
const port = await freePort();
const base = `http://127.0.0.1:${port}`;
const env: NodeJS.ProcessEnv = {
  ...process.env,
  PORT: String(port),
  HOST: '127.0.0.1',
  NODE_ENV: 'production',
  LOG_LEVEL: 'info',
  RATE_LIMIT_PER_MINUTE: '1000',
  ...(mocks
    ? {
        TRAVELPAYOUTS_TOKEN: 'e2e-token',
        TRAVELPAYOUTS_BASE_URL: mocks.baseUrl,
        TRANSITOUS_BASE_URL: mocks.baseUrl,
        ECB_RATES_URL: `${mocks.baseUrl}/eurofxref-daily.xml`,
        LEYLEK_CONTACT_EMAIL: 'e2e@example.invalid',
      }
    : {}),
};

let logs = '';
const server: ChildProcess = spawn(process.execPath, ['--import', 'tsx', 'src/server.ts'], {
  cwd: backendDir,
  env,
  stdio: ['ignore', 'pipe', 'pipe'],
});
server.stdout?.on('data', (b: Buffer) => (logs += b.toString()));
server.stderr?.on('data', (b: Buffer) => (logs += b.toString()));

async function get(path: string): Promise<{ status: number; headers: Headers; json: any; ms: number }> {
  const started = Date.now();
  const res = await fetch(`${base}${path}`);
  const text = await res.text();
  let json: any = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = text;
  }
  return { status: res.status, headers: res.headers, json, ms: Date.now() - started };
}

async function waitHealthy(): Promise<void> {
  const deadline = Date.now() + 60_000;
  while (Date.now() < deadline) {
    try {
      const r = await get('/health');
      if (r.status === 200 && r.json?.status === 'ok') return;
    } catch {
      // henüz dinlemiyor
    }
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error(`Sunucu 60 sn içinde hazır olmadı.\n${logs.slice(-2000)}`);
}

console.log(`\nLeylek uçtan uca testleri (${live ? 'CANLI' : 'sahte dış servisler'}) — ${base}\n`);
const startedAll = Date.now();

try {
  await check('Sunucu açılıyor ve veri yükleniyor (/health)', async () => {
    await waitHealthy();
    const r = await get('/health');
    assert(r.json.data.airports > 300, `havalimanı sayısı az: ${r.json.data.airports}`);
    assert(r.json.data.places > 1000, `yer sayısı az: ${r.json.data.places}`);
    return `${r.json.data.airports} havalimanı, ${r.json.data.places} yer`;
  });

  // ── Yer önerileri ──────────────────────────────────────────────
  await check('Yer önerisi: "salz" → Salzburg, "münih" → Münih', async () => {
    const a = await get('/v1/places?q=salz');
    assert(a.status === 200 && a.json.places[0]?.name === 'Salzburg', `ilk öneri: ${a.json.places?.[0]?.name}`);
    const b = await get(`/v1/places?q=${encodeURIComponent('münih')}`);
    assert(b.json.places[0]?.name === 'Münih', `ilk öneri: ${b.json.places?.[0]?.name}`);
    assert(b.json.places[0].countryName === 'Almanya', 'ülke adı Türkçe değil');
    return `${a.ms + b.ms} ms`;
  });

  // ── Arama ──────────────────────────────────────────────────────
  const pairs: { from: string; to: string; stay: number }[] = live
    ? [
        { from: 'İstanbul', to: 'Salzburg', stay: 0 },
        { from: 'İstanbul', to: 'Salzburg', stay: 1 },
        { from: 'İstanbul', to: 'Luzern', stay: 0 },
      ]
    : [
        { from: 'İstanbul', to: 'Salzburg', stay: 0 },
        { from: 'İstanbul', to: 'Salzburg', stay: 1 },
      ];
  const searchDate = day(live ? 24 : 30);
  const responses: Record<string, any> = {};

  for (const p of pairs) {
    const label = `${p.from} → ${p.to}${p.stay ? ` (${p.stay} gün konaklama)` : ''}`;
    await check(`Arama: ${label}`, async () => {
      const q = new URLSearchParams({ from: p.from, to: p.to, date: searchDate, stopoverDays: String(p.stay) });
      const r = await get(`/v1/search?${q}`);
      assert(r.status === 200, `HTTP ${r.status}: ${JSON.stringify(r.json).slice(0, 300)}`);
      const res = r.json;
      responses[label] = res;
      const opts: any[] = res.options;
      assert(opts.length >= 1 && opts.length <= 4, `kart sayısı ${opts.length}`);
      if (!live) assert(opts.length === 4, `sahte veride 4 plan beklenirdi, ${opts.length} geldi`);
      const prices = opts.map((o) => o.total.price);
      assert(prices.every((x, i) => i === 0 || prices[i - 1] <= x), `fiyat sırası bozuk: ${prices}`);
      assert(opts[0].badges.includes('CHEAPEST'), 'ilk kartta EN UCUZ rozeti yok');
      const rec = opts.filter((o) => o.badges.includes('RECOMMENDED'));
      assert(rec.length <= 1, 'birden çok önerilen');
      for (const o of rec) assert(!o.flags.includes('GROUND_NOT_VERIFIED'), 'doğrulanmamış kart önerilmiş');
      const names = res.attribution.map((a: any) => a.name);
      assert(names.includes('Transitous') && names.includes('OpenStreetMap katkıcıları'), 'atıf eksik');
      for (const o of opts) {
        assert(/[+-]\d{2}:\d{2}$/.test(o.flight.departAt) && /[+-]\d{2}:\d{2}$/.test(o.flight.arriveAt), 'saatlerde ofset yok');
        for (const b of o.booking) {
          assert(b.url.startsWith('https://'), `https olmayan bağlantı: ${b.url}`);
          assert(!/marker|aviasales|travelpayouts|SHOULD_NOT_LEAK/i.test(b.url), `ortaklık izi: ${b.url}`);
        }
        if (o.kind === 'VIA') {
          assert(o.ground, 'aktarmalı kartta kara yolu yok');
          assert(o.ground.legs.length > 0 || o.flags.includes('GROUND_NOT_VERIFIED'), 'kara yolu bacaksız ama doğrulanmış');
          if (p.stay > 0) {
            assert(o.stopover?.days === p.stay, 'konaklama bilgisi yok');
            assert(o.flags.includes('STOPOVER'), 'STOPOVER etiketi yok');
            assert(o.total.travelMin < o.total.doorToDoorMin, 'yolda geçen süre konaklamayı içeriyor');
          }
        }
      }
      assert(!JSON.stringify(res).includes('SHOULD_NOT_LEAK'), 'ortaklık bağlantısı yanıta sızdı');
      const summary = opts
        .map((o) => `${o.kind === 'DIRECT' ? 'doğrudan' : o.via.iata}:${o.total.price}${o.badges.includes('RECOMMENDED') ? '★' : ''}`)
        .join(' ');
      return `${r.ms} ms · ${summary}${res.warnings.length ? ` · uyarı: ${res.warnings}` : ''}`;
    });
  }

  await check('Aynı arama ikinci kez önbellekten gelir', async () => {
    const q = new URLSearchParams({ from: 'İstanbul', to: 'Salzburg', date: searchDate, stopoverDays: '0' });
    const before = mocks ? mocks.requests.length : 0;
    const r = await get(`/v1/search?${q}`);
    assert(r.status === 200, `HTTP ${r.status}`);
    if (mocks) assert(mocks.requests.length === before, `dış servise ${mocks.requests.length - before} istek gitti`);
    assert(r.ms < 1000, `önbellekli yanıt yavaş: ${r.ms} ms`);
    return `${r.ms} ms`;
  });

  // ── Hatalar ───────────────────────────────────────────────────
  await check('Hatalı girdi: geçmiş tarih ve konaklama sınırı 400, Türkçe mesaj', async () => {
    const past = await get(`/v1/search?from=Istanbul&to=Salzburg&date=${day(-10)}`);
    assert(past.status === 400 && past.json.error.field === 'date', `geçmiş tarih: HTTP ${past.status}`);
    assert(/Geçmiş/.test(past.json.error.message), 'mesaj Türkçe değil');
    const stay = await get(`/v1/search?from=Istanbul&to=Salzburg&date=${searchDate}&stopoverDays=7`);
    assert(stay.status === 400 && stay.json.error.field === 'stopoverDays', `konaklama: HTTP ${stay.status}`);
  });

  await check('Kapsam dışı (Türkiye içi) varış 422', async () => {
    const r = await get(`/v1/search?from=Istanbul&to=Ankara&date=${searchDate}`);
    assert(r.status === 422 && r.json.error.code === 'OUT_OF_COVERAGE', `HTTP ${r.status} ${r.json?.error?.code}`);
  });

  await check('Bilinmeyen yer 422 PLACE_NOT_FOUND', async () => {
    const r = await get(`/v1/search?from=Istanbul&to=Qwxyzzz&date=${searchDate}`);
    assert(r.status === 422 && r.json.error.code === 'PLACE_NOT_FOUND', `HTTP ${r.status} ${r.json?.error?.code}`);
  });

  // ── Güvenlik ve gizlilik ───────────────────────────────────────
  await check('Güvenlik başlıkları', async () => {
    const r = await get('/v1/attribution');
    assert(r.headers.get('content-security-policy')?.includes("default-src 'none'"), 'CSP yok');
    assert(r.headers.get('permissions-policy')?.includes('geolocation=()'), 'Permissions-Policy yok');
    assert(!r.headers.get('x-powered-by'), 'X-Powered-By sızıyor');
    assert(r.headers.get('strict-transport-security'), 'HSTS yok');
  });

  await check('Loglarda IP, sorgu dizesi ve yer adı yok', async () => {
    assert(logs.includes('"path":"/v1/search"'), 'istek logu bulunamadı');
    assert(!/127\.0\.0\.1/.test(logs.replace(/listening on http:\/\/127\.0\.0\.1:\d+/g, '').replace(/Server listening at http:\/\/127\.0\.0\.1:\d+/g, '')), 'logda IP adresi var');
    assert(!/[?&](from|to|date)=/.test(logs), 'logda sorgu dizesi var');
    assert(!/Salzburg|Luzern/.test(logs), 'logda arama yapılan yer adı var');
  });

  if (mocks) {
    await check('Transitous kuralları: User-Agent, istek sayısı, önerilen parametreler', async () => {
      const t = mocks.requests.filter((r) => r.path.startsWith('/api/'));
      assert(t.length > 0, 'Transitous isteği yok');
      assert(t.every((r) => /^Leylek\/\d+\.\d+\.\d+ \(\+https:\/\/github\.com\/.+; e2e@example\.invalid\)$/.test(r.userAgent)), `User-Agent: ${t[0]?.userAgent}`);
      const plans = mocks.requests.filter((r) => r.path === '/api/v6/plan');
      assert(plans.length <= 5 * pairs.length, `/plan isteği fazla: ${plans.length}`);
      assert(plans.every((r) => !r.query.has('timetableView') && r.query.get('searchWindow') === '3600'), 'plan parametreleri önerilene uymuyor');
      assert(plans.every((r) => /^(airport|station):/.test(r.query.get('fromPlace') ?? '')), 'plan kalkışı durak kimliği değil');
      assert(plans.every((r) => !(r.query.get('fromPlace') ?? '').startsWith('plane:')), 'uçak durağından plan istendi');
      return `${plans.length} /plan, ${t.length - plans.length} durak/yer isteği`;
    });

    await check('Travelpayouts: tek yön, ortaklık işareti yok', async () => {
      const tp = mocks.requests.filter((r) => r.path === '/aviasales/v3/prices_for_dates');
      assert(tp.length > 0, 'uçuş isteği yok');
      assert(tp.every((r) => r.query.get('one_way') === 'true' && !r.query.has('marker')), 'one_way/marker hatalı');
      return `${tp.length} istek`;
    });
  }

  // ── Uygulamanın veri katmanı aynı sunucuya karşı ──────────────
  await check('Uygulama veri katmanı (Dart) backend yanıtlarını okuyor', async () => {
    const dart = process.platform === 'win32' ? 'dart.bat' : 'dart';
    const r = spawnSync(dart, ['run', 'tool/e2e_api_contract.dart', base, searchDate], {
      cwd: appDir,
      encoding: 'utf8',
      shell: process.platform === 'win32',
      timeout: 240_000,
    });
    const out = `${r.stdout ?? ''}${r.stderr ?? ''}`.trim();
    assert(r.status === 0, `çıkış kodu ${r.status}\n${out.slice(-1500)}`);
    return out.split('\n').filter((l) => l.startsWith('✓')).length + ' kontrol';
  });
} finally {
  server.kill();
  await mocks?.close();
}

// ── Rapor ─────────────────────────────────────────────────────────
const failed = checks.filter((c) => !c.ok);
const report = {
  mode: live ? 'live' : 'mock',
  startedAt: new Date(startedAll).toISOString(),
  durationMs: Date.now() - startedAll,
  passed: checks.length - failed.length,
  failed: failed.length,
  checks,
};
const dir = join(backendDir, 'e2e-reports');
mkdirSync(dir, { recursive: true });
const file = join(dir, `e2e-${report.mode}-${report.startedAt.replace(/[:.]/g, '-')}.json`);
writeFileSync(file, JSON.stringify(report, null, 2));
console.log(`\n${report.passed} geçti, ${report.failed} düştü (${Math.round(report.durationMs / 1000)} sn) → ${file}`);
process.exit(failed.length > 0 ? 1 : 0);
