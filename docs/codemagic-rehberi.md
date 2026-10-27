# Leylek · Codemagic ile derleme rehberi

Bu rehber, Leylek'i Codemagic'te sıfırdan derlemeyi adım adım anlatır: Android `.aab`/`.apk` ve iOS TestFlight.
Her adımda **ne yaptığın** ve **neden yaptığın** yazıyor. Böylece bir şey ters giderse nereye bakacağını bilirsin.

---

## 0. Büyük resim: Codemagic ne yapıyor?

Codemagic bir **CI/CD** servisi:

- **CI** (sürekli entegrasyon): Her `git push`'ta kodu temiz bir makinede derler ve testleri koşar.
- **CD** (sürekli teslim): İstediğinde imzalı paketi üretir ve mağazaya yükler.

Akış şöyle işler:

```
GitHub (kod + codemagic.yaml)
   │  push ya da "Start new build"
   ▼
Codemagic sanal makinesi (Linux ya da Mac)
   │  1. depoyu klonlar
   │  2. codemagic.yaml'daki adımları sırayla çalıştırır
   │  3. sırları (keystore, Apple anahtarı, API_BASE_URL) arayüzden alır
   ▼
Çıktılar (artifacts): .aab, .apk, .ipa, test raporu
   │
   ▼
App Store Connect / e-posta / indirme
```

**Neden kendi bilgisayarında değil?**

- **iOS paketi yalnızca Mac'te derlenir.** Senin Windows makinende bu imkânsız; Codemagic'in Mac mini M2'leri bu işi yapar.
- **Yerelde Android'i engelleyen iki sorun var.** Bu makinede yol "Masaüstü" içeriyor ve JDK yok. Codemagic'in makinesinde ikisi de sorun değil.

**Önemli kural:** Şifreler, anahtar dosyaları ve backend adresi `codemagic.yaml`'a **yazılmaz**. Yaml yalnızca isimlerini anar (`leylek_upload`, `codemagic`, `leylek`). Asıl değerler Codemagic arayüzünde, şifreli saklanır. Depo açık kaynak olunca da sırlar açığa çıkmaz.

---

## 1. Depodaki `codemagic.yaml`'ı tanı

Dosya proje kökünde: [`codemagic.yaml`](../codemagic.yaml). İçinde üç **workflow** (iş akışı) var:

| Workflow | Ne zaman çalışır | Makine | Ne üretir |
|---|---|---|---|
| `kontrol` | `main`'e her push ve PR'da **otomatik** | Linux | Test sonuçları, E2E JSON raporu |
| `android-release` | Sen **elle** başlatınca | Linux | İmzalı `.aab` (Play Store) + `.apk` (telefona kurmak için) |
| `ios-testflight` | Sen **elle** başlatınca | Mac mini M2 | İmzalı `.ipa`, App Store Connect'e yüklenir |

Bir workflow'un parçaları şunlar:

```yaml
android-release:                 # workflow kimliği
  name: Android release          # arayüzde görünen ad
  max_build_duration: 45         # dakika; aşarsa durdurulur (para/kota koruması)
  instance_type: linux_x2        # hangi makine
  environment:
    flutter: stable              # Flutter sürümü
    java: 17                     # Gradle için JDK
    android_signing:
      - leylek_upload            # arayüze yükleyeceğin keystore'un ADI
    groups:
      - leylek                   # arayüzdeki ortam değişkeni grubu (API_BASE_URL burada)
  scripts:                       # sırayla çalışan kabuk komutları
    - name: Testler
      script: flutter test
  artifacts:                     # derleme bitince indirilebilecek dosyalar
    - build/app/outputs/bundle/release/*.aab
  publishing:                    # bitince ne yapılsın (e-posta, mağaza)
    email: ...
```

Bilmen gereken iki ifade:

- `$BUILD_NUMBER`: Codemagic her derlemede bunu 1 artırır. Mağazalar aynı derleme numarasını iki kez kabul etmez; bu sayede hiç elle değiştirmezsin.
- `${API_BASE_URL:+--dart-define=API_BASE_URL=$API_BASE_URL}`: "API_BASE_URL doluysa bu parametreyi ekle, boşsa hiç ekleme" demek. Boşsa uygulama örnek veriyle derlenir ve log'da büyük bir **UYARI** satırı çıkar.

