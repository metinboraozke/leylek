import type { LoggerOptions } from 'pino';

/**
 * Log ayarları — IP adresi, User-Agent ve sorgu dizesi YOK.
 *
 * PAX'teki serileştiriciden uyarlandı. Fastify varsayılan olarak her
 * isteğin uzak adresini loga yazar; Leylek'in "kişisel veri yok" kararı
 * gereği yalnızca yöntem, yol (sorgu dizesi olmadan) ve istek kimliği
 * kaydedilir. Arama sorgusu (nereden, nereye, ne zaman) da loga girmez.
 */
export function stripQuery(url: string | undefined): string | undefined {
  if (!url) return url;
  const i = url.indexOf('?');
  return i === -1 ? url : url.slice(0, i);
}

export const requestSerializer = (request: { method?: string; url?: string; id?: string }) => ({
  method: request.method,
  path: stripQuery(request.url),
  reqId: request.id,
});

export function loggerOptions(level: string, pretty: boolean): LoggerOptions {
  const base: LoggerOptions = {
    level,
    base: { service: 'leylek-backend' },
    redact: { paths: ['req.headers', 'headers', '*.token'], censor: '[gizli]' },
    serializers: { req: requestSerializer },
  };
  return pretty
    ? {
        ...base,
        transport: {
          target: 'pino-pretty',
          options: { colorize: true, translateTime: 'HH:MM:ss.l', ignore: 'pid,hostname,service' },
        },
      }
    : base;
}
