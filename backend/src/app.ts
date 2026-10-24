import { createHmac, randomBytes } from 'node:crypto';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import Fastify, { type FastifyInstance } from 'fastify';
import { ZodError } from 'zod';
import type { Config } from './config.js';
import { AppError } from './core/errors.js';
import { loggerOptions } from './core/logger.js';
import type { Indexes } from './data/dataset.js';
import { PlaceIndex } from './data/place-index.js';
import { placesQuerySchema, searchQuerySchema } from './routes/schemas.js';
import type { SearchService } from './search/pipeline.js';
import { ATTRIBUTION } from './search/response.js';

export interface AppDeps {
  config: Config;
  search: SearchService;
  indexes: () => Indexes | null;
  /** Sağlık uç noktasına eklenecek durum bilgisi. */
  status: () => Record<string, unknown>;
  now?: () => number;
}

/**
 * IP adresini hız sınırı anahtarına çevirir: her gün yenilenen tuzla
 * HMAC özeti. Anahtar yalnızca bellekte, bir dakikalık sayaçta yaşar;
 * özgün IP hiçbir yere yazılmaz ve ertesi gün eski özetler eşleşmez.
 */
export function makeIpKeyer(now: () => number = Date.now) {
  let day = -1;
  let salt = randomBytes(32);
  return (ip: string) => {
    const today = Math.floor(now() / 86_400_000);
    if (today !== day) {
      day = today;
      salt = randomBytes(32);
    }
    return createHmac('sha256', salt).update(ip).digest('base64url').slice(0, 22);
  };
}

export async function buildApp(deps: AppDeps): Promise<FastifyInstance> {
  const { config } = deps;
  const app = Fastify({
    logger: config.env === 'test' ? false : loggerOptions(config.logLevel, config.env === 'development'),
    trustProxy: true,
    bodyLimit: 1024,
    keepAliveTimeout: 61_000,
  });

  // PAX'teki ayarlar: API yalnızca JSON döner, tarayıcıda hiçbir şey yüklemez.
  await app.register(helmet, {
    contentSecurityPolicy: {
      directives: { 'default-src': ["'none'"], 'frame-ancestors': ["'none'"], 'base-uri': ["'none'"] },
    },
    crossOriginEmbedderPolicy: true,
    hsts: { maxAge: 31536000, includeSubDomains: true },
  });
  app.addHook('onSend', async (_request, reply, payload) => {
    reply.header(
      'Permissions-Policy',
      'accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()',
    );
    return payload;
  });
  // CORS kayıtlı değil: istemci mobil uygulama, tarayıcıdan çağrı beklenmiyor.

  const ipKey = makeIpKeyer(deps.now);
  await app.register(rateLimit, {
    max: config.rateLimitPerMinute,
    timeWindow: '1 minute',
    skipOnError: true,
    allowList: (request) => request.url === '/health',
    keyGenerator: (request) => ipKey(request.ip),
    errorResponseBuilder: (_request, context) => ({
      statusCode: 429,
      error: { code: 'RATE_LIMITED', message: `Çok fazla arama. ${context.after} sonra tekrar dene.` },
    }),
  });

  app.setErrorHandler((error, request, reply) => {
    if (error instanceof AppError) {
      return reply.status(error.status).send({ error: { code: error.code, message: error.message } });
    }
    if (error instanceof ZodError) {
      const first = error.issues[0];
      return reply.status(400).send({
        error: {
          code: 'INVALID_QUERY',
          field: first?.path.join('.') ?? null,
          message: first?.message ?? 'Geçersiz istek.',
        },
      });
    }
    const status = (error as { statusCode?: number }).statusCode;
    if (status === 429) {
      return reply.status(429).send(error);
    }
    request.log.error({ err: error }, 'Beklenmeyen hata');
    return reply.status(500).send({
      error: { code: 'INTERNAL', message: 'Beklenmeyen bir sorun oldu. Biraz sonra tekrar dene.' },
    });
  });

  const searchSchema = searchQuerySchema(deps.now);

  app.get('/v1/search', async (request) => {
    const q = searchSchema.parse(request.query);
    return deps.search.search({
      from: q.from,
      to: q.to,
      date: q.date,
      radiusKm: q.radiusKm,
      maxGroundHours: q.maxGroundHours,
      currency: q.currency,
    });
  });

  app.get('/v1/places', async (request) => {
    const q = placesQuerySchema.parse(request.query);
    const indexes = deps.indexes();
    if (!indexes) throw new AppError(503, 'DATA_NOT_READY', 'Sunucu verileri henüz yüklenmedi.');
    return { places: indexes.places.search(q.q, 8).map(PlaceIndex.toSuggestion) };
  });

  app.get('/v1/attribution', async () => ({ attribution: ATTRIBUTION }));

  app.get('/health', async () => {
    const indexes = deps.indexes();
    return {
      status: indexes ? 'ok' : 'starting',
      data: indexes
        ? {
            airports: indexes.airports.airports.length,
            places: indexes.places.size,
            generatedAt: indexes.generatedAt,
          }
        : null,
      ...deps.status(),
    };
  });

  return app;
}
