/**
 * Arama için metni sadeleştirir: küçük harf, aksansız, tek boşluk.
 * "Münih", "munih" ve "MÜNİH" aynı anahtara düşer. Uygulamadaki
 * `normalizeForSearch` ile aynı kuralları izler.
 */
const SPECIAL: Record<string, string> = {
  ı: 'i',
  ł: 'l',
  ø: 'o',
  ß: 'ss',
  đ: 'd',
  æ: 'ae',
  œ: 'oe',
  þ: 'th',
};

export function normalize(input: string): string {
  return input
    .toLocaleLowerCase('tr')
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .replace(/[ıłøßđæœþ]/g, (c) => SPECIAL[c] ?? c)
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .trim();
}
