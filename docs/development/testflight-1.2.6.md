# Watchloom 1.2.6 (17) — TestFlight

2026-11-18: `bash scripts/release_ios.sh --upload-testflight` tamamlandı.

- Bundle ID: `com.canturhan.watchloom`; mevcut uygulama kimliği korundu.
- İmzalı arşiv oluşturuldu, sürüm/build/Firebase kaynak kontrolü geçti.
- Xcode yükleme sonucu: `Upload succeeded`, `EXPORT SUCCEEDED`.
- App Store Connect build ID: `55886946-db77-41c7-bd5a-89811699a478`.
- Apple işleme sonucu: `VALID`; internal `READY_FOR_BETA_TESTING`, external
  `READY_FOR_BETA_SUBMISSION`. Bu kayıt Apple'ın App Review onayı değildir.
- Mevcut `Test` grubu internal ve `hasAccessToAllBuilds=true`; tester/grup ayarı
  değiştirilmedi. Kullanıcı TestFlight cihaz kontrolünden sonra kendisi App
  Store yayın sürecine ilerleyeceğini belirtti.
- Önceki arşiv ve IPA korunarak yeni arşiv üretildi. App Store'a public yayın
  veya harici beta incelemesi başlatılmadı, test kullanıcıları değiştirilmedi.

## İçerik

- Doğrulanmış Apple/Google/e-posta topluluk oturumlarında güncel token kontrolü.
- Kendi yorumunu düzenleme/silme; başkasına müdahale engeli ve rate-limitler.
- Düzenlenen metnin yeniden moderasyona gönderilmesi ve onay öncesi gizliliği.
- Uygunsuz metinde Türkçe/İngilizce düzeltme geri bildirimi.
- HTTP moderasyon hızlandırıcısının kayıt formunu bekletmemesi; gerçek sunucu
  cron'u ve Firestore kuyruğu üzerinden moderasyon ve canlı durum yenilemesi.
- Aynı bundle ID, veritabanı adları ve şema 6 korunuyor; veri sıfırlama yok.

## Kontroller

Yayın komutu 235 Flutter, 73 Node ve 34 Python testini yeniden çalıştırdı;
Flutter analiz temiz, gerçek workerd runtime testi başarılı. Son Firestore
emülatör kontrolünde 28 test geçti. Yayımlanan Worker'ın nonce'a bağlı gerçek
cron kontrolü Firebase/Auth/indeks/moderasyon hazırlığını doğruladı.

Doğrudan `workers.dev` TLS bağlantısı bu ağda hâlâ başarısız. Bu sürüm yorum
kaydını o bağlantıya bağımlı tutmaz; sertifika denetimi gevşetilmedi. Ayrıntılar:
[TLS ve kuyruk raporu](community-worker-tls.md).

Kaynak hash manifesti: `build/release-audit/watchloom-1.2.6-17-source.json`.
Yükleme logu: `/tmp/watchloom-1.2.6-17-testflight-release.log`.
Arşiv: `build/ios/archive/Runner.xcarchive`.

## Cihazda son kontrol

TestFlight'tan mevcut kurulumun üzerine güncelleyin; uygulamayı silmeyin.
Örnek dizi/film, not, favori ve bölüm ilerlemesini güncelleme öncesi/sonrası
karşılaştırın. Apple, Google ve doğrulanmış e-posta hesaplarında yorum/yanıt,
owner düzenleme/silme, up/down oy, ret sonrası uygun metinle tekrar gönderme
ve otomatik onay/ret durum güncellemesini sınayın. Mevcut 30 saniyelik gönderim/
düzenleme aralığı ve günlük kota korunuyor. Başka kullanıcının yorumunu
düzenleme/silme reddedilmeli. Bu gerçek cihaz kontrolleri henüz agent tarafından
yapılmış sayılmaz.
