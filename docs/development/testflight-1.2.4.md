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

13 Kasım 2026 tarihinde 1.2.4 (15) paketi App Store Connect'e başarıyla
yüklendi. Xcode `Upload succeeded` ve `EXPORT SUCCEEDED` bildirdi; Apple
paketi işleme aşamasına aldı. İşlemenin tamamlandığı veya test gruplarına
dağıtımın etkin olduğu henüz doğrulanmadı.

Son canlı topluluk doğrulaması Worker TLS bağlantısında `EPROTO` hatasıyla
durdu. Firestore kontrolü geçti. Kullanıcının TestFlight yükleme talebiyle,
arşiv güvenlik/sürüm ve kod imzası ayrıca doğrulanıp mevcut TestFlight export
ayarları kullanılarak `xcodebuild -exportArchive` ile doğrudan beta yüklemesi
yapıldı. Yayın betiğindeki kontroller değiştirilmedi. Bu yükleme canlı
moderasyonun veya tüm özelliklerin gerçek cihazda doğrulandığı anlamına gelmez.

Yükleme günlüğü yerelde `/tmp/watchloom-1.2.4-15-apple-upload.log` konumunda.

Yerel çıktılar:

- `build/ios/archive/Runner.xcarchive`
- `build/ios/ipa/Watchloom.ipa`

Aynı sürüm/build numarasıyla yeniden yükleme yapmayın. App Store Connect
işlemesi ve gerçek cihazda giriş, topluluk onayı,
yorum/yanıt/düzenleme/silme, yedekleme ve satın alma akışları ayrıca doğrulanmalı.
