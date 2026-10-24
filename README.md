# Leylek

Doğrudan uçuş pahalıysa varış şehrine yakın bir havalimanına uçup kalan yolu
tren, otobüs ya da feribotla tamamlayan rotaları bulan, açık kaynak ve gelir
amacı gütmeyen bir uygulama. Hesap yok, kişisel veri saklanmaz.

Ekranda en az üç seçenek, en ucuzdan en pahalıya sıralı olarak gösterilir.
Doğrudan uçuş da bu seçeneklerden biridir. Fiyat, süre ve risk dengesi en iyi
olan seçenek "Önerilen" olarak işaretlenir.

## Çalıştırma

```bash
flutter pub get
flutter run                                              # örnek veriyle
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # yerel backend ile (Android emülatörü)
flutter test
```

`API_BASE_URL` verilmezse uygulama örnek veriyle (İstanbul → Salzburg) çalışır
ve ekranda bunu açıkça yazar.

Backend `backend/` klasöründe; kurulum ve algoritma için `backend/README.md`.
`test/fixtures/backend_search_response.json` backend'in gerçek arama hattından
üretilmiş yanıt örneğidir; sözleşme testi uygulamanın bunu okuyabildiğini denetler.

## Mimari

Clean Architecture, özellik (feature) bazlı klasörler:

```
lib/
  app/            bileşim kökü (dependencies.dart) ve MaterialApp
  core/           hata, Result, ağ, JSON okuma, zaman, biçimlendirme, tema
  features/
    places/        yer önerisi
    route_search/  rota araması
      domain/        varlıklar, depo arayüzleri, kullanım durumları (saf Dart)
      data/          veri kaynakları, JSON eşleme, depo uygulamaları
      presentation/  cubit'ler, sayfa ve bileşenler
```

Bağımlılık yönü hep içe doğru: `presentation → domain ← data`. Domain katmanı
Flutter'ı, Dio'yu ya da JSON'u bilmez.

SOLID karşılıkları:

- **Tek sorumluluk:** `SearchRoutes` yalnızca doğrular ve devreder,
  `SearchFormCubit` yalnızca formu tutar, `SearchCubit` yalnızca aramayı yürütür.
- **Açık/kapalı:** yeni bir veri kaynağı (ör. önbellekli) mevcut sınıflara
  dokunmadan `RouteSearchDataSource` uygulanarak eklenir.
- **Liskov:** `ApiRouteSearchDataSource` ve `SampleRouteSearchDataSource`
  aynı sözleşmeyi tutar; depo hangisinin takıldığını bilmez.
- **Arayüz ayrımı:** `JsonApi` yalnızca `getJson` sunar; veri kaynakları
  ihtiyaç duymadıkları HTTP ayrıntılarına bağlanmaz.
- **Bağımlılığın tersine çevrilmesi:** üst katmanlar arayüzlere bağlı;
  somut sınıflar yalnızca `app/dependencies.dart` içinde birleştirilir.

## Veri kaynakları ve atıf

Kara bacağı [Transitous](https://transitous.org/sources/) (OpenStreetMap
katkıcıları dahil), havalimanları [OurAirports](https://ourairports.com/data/),
şehirler [GeoNames](https://www.geonames.org/), uçuş fiyatları Aviasales
verisi (son 48 saatte görülen fiyatlar). Uygulama yalnızca Leylek backend'ine
bağlanır; dış servislere kullanıcı verisi gitmez.

## Lisans

MIT. Ayrıntı için `LICENSE`.
