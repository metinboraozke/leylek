import { z } from 'zod';

/**
 * Ortam değişkenleri. Tek yerde doğrulanır; geri kalan kod `Config`
 * nesnesini alır, `process.env`'e hiç dokunmaz (testte farklı ayar
 * vermek bu yüzden kolay).
 */
const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(8080),
  HOST: z.string().default('0.0.0.0'),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),

  TRAVELPAYOUTS_TOKEN: z.string().trim().default(''),

  LEYLEK_REPO_URL: z.string().trim().default('https://github.com/metinboraozke/leylek'),
  LEYLEK_CONTACT_EMAIL: z.string().trim().default(''),

  TRANSITOUS_BASE_URL: z.string().url().default('https://api.transitous.org'),
  // Uçtan uca testlerde sahte sunucuya yönlendirmek için; üretimde boş bırakılır.
  TRAVELPAYOUTS_BASE_URL: z.string().url().default('https://api.travelpayouts.com'),
  ECB_RATES_URL: z.string().url().default('https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml'),
  TRANSITOUS_PLAN_PER_MINUTE: z.coerce.number().int().positive().default(30),
  TRANSITOUS_PLAN_PER_DAY: z.coerce.number().int().positive().default(3000),

  RATE_LIMIT_PER_MINUTE: z.coerce.number().int().positive().default(20),
  DATA_DIR: z.string().default('./data'),
});

export const APP_VERSION = '0.1.0';

export interface Config {
  env: 'development' | 'test' | 'production';
  port: number;
  host: string;
  logLevel: string;
  travelpayoutsToken: string;
  transitousBaseUrl: string;
  travelpayoutsBaseUrl: string;
  ecbRatesUrl: string;
  transitousPlanPerMinute: number;
  transitousPlanPerDay: number;
  rateLimitPerMinute: number;
  dataDir: string;
  /** Transitous koşulu: uygulama adı, sürüm ve iletişim bilgisi. */
  userAgent: string;
  contactConfigured: boolean;
}

export function loadConfig(source: NodeJS.ProcessEnv = process.env): Config {
  const e = schema.parse(source);
  const contact = e.LEYLEK_CONTACT_EMAIL || 'iletisim-ayarlanmadi';
  return {
    env: e.NODE_ENV,
    port: e.PORT,
    host: e.HOST,
    logLevel: e.LOG_LEVEL,
    travelpayoutsToken: e.TRAVELPAYOUTS_TOKEN,
    transitousBaseUrl: e.TRANSITOUS_BASE_URL.replace(/\/+$/, ''),
    travelpayoutsBaseUrl: e.TRAVELPAYOUTS_BASE_URL.replace(/\/+$/, ''),
    ecbRatesUrl: e.ECB_RATES_URL,
    transitousPlanPerMinute: e.TRANSITOUS_PLAN_PER_MINUTE,
    transitousPlanPerDay: e.TRANSITOUS_PLAN_PER_DAY,
    rateLimitPerMinute: e.RATE_LIMIT_PER_MINUTE,
    dataDir: e.DATA_DIR,
    userAgent: `Leylek/${APP_VERSION} (+${e.LEYLEK_REPO_URL}; ${contact})`,
    contactConfigured: e.LEYLEK_CONTACT_EMAIL.length > 0,
  };
}
