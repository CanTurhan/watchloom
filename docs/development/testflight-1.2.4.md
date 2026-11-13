# Watchloom 1.2.4 (15)

Topluluk oturum doğrulama düzeltmeleri için hazırlanan iOS test sürümü.

## Doğrulananlar

- Flutter: 204 test; Node: 64 test; Python: 33 test başarılı.
- Flutter analyze temiz.
- İmzalı iOS arşivi ve App Store IPA oluşturuldu.
- `verify_ios_artifacts.py` arşiv ve IPA sürüm/paket güvenlik kontrolleri başarılı.
- `codesign --verify --deep --strict` arşiv uygulaması için başarılı.
- Test reklamları açık (`WATCHLOOM_TEST_ADS=true`).
- Önceki arşiv ve IPA `build/ios/previous-*` dizinlerinde korundu.

## Yayın durumu

TestFlight yüklemesi yapılmadı. Son canlı topluluk doğrulaması Worker TLS
bağlantısında `EPROTO` hatasıyla durdu. Firestore kontrolü son denemede geçti;
ağ değişiklikleri sırasında sonuçlar değiştiğinden canlı erişim yeniden
doğrulanmalı. Bu kayıt gerçek cihaz testi veya yükleme başarısı anlamına gelmez.

Yerel çıktılar:

- `build/ios/archive/Runner.xcarchive`
- `build/ios/ipa/Watchloom.ipa`

Bağlantı düzeldiğinde `bash scripts/release_ios.sh --upload-existing` hazır
arşivi Firebase, canlı topluluk, güvenlik ve sürüm kontrollerinden sonra yükler.
Arşiv farklı kaynak veya sürümle yeniden oluşturulduysa önce çıktıları kontrol
edin. Yükleme sonrasında App Store Connect işlemesi ve gerçek cihazda giriş,
topluluk onayı, yorum/yanıt/düzenleme/silme, yedekleme ve satın alma akışları
ayrıca doğrulanmalı.