---

## 2. Codemagic hesabı ve depoyu bağlama

1. <https://codemagic.io/signup> adresine git ve **"Sign up with GitHub"** ile giriş yap.
2. GitHub, Codemagic'e depo erişimi isteyecek. **"Only select repositories"** → `metinboraozke/leylek` seç. Depo gizli olsa da çalışır.
3. Codemagic panelinde **"Add application"** → **GitHub** → `leylek` deposunu seç.
4. **Project type** sorusunda **"Flutter App (via codemagic.yaml)"** seç. Workflow Editor'ı **seçme**: o arayüzden ayar yapar ve yaml'ı yok sayar.
5. Uygulama sayfasında **"Check for configuration file"** butonuna bas. `codemagic.yaml` bulununca üç workflow listelenir.
   - Bulunamazsa yaml henüz GitHub'a gönderilmemiştir. Önce push edilmesi gerekir.

**Ücretsiz kota:** Kişisel hesaplarda aylık ücretsiz derleme dakikası var. Güncel kotayı **Billing** sayfasından gör. Mac derlemesi Linux'tan daha çok dakika yer. `max_build_duration` takılan bir derlemenin kotanı yemesini engeller.

---

## 3. Ortam değişkeni grubu: `leylek`

Yaml `groups: - leylek` diyor; bu grubun arayüzde var olması gerekir, yoksa derleme en başta *"Environment group leylek not found"* hatasıyla düşer.

1. Uygulama sayfası → **Environment variables** sekmesi.
2. **Variable name:** `API_BASE_URL`
3. **Variable value:** Backend'in herkese açık adresi, örneğin `https://api.leylek.app`.
   - Mutlaka **https** olmalı. Android ve iOS, release derlemesinde düz http'ye izin vermez.
   - Sonda `/` olmasın.
4. **Group:** `leylek` yaz. Yoksa oluşturulur.
5. **Secure** kutusunu işaretle. Değer log'larda `*****` olarak görünür.
6. **Add**.

**Backend henüz yayında değilse:** Grubu yine de oluştur ama `API_BASE_URL` yerine zararsız bir değişken koy, örneğin `LEYLEK_NOT` = `ornek-veri`. Derleme çalışır, uygulama örnek veri gösterir. Backend yayına girince `API_BASE_URL`'ü eklemen yeterli; yaml'a dokunmazsın.

---

## 4. Android: yükleme anahtarı (keystore)

### 4.1 Kavramlar

- **Keystore (`.jks`):** Uygulamayı imzalayan özel anahtarın bulunduğu dosya. Play Store, güncellemenin senden geldiğini bu imzayla anlar.
- **Upload key / App signing key:** Play Console'da **Play App Signing** açıkken sen paketi *upload key* ile imzalarsın. Google, kullanıcılara dağıtırken kendi *app signing key*'iyle yeniden imzalar. Upload key'i kaybedersen Google'dan sıfırlatabilirsin; Play App Signing olmadan kaybetmek ise uygulamayı bir daha güncelleyememek demektir.

### 4.2 Keystore'u oluştur (bir kez)

`keytool` JRE ile de gelir; senin makinedeki Temurin 17 yeterli. PowerShell'de, **proje klasörünün dışında** bir yerde çalıştır:

```bash
keytool -genkey -v -keystore leylek-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias leylek
```

Sorular ve cevaplar:

- **Keystore şifresi:** Güçlü bir şifre koy ve şifre yöneticisine kaydet.
- **Ad soyad, birim, şehir…:** Gerçek bilgilerini yazabilirsin. Kullanıcı bunları görmez.
- **Anahtar şifresi:** Enter'a basarsan keystore şifresiyle aynı olur.

Sonuç: `leylek-upload.jks`. Bu dosyayı ve şifreyi **iki ayrı yerde** yedekle (örneğin şifre yöneticisi ve harici disk). **Git'e koyma.** `android/.gitignore` zaten `*.jks` ve `key.properties` dosyalarını dışarıda tutuyor.

### 4.3 Codemagic'e yükle

