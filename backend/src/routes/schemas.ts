import { z } from 'zod';

const MAX_DAYS_AHEAD = 330;

function dayOffset(day: string, now: number): number {
  const today = new Date(now).toISOString().slice(0, 10);
  return Math.round((Date.parse(`${day}T00:00:00Z`) - Date.parse(`${today}T00:00:00Z`)) / 86_400_000);
}

/** `/v1/search` sorgusu. Uygulamadaki `SearchRoutes` ile aynı sınırlar. */
export function searchQuerySchema(now: () => number = Date.now) {
  return z.object({
    from: z.string().trim().min(2, 'Nereden yola çıkacağını seç.').max(80),
    to: z.string().trim().min(2, 'Nereye gideceğini seç.').max(80),
    date: z
      .string()
      .regex(/^\d{4}-\d{2}-\d{2}$/, 'Tarih YYYY-AA-GG biçiminde olmalı.')
      .refine((d) => Number.isFinite(Date.parse(`${d}T00:00:00Z`)), 'Geçersiz tarih.')
      // Saat dilimi farkı yüzünden bir gün esneklik: İstanbul'da bugün,
      // UTC'de henüz dün olabilir.
      .refine((d) => dayOffset(d, now()) >= -1, 'Geçmiş bir tarih seçilemez.')
      .refine((d) => dayOffset(d, now()) <= MAX_DAYS_AHEAD, `En fazla ${MAX_DAYS_AHEAD} gün sonrası aranabilir.`),
    radiusKm: z.coerce.number().int().min(50).max(400).default(250),
    maxGroundHours: z.coerce.number().min(1).max(8).default(5),
    currency: z.enum(['TRY', 'EUR']).default('TRY'),
    lang: z.enum(['tr', 'en']).default('tr'),
  });
}

export const placesQuerySchema = z.object({
  q: z.string().trim().min(1).max(80),
  lang: z.enum(['tr', 'en']).default('tr'),
});
