/**
 * Elle tutulan ülke listeleri. Değiştikçe güncellenir.
 */

/** Schengen bölgesi (2025 itibarıyla Romanya ve Bulgaristan dahil). */
export const SCHENGEN = new Set([
  'AT', 'BE', 'BG', 'CH', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FI', 'FR', 'GR', 'HR', 'HU',
  'IS', 'IT', 'LI', 'LT', 'LU', 'LV', 'MT', 'NL', 'NO', 'PL', 'PT', 'RO', 'SE', 'SI', 'SK',
]);

/**
 * Varış olarak kabul edilen ülkeler: Transitous'ta uzun mesafe toplu
 * taşıma verisi olan Avrupa ülkeleri. transitous.org/sources'a bakılarak
 * ayda bir gözden geçirilir. Türkiye bilinçli olarak yok: kara bacağı
 * Türkiye içinde kalan rotalar kapsam dışı.
 */
export const DESTINATION_COUNTRIES = new Set([
  ...SCHENGEN,
  'GB', 'IE', 'CY', 'RS', 'BA', 'ME', 'MK', 'AL', 'XK', 'MD', 'MC', 'SM', 'AD', 'VA',
]);

/** Kalkış ve yer araması için veri alınan ülkeler. */
export const DATA_COUNTRIES = new Set([...DESTINATION_COUNTRIES, 'TR', 'UA']);

/**
 * Kara bacağı kaba maliyet tahmini (EUR): taban + km başı.
 * Başlangıç değerleri; F2'de Transitous'tan gelen gerçek fiyatlarla
 * ülke ülke ayarlanacak.
 */
export const GROUND_COST = {
  default: { base: 4, perKm: 0.11 },
  byCountry: {
    CH: { base: 6, perKm: 0.25 },
    NO: { base: 6, perKm: 0.2 },
    GB: { base: 5, perKm: 0.18 },
    DK: { base: 5, perKm: 0.18 },
    SE: { base: 5, perKm: 0.15 },
    AT: { base: 4, perKm: 0.14 },
    DE: { base: 4, perKm: 0.13 },
    NL: { base: 4, perKm: 0.15 },
    BE: { base: 4, perKm: 0.13 },
    FR: { base: 4, perKm: 0.12 },
    IT: { base: 3, perKm: 0.09 },
    ES: { base: 3, perKm: 0.09 },
    PT: { base: 3, perKm: 0.08 },
    PL: { base: 2, perKm: 0.06 },
    CZ: { base: 2, perKm: 0.06 },
    HU: { base: 2, perKm: 0.06 },
    RO: { base: 2, perKm: 0.05 },
    BG: { base: 2, perKm: 0.05 },
    GR: { base: 3, perKm: 0.08 },
    HR: { base: 3, perKm: 0.08 },
  } as Record<string, { base: number; perKm: number }>,
};

/** Türkçe şehir adları. GeoNames temel dosyası dil etiketi taşımadığı için elle. */
export const TURKISH_CITY_NAMES: Record<string, string> = {
  'Munich|DE': 'Münih',
  'Vienna|AT': 'Viyana',
  'Prague|CZ': 'Prag',
  'Rome|IT': 'Roma',
  'Milan|IT': 'Milano',
  'Naples|IT': 'Napoli',
  'Florence|IT': 'Floransa',
  'Venice|IT': 'Venedik',
  'Turin|IT': 'Torino',
  'Athens|GR': 'Atina',
  'Thessaloniki|GR': 'Selanik',
  'Warsaw|PL': 'Varşova',
  'Krakow|PL': 'Krakov',
  'Copenhagen|DK': 'Kopenhag',
  'Brussels|BE': 'Brüksel',
  'Lisbon|PT': 'Lizbon',
  'Belgrade|RS': 'Belgrad',
  'Geneva|CH': 'Cenevre',
  'Zurich|CH': 'Zürih',
  'The Hague|NL': 'Lahey',
  'Cologne|DE': 'Köln',
  'Nuremberg|DE': 'Nürnberg',
  'Bucharest|RO': 'Bükreş',
  'Budapest|HU': 'Budapeşte',
  'Sofia|BG': 'Sofya',
  'Seville|ES': 'Sevilla',
  'London|GB': 'Londra',
  'Paris|FR': 'Paris',
  'Moscow|RU': 'Moskova',
  'Kyiv|UA': 'Kiev',
  'Skopje|MK': 'Üsküp',
  'Sarajevo|BA': 'Saraybosna',
  'Tirana|AL': 'Tiran',
  'Nicosia|CY': 'Lefkoşa',
  'Istanbul|TR': 'İstanbul',
  'Izmir|TR': 'İzmir',
  'Iskenderun|TR': 'İskenderun',
  'Isparta|TR': 'Isparta',
};

/** Ülkelerin halk arasındaki Türkçe adları; resmî adın yanında aranır. */
export const COUNTRY_ALIASES: Record<string, string[]> = {
  GB: ['İngiltere', 'Britanya'],
  NL: ['Holland'],
  CZ: ['Çek Cumhuriyeti'],
  BA: ['Bosna'],
  MK: ['Makedonya'],
  VA: ['Vatikan'],
  XK: ['Kosova'],
};

const regionNames = new Intl.DisplayNames(['tr'], { type: 'region' });
const regionNamesEn = new Intl.DisplayNames(['en'], { type: 'region' });

/** ISO ülke kodunun İngilizce adı ("DE" → "Germany"); ülke aramasında da eşleşsin. */
export function countryNameEn(code: string): string {
  try {
    return regionNamesEn.of(code) ?? code;
  } catch {
    return code;
  }
}

/** ISO ülke kodunun Türkçe adı ("AT" → "Avusturya"). */
export function countryNameTr(code: string): string {
  try {
    return regionNames.of(code) ?? code;
  } catch {
    return code;
  }
}
