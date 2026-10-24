import type { Price } from '../../search/ports.js';

/**
 * MOTIS `fareTransfers` çözümlemesi (GTFS fare_transfer_rules'tan).
 *
 * Her ücret grubu bir ya da daha çok "etkin ücret bacağı" içerir:
 *   • AB      → yalnızca aktarma ürünü alınır
 *   • A_AB    → ilk etkin bacağın ürünü + aktarma ürünü
 *   • A_AB_B  → her etkin bacağın ürünü + aktarma ürünü
 *   • kural yok → her etkin bacak ayrı alınır
 * Bir bacak için birden çok seçenek varsa (yetişkin, çocuk, günlük…)
 * varsayılan yolcu kategorisindeki en ucuz seçenek alınır.
 */
export interface FareProduct {
  amount?: number;
  currency?: string;
  riderCategory?: { isDefaultFareCategory?: boolean };
}

export interface FareTransfer {
  rule?: 'A_AB' | 'A_AB_B' | 'AB';
  transferProducts?: FareProduct[];
  effectiveFareLegProducts?: FareProduct[][][];
}

const isDefault = (p: FareProduct) => p.riderCategory?.isDefaultFareCategory !== false;

function valid(p: FareProduct): p is Required<Pick<FareProduct, 'amount' | 'currency'>> & FareProduct {
  return typeof p.amount === 'number' && Number.isFinite(p.amount) && typeof p.currency === 'string';
}

/** Ürün listesinden en ucuz varsayılan ürün (para birimi karışıksa ilk birim). */
function cheapest(products: FareProduct[] | undefined): Price | null {
  const options = (products ?? []).filter(valid);
  const preferred = options.filter(isDefault);
  const pool = preferred.length > 0 ? preferred : options;
  let best: Price | null = null;
  for (const p of pool) {
    if (!best || (p.currency === best.currency && p.amount < best.amount)) {
      best = { amount: p.amount, currency: p.currency };
    }
  }
  return best;
}

/**
 * Bir etkin bacağın fiyatı. Seçenekler bir ürün kümesi olabilir
 * (ör. bilet + ek ücret); küme toplamının en ucuzu seçilir.
 */
function legPrice(options: FareProduct[][] | undefined): Price | null {
  const bundles = (options ?? [])
    .map((bundle) => bundle.filter(valid))
    .filter((bundle) => bundle.length > 0 && bundle.every((p) => p.currency === bundle[0]!.currency));
  // Önce tamamı varsayılan kategoride olan seçenekler (indirimli çocuk
  // bileti yetişkine gösterilmesin); hiç yoksa hepsi.
  const preferred = bundles.filter((bundle) => bundle.every(isDefault));
  let best: Price | null = null;
  for (const bundle of preferred.length > 0 ? preferred : bundles) {
    const total = bundle.reduce((sum, p) => sum + p.amount, 0);
    const currency = bundle[0]!.currency;
    if (!best || (currency === best.currency && total < best.amount)) best = { amount: total, currency };
  }
  return best;
}

/** Ücret grubunun alınması gereken ürünleri; çözülemezse `null`. */
export function transferPrices(transfer: FareTransfer): Price[] | null {
  const legs = transfer.effectiveFareLegProducts ?? [];
  const transferProduct = cheapest(transfer.transferProducts);
  const out: Price[] = [];

  const legsToBuy =
    transfer.rule === 'AB' ? [] : transfer.rule === 'A_AB' ? legs.slice(0, 1) : legs;
  for (const options of legsToBuy) {
    const price = legPrice(options);
    if (!price) return null;
    out.push(price);
  }
  if (transferProduct) out.push(transferProduct);
  if (transfer.rule === 'AB' && !transferProduct) return null;
  return out;
}