1. Codemagic → sağ üstten **Team settings** (kişisel hesapta **Personal account settings**) → **codemagic.yaml settings** → **Code signing identities** → **Android keystores** sekmesi.
2. **Upload keystore**:
   - **Keystore file:** `leylek-upload.jks`
   - **Keystore password:** Keystore şifresi
   - **Key alias:** `leylek`
   - **Key password:** Anahtar şifresi
   - **Reference name:** `leylek_upload`. Bu, yaml'daki `android_signing: - leylek_upload` ile **birebir aynı** olmalı.
3. **Add keystore**.

### 4.4 Gradle bunu nasıl kullanıyor?

`android/app/build.gradle.kts` dosyasında anahtar şu sırayla aranır:

1. Codemagic'in koyduğu ortam değişkenleri: `CM_KEYSTORE_PATH`, `CM_KEYSTORE_PASSWORD`, `CM_KEY_ALIAS`, `CM_KEY_PASSWORD`.
2. Yerelde `android/key.properties` dosyası (ileride bilgisayarında imzalı derlemek istersen).
3. İkisi de yoksa **debug anahtarı** kullanılır. Böyle bir paket telefonda çalışır ama Play Store'a **yüklenemez**.

Yerelde imzalı derlemek istersen `android/key.properties` dosyası şöyle olur (git'e girmez):

```
storeFile=C:/anahtarlar/leylek-upload.jks
storePassword=...
keyAlias=leylek
keyPassword=...
```

---

## 5. İlk derleme: `kontrol` workflow'u

Önce imzasız, sırsız bir workflow ile ortamın sağlam olduğunu gör.

1. Uygulama sayfası → **Start new build**.
2. **Branch:** `main`, **Workflow:** `Kontrol (test)` → **Start new build**.
3. Derleme sayfasında adımlar sırayla akar. Her birine tıklayınca log'u açılır:

   | Adım | Ne yapar | Düşerse |
   |---|---|---|
   | Flutter paketleri | `flutter pub get` | `pubspec.yaml` bozuk ya da paket sürümü uyuşmuyor |
   | Statik analiz | `flutter analyze` | Kodda uyarı/hata var; log'da dosya ve satır yazar |
   | Flutter testleri | 33 birim + widget testi | Hangi testin neden düştüğü log'da |
   | Backend paketleri | `npm ci` (lock dosyasına birebir) | `package-lock.json` eski |
   | Backend testleri | 82 Vitest testi | Log'da test adı |
   | Havalimanı ve şehir verisi | OurAirports + GeoNames indirir | İndirme sitesi geçici kapalı; tekrar dene |
   | Uçtan uca | Sahte servislerle 13 kontrol | **Artifacts**'taki JSON'da hangi kontrolün düştüğü yazar |

4. Yeşilse hazırsın. Bundan sonra `main`'e her push'ta bu workflow kendiliğinden çalışır (`triggering` bölümü).

---

## 6. Android release derlemesi

1. **Start new build** → Workflow: **Android release**.
2. Adımlar: paketler → backend adresi kontrolü (log'da `Backend: https://…` ya da **UYARI** satırı) → testler → `.aab` → `.apk`.
3. Bitince **Artifacts** bölümünde şu dosyalar olur:
   - `app-release.aab`: Play Store'a yüklenen paket.
   - `app-release.apk`: Telefona doğrudan kurmak için.
   - `mapping.txt`: Kod karıştırma eşlemesi (çökme raporlarını okumak için).
   - Ayrıca `metinbora61@gmail.com` adresine bitti/düştü e-postası gelir.

**APK'yı telefonda denemek:** APK'yı telefona indir, dosyaya dokun ve "bilinmeyen kaynaklardan yükleme" iznini o uygulama için aç. Debug anahtarıyla imzalı bir sürüm telefonda zaten kuruluysa önce onu kaldır, çünkü imzalar farklı.

**Play Console'a ilk yükleme (elle):**

1. <https://play.google.com/console> adresinde geliştirici hesabı aç (tek seferlik ücret).
2. **Uygulama oluştur** → ad `Leylek`, ücretsiz.
3. **Test** → **Dahili test** → **Yeni sürüm oluştur**. Play App Signing'i kabul et (önerilen).
4. `app-release.aab`'ı sürükle. Sürüm notu yaz ve kaydet.
5. Gizlilik politikası, veri güvenliği formu ve içerik derecelendirmesi doldurulmadan herkese açık sürüme geçilemez (test raporundaki eksikler listesine bak).

İleride Play'e otomatik yükleme istersen yaml'daki `publishing` bölümüne `google_play` eklenir. Bunun için Google Cloud'da bir hizmet hesabı gerekir. İlk sürümü mutlaka elle yükle; Google, ilk paketi API'den kabul etmiyor.

---

## 7. iOS TestFlight derlemesi

### 7.1 Gerekenler

- **Apple Developer Program** üyeliği (yıllık ücretli).
- Paket kimliği: `app.leylek.leylek`. Yayından sonra değiştirilemez.

### 7.2 Apple tarafı

1. **App ID:** <https://developer.apple.com/account> → **Certificates, IDs & Profiles** → **Identifiers** → **+** → **App IDs** → **App**.
   - Description: `Leylek`. Bundle ID: **Explicit** `app.leylek.leylek`. Ek yetenek gerekmiyor → **Register**.
2. **App Store Connect'te uygulama kaydı:** <https://appstoreconnect.apple.com> → **Apps** → **+** → **New App**.
   - Platform: iOS. Name: `Leylek`. Primary language: Türkçe. Bundle ID: listeden `app.leylek.leylek`. SKU: `leylek-ios`.
   - Bu kayıt olmadan yükleme *"No suitable application records were found"* hatasıyla düşer.
3. **App Store Connect API anahtarı** (Codemagic'in senin adına Apple'la konuşması için):
   - App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API** → **Team Keys** → **+**.
   - Name: `codemagic`. Access: **App Manager**.
   - **Download API Key** ile `.p8` dosyasını indir. **Yalnızca bir kez indirilebilir**, iyi sakla.
   - Sayfadaki **Issuer ID** ve anahtarın **Key ID** değerini not et.

### 7.3 Codemagic tarafı

1. **Team settings → Team integrations → Developer Portal → Manage keys → Add key**:
   - **App Store Connect API key name:** `codemagic`. Yaml'daki `app_store_connect: codemagic` ile **aynı** olmalı.
   - **Issuer ID**, **Key ID** ve `.p8` dosyası.
2. **Dağıtım sertifikası:** **codemagic.yaml settings → Code signing identities → iOS certificates** → **Generate certificate** → tür **Apple Distribution**, az önce eklediğin anahtarı seç.
   - Codemagic sertifikayı Apple'da oluşturur ve saklar. Çıkan `.p12` şifresini kaydet.
   - Apple hesap başına en fazla birkaç dağıtım sertifikasına izin verir; sınır dolarsa eskisini sil ya da onun `.p12` dosyasını **Upload** et.
3. **Provisioning profile:** Hangi sertifikanın hangi uygulamayı imzalayabileceğini söyleyen belgedir.
   - Apple Developer → **Profiles** → **+** → **App Store Connect** (Distribution) → App ID `app.leylek.leylek` → az önce oluşan sertifika → ad `Leylek App Store` → **Generate**.
   - Codemagic → **iOS provisioning profiles** → **Fetch profiles** → `Leylek App Store`'u seç → **Download selected**.

Yaml'daki şu bölüm, derleme sırasında bu sertifika ve profili bundle ID'ye göre bulup makineye kurar:

```yaml
ios_signing:
  distribution_type: app_store
  bundle_identifier: app.leylek.leylek
```

`xcode-project use-profiles` adımı da Xcode projesini bu profili kullanacak şekilde ayarlar.

### 7.4 Derle ve yükle

1. **Start new build** → **iOS TestFlight**.
2. Adımlar: paketler → backend kontrolü → profiller → `flutter build ipa` (10–20 dk) → App Store Connect'e yükleme.
3. Yükleme bitince Apple paketi **işler** (Processing, 5–30 dk). Bitince e-posta gelir.
4. App Store Connect → Leylek → **TestFlight** sekmesinde derleme görünür.
   - **Şifreleme sorusu sorulmaz.** `Info.plist`'e `ITSAppUsesNonExemptEncryption = false` eklendi; uygulama yalnızca standart HTTPS kullanıyor.
5. **Internal Testing** → **+** ile grup oluştur → kendini ekle. Telefona **TestFlight** uygulamasını kur ve davetle Leylek'i yükle.

Yaml'da `submit_to_testflight: false`. `true` yaparsan işleme bitince derleme otomatik olarak test grubuna açılır.

---

## 8. Sık hatalar ve çözümleri

| Hata (log'da) | Neden | Çözüm |
|---|---|---|
| `Environment group "leylek" not found` | Grup oluşturulmadı | 3. adım |
| `Keystore reference "leylek_upload" not found` | Keystore adı farklı | 4.3'te Reference name `leylek_upload` olmalı |
| `Keystore was tampered with, or password was incorrect` | Şifre yanlış | Keystore'u sil ve doğru şifreyle yeniden yükle |
| `No matching profiles found for bundle identifier` | Profil yok ya da başka bundle ID için | 7.3 / 3. madde; profil `app.leylek.leylek` için ve **App Store** türünde olmalı |
| `No suitable application records were found` | App Store Connect'te uygulama kaydı yok | 7.2 / 2. madde |
| `The bundle version must be higher than the previously uploaded version` | Aynı derleme numarası | Yaml zaten `$BUILD_NUMBER` kullanıyor; elle numara verdiysen kaldır |
| `Invalid large app icon … alpha channel` | İkonda saydamlık | `remove_alpha_ios: true` ile çözüldü; ikon değişirse `dart run flutter_launcher_icons` |
| Uygulama açılıyor ama "örnek veri" diyor | `API_BASE_URL` boş | Log'daki **UYARI** satırına bak; 3. adım |
| Uygulama "bağlantı kurulamadı" diyor | Adres http ya da yanlış | https olmalı; tarayıcıda `<adres>/health` açılıyor mu, dene |
| Derleme `max_build_duration`'da kesildi | Takılan adım | Log'da son adımı bul; süreyi gerekirse artır |

---

## 9. Yerelde bu iş için ne değişti?

- `codemagic.yaml`: Üç workflow.
- `android/app/build.gradle.kts`: Release imzası Codemagic değişkenlerinden ya da `key.properties` dosyasından okunuyor; ikisi de yoksa debug anahtarı kullanılıyor.
- `ios/Runner/Info.plist`: Şifreleme beyanı (`ITSAppUsesNonExemptEncryption = false`).
- Uygulama simgesi: `assets/ikon.jpg` dosyasından Android ve iOS simgeleri üretildi.
  - Yapılandırması `pubspec.yaml` içinde `flutter_launcher_icons` bölümünde. İkon değişirse `dart run flutter_launcher_icons` çalıştırıp commit'lemek yeter.
- Neden yaml'da ikon üretmiyoruz? Derleme makinesi her seferinde kodu değiştirmemeli. Depoda ne varsa paket de o olmalı (tekrarlanabilir derleme).

---

## 10. Sözlük

- **Workflow:** Yaml'daki bir iş akışı; adımlar listesi.
- **Instance:** Derlemenin koştuğu sanal makine (`linux_x2`, `mac_mini_m2`).
- **Artifact:** Derlemenin ürettiği ve indirilebilen dosya.
- **AAB / APK:** AAB, Play Store'un istediği paket biçimidir; Google onu cihaza göre böler. APK doğrudan kurulabilen pakettir.
- **Keystore / upload key:** Android imza anahtarı dosyası.
- **Certificate (iOS):** Apple'ın "bu geliştirici gerçekten sen" onayı.
- **Provisioning profile:** "Bu sertifika şu uygulamayı şu dağıtım için imzalayabilir" belgesi.
- **`.p8` API anahtarı:** Codemagic'in senin yerine App Store Connect'e erişmesi için.
- **Bundle ID / applicationId:** Uygulamanın mağazadaki kalıcı kimliği (`app.leylek.leylek`).
- **`--dart-define`:** Derleme anında koda sabit gömme. `API_BASE_URL` bu yolla verilir.
- **`$BUILD_NUMBER`:** Codemagic'in her derlemede artırdığı sayı.
