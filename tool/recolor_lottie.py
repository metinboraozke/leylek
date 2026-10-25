"""Lottie animasyonlarını Leylek paletine çeker.

    python tool/recolor_lottie.py <kaynak_klasör>

Kaynak klasörde LottieFiles'tan indirilen ham JSON'lar beklenir
(stork.json, plane.json, bus.json). Çıktı assets/lottie/.
Dolgu ve çizgi renkleri aşağıdaki tablolarla eşlenir; Flutter'ın Lottie
oynatıcısı After Effects ifadelerini desteklemediği için ifadeler silinir
(aksi halde web önizlemesinde de çizim bozuluyor).
"""
import json
import pathlib
import sys

PALETTE = {
    # Uçan leylek: soluk mavi-beyaz tüyler parlak beyaza, gölgeler nötr griye
    'stork': {
        '#DFF3F7': '#FFFFFF',
        '#CFF3F9': '#F4F7F9',
        '#B4E9EF': '#E3E9ED',
        '#B5E0EA': '#DCE3E8',
        '#FF9D33': '#E8542F',  # gaga ve bacaklar: gaga turuncusu
        '#FFB000': '#F2A23A',
        '#3A89FC': '#2F6E9E',  # bohça: göğün koyu tonu
        '#8CB3F8': '#FFFFFF',  # bulut ve rüzgâr
        '#6E98F4': '#FFFFFF',
    },
    # Araçlar beyaz çizgi: uçağın beyaz dolgusu saydam yapılır ki üçü de
    # aynı çizgisel dilde görünsün. Okunurluk için uygulama arkalarına
    # yumuşak bir gölge çizer (bkz. VehicleLottie).
    'plane': {'#F26F21': '#FFFFFF', '#FFFFFF': ('#FFFFFF', 0)},
    'bus': {'#4653A0': '#FFFFFF'},
}


def to_hex(c):
    return '#%02X%02X%02X' % tuple(int(round(v * 255)) for v in c[:3])


def to_rgba(hex_color, alpha):
    h = hex_color.lstrip('#')
    return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)] + [alpha]


def recolor(node, table, stats):
    if isinstance(node, dict):
        if node.get('ty') in ('fl', 'st'):
            k = node.get('c', {}).get('k')
            if isinstance(k, list) and k and isinstance(k[0], (int, float)):
                new = table.get(to_hex(k))
                if new:
                    # Değer ya renk ya da (renk, saydamlık) çifti.
                    color, alpha = new if isinstance(new, tuple) else (new, None)
                    if alpha is None:
                        node['c']['k'] = to_rgba(color, k[3] if len(k) > 3 else 1)
                    else:
                        node['c']['k'] = to_rgba(color, 1)
                        node['o'] = {'a': 0, 'k': alpha * 100}
                    stats['renk'] += 1
        if isinstance(node.get('x'), str) and 'k' in node:
            del node['x']
            stats['ifade'] += 1
        for v in node.values():
            recolor(v, table, stats)
    elif isinstance(node, list):
        for v in node:
            recolor(v, table, stats)


def main():
    src = pathlib.Path(sys.argv[1])
    out = pathlib.Path(__file__).resolve().parent.parent / 'assets' / 'lottie'
    out.mkdir(parents=True, exist_ok=True)
    for name, table in PALETTE.items():
        data = json.loads((src / f'{name}.json').read_text(encoding='utf-8'))
        stats = {'renk': 0, 'ifade': 0}
        recolor(data, table, stats)
        (out / f'{name}.json').write_text(json.dumps(data, separators=(',', ':')), encoding='utf-8')
        print(f'{name}: {stats["renk"]} renk değişti, {stats["ifade"]} ifade silindi')


if __name__ == '__main__':
    main()
