# Topluluk yetki kontrolü — 1.2.5 (16)

## Sonuç

| Giriş | İçerik | Yeni yorum/yanıt | Kendi yorumunu düzenleme/silme | Başkasının yorumuna up/down |
| --- | --- | --- | --- | --- |
| Apple | Dizi | Geçti | Geçti | Geçti |
| Apple | Film | Geçti | Geçti | Geçti |
| Google | Dizi | Geçti | Geçti | Geçti |
| Google | Film | Geçti | Geçti | Geçti |
| Doğrulanmış e-posta | Dizi | Geçti | Geçti | Geçti |
| Doğrulanmış e-posta | Film | Geçti | Geçti | Geçti |

Bu tablo Firebase Auth/Firestore demo emülatörü ve Flutter widget testlerinin
sonucudur. Gerçek Apple/Google OAuth veya tüm kullanıcıların production
oturumlarının cihazda doğrulandığı anlamına gelmez. Emülatör sağlayıcı testleri
yalnız loopback ortamında kabul edilen sentetik token claim'leri kullanır.

## Test edilen sınırlar

- Üç giriş sağlayıcısının her biri dizi ve film yazarı olarak sınandı. Her
  yazar/içerik kombinasyonunda üç sağlayıcıdan ayrı kullanıcılar upvote,
  downvote'a geçiş ve oy geri alma işlemlerini atomik sayaçlarla tamamladı.
- Widget testleri altı kombinasyonda yeni yorum gönderme, kendi yorumunu
  düzenleme/silme, up/down oy verme ve oy geri alma düğmelerini çalıştırdı.
  Başkasının yorumunda düzenleme/silme menüsü gösterilmedi.
- Anonim ve doğrulanmamış e-posta hesabının yorum oluşturma, düzenleme,
  silme ve up/down yazmaları reddedildi. Doğrulanmamış eski hesabın kök ve
  profil belgeleri testte Admin ile oluşturuldu; ret yalnız eksik bootstrap'e
  dayanmadı.
- Başkasının yorumunu değiştirme/silme ve kendi yorumuna oy verme reddedildi.
  Bekleyen yorum kamuya okunamadı ve yeni oy kabul etmedi.
- Düzenleme yorumu tekrar pending yaptı; mevcut oy toplamları korundu ve yeni
  metin onaydan önce başkasına açılmadı. Gizlenmiş yorumdan eski oyunu geri alma
  güvenli biçimde çalıştı.
- Güncel onay sunucudan okundu; eski onay yeni yorum/düzenleme/oy yazmasını
  engelledi. Açık onay yenilemesinden sonra işlem başarılı oldu.
- Uygulama kökü bulunmayan eski Auth hesabı kendi UID'siyle bootstrap edildi.
  Mevcut hesaplar birleştirilmedi veya verileri taşınmadı.

## Kullanım koşulları

Kullanıcı aktif hesabına girmeli ve güncel topluluk kurallarını kabul etmelidir.
E-posta/parola hesabında doğrulanmış e-posta zorunludur. Apple/Google için
sağlayıcı oturumu doğrulanır; gizli e-posta kullanımı engel değildir. Yorum
metni güvenlik kurallarını geçmeli, topluluk yapılandırması yayına açık olmalı
ve ağ erişimi çalışmalıdır. Karşılıklı engeller ve silinme kilitleri korunur.

Yorum oluşturma/düzenleme arasında sunucuda 30 saniye, oylar arasında 1 saniye
sınırı uygulanır. Günlük sınırlar değiştirilmedi. Emülatör testleri zaman
aralıklarını yalnız kendi demo verilerinde ilerletir; production sınırları
gevşetilmedi. Yorumlar ve düzenlemeler otomatik moderasyon onayından sonra
kamuya açılır.

## Kontroller ve açık kalan doğrulama

- Flutter: 224 test başarılı; `flutter analyze --no-pub` temiz.
- Firebase demo Auth + Firestore: 28 test başarılı.
- Node/moderasyon: 64 test başarılı.
- Production Firestore dağıtım kontrolü başarılı; kural kaynağı değiştirilmedi.
- Canlı Worker doğrulaması mevcut ağda `EPROTO` ile durdu. Bu nedenle tüm
  cihaz/ağlarda yorumların şu anda otomatik yayınlanacağı doğrulanmadı.
- Gerçek cihazda Apple/Google/e-posta girişi, aynı UID ile yeniden kurulum,
  yorumlar, oylar ve canlı moderasyon yeni build üzerinde ayrıca sınanmalı.

Bu çalışma production'a yorum/oy yazmadı ve kullanıcı verisi silmedi. Yerel
build ve başarılı beta yüklemesi canlı moderasyonun doğrulanması değildir.

## Hazırlanan iOS test paketi

- Sürüm: 1.2.5 (16), iOS 15.0 ve üzeri.
- İmzalı arşiv ve IPA başarıyla oluşturuldu; arşiv/IPA paket güvenliği ve sürüm
  eşleşmesi `verify_ios_artifacts.py` ile doğrulandı.
- `codesign --verify --deep --strict` başarılı; 52 privacy manifest envantere
  alındı. Test reklamları açık (`WATCHLOOM_TEST_ADS=true`).
- Arşiv: `build/ios/archive/Runner.xcarchive`.
- IPA: `build/ios/ipa/Watchloom.ipa`.
- Önceki arşiv/IPA silinmeden `build/ios/previous-*` dizinlerine taşındı.
- 16 Kasım 2026 tarihinde App Store Connect'e TestFlight için başarıyla yüklendi.
  Xcode `Upload succeeded` ve `EXPORT SUCCEEDED` bildirdi; Apple paketi işleme
  aşamasına aldı. İşlemenin tamamlandığı ve test grubu erişimi doğrulanmadı.
- Yeni build bekleme düzeltmelerini içerir; daha önce yüklenen 1.2.4 (15) bu
  düzeltmeleri içermez.
- Son yükleme öncesi Firestore, arşiv, kod imzası ve paket güvenliği kontrolleri
  geçti. Worker canlı kontrolü `EPROTO` ile durdu. Kullanıcının beta yükleme
  talebiyle mevcut TestFlight export ayarları kullanılarak doğrudan
  `xcodebuild -exportArchive` çalıştırıldı. Yayın betiğinin kontrolleri
  değiştirilmedi; Worker TLS sorunu açık test sınırlaması olarak kaldı.
- Yerel yükleme günlüğü: `/tmp/watchloom-1.2.5-16-apple-upload.log`.
- Aynı sürüm/build numarasıyla yeniden yükleme yapmayın.
