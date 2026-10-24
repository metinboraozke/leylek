# Leylek backend

Node 22 + Fastify 5. Veritabanı yok; veri dosyaları açılışta belleğe yüklenir,
önbellek bellekte. Uygulama yalnızca bu sunucuya bağlanır.

## Kurulum

```bash
npm install
cp .env.example .env        # TRAVELPAYOUTS_TOKEN ve LEYLEK_CONTACT_EMAIL doldurulmalı
npm run data:import         # OurAirports, Travelpayouts şehir kodları, GeoNames
npm run dev                 # http://localhost:8080
npm test                    # dış servisler sahte, ağa çıkmaz
LIVE=1 npm run live -- "İstanbul" "Salzburg" 2026-11-20   # gerçek ağ, canlı deneme
```

## Uç noktalar

| Uç nokta | Ne yapar | Dış istek |
|---|---|---|
| `GET /v1/search?from=&to=&date=&radiusKm=&maxGroundHours=&currency=` | Aktarmalı rota araması: en az 3, en fazla 5 kart, en ucuzdan pahalıya, biri "Önerilen" | Travelpayouts, Transitous (bütçeli) |
| `GET /v1/places?q=` | Şehir ve havalimanı otomatik tamamlama | Yok |
| `GET /v1/attribution` | Atıf metinleri | Yok |
| `GET /health` | Veri, bütçe ve sigorta durumu | Yok |

## Arama hattı (`src/search`)

| Adım | Dosya | Ne yapar |
|---|---|---|
| 01 | `resolve.ts` | Yerel dizinde çözer; bulamazsa Transitous geocode (30 gün önbellek) |
| 02 | `candidates.ts` | D'ye R km içindeki havalimanları; doğrudan grubu ve adaylar, şehir koduna toplanmış |
| 03 | `flights.ts` | Travelpayouts `prices_for_dates`, `one_way=true`, 6 saat önbellek |
| 04 | `prefilter.ts` | Ağdan önce kaba tahminle eleme; en fazla K = 5 aday Transitous'a gider |
| 05 | `ground.ts` | Transitous `/api/v6/plan`, inişten sonra 45/60/90 dk tampon, 6 saat önbellek |
| 06 | `rank.ts` | Puan, en az 3 karta doldurma, fiyata göre sıra, rozetler |

Dış servisler `search/ports.ts` arayüzlerinin arkasında. Transitous'un önüne
`BudgetedGroundRouter` (önbellek + dakika/gün bütçesi + 429 sigortası) takılı.

## Transitous koşulları

- Her istekte `Leylek/<sürüm> (+<repo>; <iletişim>)` User-Agent'ı gider.
  `LEYLEK_CONTACT_EMAIL` boşsa canlı deneme betiği çalışmaz.
- Yalnızca herkese açık API (`api.transitous.org`). Staging ya da iç uç nokta yok.
- Arama başına en fazla 5 `/plan`; sunucu geneli dakikada 30, günde 3.000
  (`.env`'den ayarlanır).
- Her yanıtta transitous.org/sources ve OpenStreetMap atfı.

## Gizlilik

Loglarda IP, User-Agent ve sorgu dizesi yok; yalnızca yöntem, yol, durum ve
süre. Hız sınırı anahtarı IP'nin her gün yenilenen tuzla HMAC özeti ve
yalnızca bellekte durur. Arama geçmişi saklanmaz. Travelpayouts yanıtındaki
ortaklık bağlantısı istemciye hiç gönderilmez.
