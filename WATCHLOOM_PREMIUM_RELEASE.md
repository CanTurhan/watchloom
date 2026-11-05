# Watchloom Premium — iOS hazırlığı

Çalışma dalı: `version_1.1.0_5`. Kaynak sürümü: **1.1.0 (5)**.
Bu dosya uygulanan değişikliklerle, mağazada ve cihazda henüz yapılmayan işleri ayırır.

## Ürün ve fiyat kararı

| Alan | Değer |
| --- | --- |
| Bundle ID | `com.canturhan.watchloom` |
| Subscription group | `Watchloom Premium` |
| Reference name | `Watchloom Premium Monthly` |
| Product ID | `com.canturhan.watchloom.premium.monthly` |
| Type / Duration | Auto-Renewable / 1 Month |
| Türkiye | **50 TL / ay hedefi** |
| ABD | **$0.99 / ay** |
| Avrupa | ABD fiyatıyla uyumlu Apple yerel karşılıkları; ülke/vergiler kontrol edilecek |
| Introductory offer | Yok; bu sürüm için deneme süresi kararlaştırılmadı |
| Family Sharing | Bu uygulamada yapılandırılmadı |

Türkiye için Connect'te gerçekten sunulan fiyat noktaları kontrol edilmeli. Tam 50 TL yoksa en yakın uygun fiyat noktası (örneğin yalnızca listede varsa 49,99 TL) kullanılmalı ve son değer kayıt altına alınmalı. Tablodaki hedefler henüz mağazaya uygulanmadı. Uygulama döviz hesabı yapmaz ve sabit fiyat göstermez; StoreKit'in `displayPrice` değerini aynen kullanır.

Apple başlangıçta ülkelere göre vergi/kur karşılıklarını sunar. Abonelik fiyatları daha sonra kur değiştikçe otomatik olarak güncellenmez; ülke fiyatlarını dönemsel gözden geçirmek gerekir. [Apple fiyatlandırma belgesi](https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions/).

## Uygulanan davranış

- Free: tüm durumlar toplamında 5 kayıtlı dizi ve ana sekmelerin altında banner reklam.
- Premium: sınırsız kayıt/takip, banner reklamların kaldırılması.
- Bölüm ilerlemesi, hatırlatmalar, notlar, favoriler, istatistikler ve paylaşım Free'de açık.
- Mevcut 5'ten fazla kaydı olan kullanıcıların dizileri ve geçmişi korunur. Premium bitse de düzenleme/takip devam eder; yeni ekleme için sayı 5'in altına inmeli veya Premium aktif olmalı.
- Kontrol hem kayıt akışında hem SQLite işlemi içinde yapılır; eşzamanlı eklemeler sınırı aşamaz. Veritabanı sürümü değişmedi.
- Premium ekranı Kütüphane, iki Ayarlar ekranı ve 6. diziyi ekleme akışından açılır. EN/TR metinler, aylık fiyat, otomatik yenileme açıklaması, geri yükleme, yönetim, gizlilik ve Apple EULA bağlantıları bulunur.
- Erişim StoreKit 2'nin doğrulanmış işlemlerinden gelir. Fiyat alınamaması ücretsiz özellikleri kapatmaz; satın alma fiyat/doğrulama hazır olana kadar kapalıdır. Kart bilgileri uygulamaya gelmez.
- Kullanıcı reklam izni vermeden, başlangıçta/erişim doğrulanırken, satın alma sırasında ve Premium aktifken reklam oluşturulmaz. Başka ekran açıldığında banner kaldırılır. Reklam yükleme hatası boş alan veya tekrar döngüsü oluşturmaz.
- Yerelde başlanmış Yandex entegrasyonu korundu. SDK, uygun ücretsiz kullanıcı izin verdikten sonra gerektiğinde başlatılır; reklam onayı `false`, SDK konum takibi ve isteğe bağlı AppMetrica uygulama/reklam analitiği kapalı. IDFA raporlaması SDK API'siyle kapalı; ATT izni istenmez. Bu ayarlar tüm teknik veri toplamayı ortadan kaldırdığı iddiası değildir.
- Üretim reklam birimi, önceki yerel çalışmadan: `R-M-19758972-1`. Yandex panelinde Watchloom iOS uygulamasına ait olduğu ve aktif olduğu doğrulanmalı.
- Debug/Profile ve `WATCHLOOM_TEST_ADS=true` derlemeleri Yandex'in `demo-banner-yandex` birimini kullanır. Üretimde gerçek birim kullanılır.
- iOS minimumu **15.0**; StoreKit 2 ve Yandex SDK uyumu için Podfile, Xcode ve Flutter framework ayarları eşlendi. Eski iOS sürümleri bu güncellemeyi alamaz.

## Yerel kontroller

5 Kasım 2026 kontrol sonucu: **33 Flutter testi ve 12 arşiv/IPA doğrulama testi geçti**; `flutter analyze` temiz. Yeni Swift satın alma köprüsü gerçek iOS SDK'sıyla typecheck kontrolünden geçti. iOS ayarları, SKU eşleşmesi, StoreKit fixture'ın uygulama kaynaklarına dahil edilmemesi ve reklam ağı kimlikleri kontrol edildi. Bunlar gerçek cihazdaki satın alma/reklam ve tam arşiv testlerinin yerine geçmez; aşağıdaki cihaz listesi henüz tamamlanmadı.

```bash
cd /Users/canturhan/CodingSpace/watchloom
bash scripts/release_ios.sh --check
```

Önbellekte olmayan bağımlılıklar varsa önce normal Terminal'de `flutter pub get` çalıştır. Script kilitli sürümlerle çevrimdışı çözümleme yapar.

Bu ajan oturumunda kullanılan alternatif test çalıştırıcısı:

```bash
WATCHLOOM_FLUTTER_BIN=/Users/canturhan/.cache/solenya-toolchain/flutter/bin/flutter \
WATCHLOOM_TEST_RUNNER=lightweight bash scripts/release_ios.sh --check
```

`ios/Runner/Watchloom.storekit` yalnızca Xcode yerel testi içindir; uygulamanın kaynak paketine eklenmemiştir. Xcode → Edit Scheme → Run → Options → StoreKit Configuration alanından seç. Satın alma, iptal, pending, yenileme, süre sonu ve refund durumlarını StoreKit Transaction Manager ile kontrol et. Sandbox/TestFlight için gerçek Connect ürünü gerekir; fixture yerine geçmez.

## App Store Connect adımları

1. **Watchloom → Monetization → Subscriptions** altında yukarıdaki grup ve aynı Product ID ile aylık ürünü oluştur. Solenya ürününü kullanma. [Apple abonelik kurulumu](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/).
2. Başlangıç fiyatını ABD $0.99 seç; Türkiye fiyatını 50 TL hedefine göre ayrıca ayarla. Avrupa ve diğer mağazaların yerel karşılıklarını gözden geçir; satış bölgelerini uygulamanın bölgeleriyle eşleştir. Uygulamanın indirme ücreti ücretsiz kalmalı.
3. EN adı: `Watchloom Premium Monthly`; açıklama: `Unlimited saved shows and no banner ads.` TR adı: `Watchloom Premium Aylık`; açıklama: `Sınırsız dizi kaydı ve reklamsız kullanım.` Grup yerelleştirmelerini ekle.
4. Subscription review screenshot için cihazdaki gerçek Premium ekranını kullan. Notlarda erişim yollarını ve Free/Premium farkını belirt. İlk aboneliği yeni uygulama sürümüyle ilişkilendirerek gönder. Deneme/intro offer açma.
5. Paid Apps sözleşmesi, vergi/banka ve abonelik durumunu kontrol et. Metadata değişikliklerinin Sandbox'a yansıması zaman alabilir; fiyat hatası hemen kod hatası anlamına gelmez.
6. Gizlilik sayfalarını `docs/` kaynağından yayımla; Premium'daki `https://canturhan.github.io/watchloom/privacy.html` bağlantısının güncel içerikle açıldığını kontrol et. Gizlilik/Support URL'lerini Connect'e ekle. Açıklamaya [Apple standart EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) bağlantısını ekle.
7. **App Privacy** yanıtlarını reklam SDK'sı için güncelle. `Data Not Collected` yanıtını varsayma. Aşağıdaki SDK bulgularını gerçek arşivin Privacy Report'u ile birleştir. Reklamların bulunduğunu yaş derecelendirmesi sorularında da doğru belirt.

### Gizlilik incelemesinin dayanağı

Projeye özel analiz hesabı eklenmedi; Yandex bağımlılığı AppMetrica bileşenlerini de getiriyor. Kurulu SDK 8.3.0'ın paket manifestinde Device ID ve Advertising Data, üçüncü taraf reklam amacıyla, linked/tracking=false olarak beyan edilmiş. AppMetrica bileşenlerinde Coarse Location, Product Interaction, Purchase History, Other Data Types ve tanılama beyanları da bulunabiliyor. Bir modülün projede bulunması her alanın bu yapılandırmada toplandığını tek başına kanıtlamaz. Gerçek arşivde AppMetricaAdSupport modülünün tracking=true beyanı da mevcut; IDFA göndermeyi kapatan public API'nin kullanılması vendor manifestini gizlemez. App Privacy/ATT yanıtları sağlayıcı yapılandırması ve gerçek cihaz davranışıyla doğrulanmalı.

Yandex'in genel App Store tablosu ile paket manifestleri aynı ayrıntıları sunmuyor; son Connect yanıtını yalnızca genel tabloya bakarak işaretleme. Gerçek arşivin Xcode Privacy Report'unu incele; konum kapalı/ATT istenmiyor yapılandırmasını hesaba kat. Gerekiyorsa sağlayıcıdan yapılandırmaya özel açıklama al. Uygulama ve web metinleri reklam/Apple işlemlerini açıklar; satın alma geçmişinin reklam isteğine uygulama tarafından eklenmesi yoktur. [Yandex App Privacy](https://ads.yandex.com/helpcenter/en/dev/ios/app-privacy-apple), [Yandex GDPR](https://ads.yandex.com/helpcenter/en/dev/flutter/gdpr), [Apple App Privacy](https://developer.apple.com/app-store/app-privacy-details/).

## Derleme ve TestFlight

Xcode ile test reklamlı QA arşivi ve IPA oluştur (yükleme yapmaz):

```bash
bash scripts/release_ios.sh --archive-xcode
```

Flutter üzerinden aynı QA derlemesi için:

```bash
bash scripts/release_ios.sh --build-testflight
```

Script önce eski IPA klasörünü `build/ios/previous-ipa.*` altında koruyarak çıkış yolundan ayırır; aynı build numaralı bir önceki dosyanın yanlışlıkla doğrulanmasını da önler. Yeni arşiv ve IPA'nın bundle/sürüm/build/minimum iOS bilgilerini mevcut kaynağa göre doğrular; yanlış metadata veya pakete eklenmiş `.storekit` varsa hata verir. IPA export hatasında eski IPA'yı yükleme. Xcode Organizer veya Transporter ile doğrulanmış build'i yükle.

5 Kasım 2026 imzalı arşiv denemesi, Xcode'un çalışma alanını açamaması (`xcodebuild` error 66) nedeniyle tamamlanmadı. Foundation kaynak türü sorgusu macOS LaunchServices için `kLSDataUnavailableErr` (-10813) döndürdü; proje dosyası `xcodebuild -list -project` ile okunabildi. Bu durum çalışma alanı XML dosyasının eksik olduğu anlamına gelmiyor. Çalışma alanı dosyaları mevcut; yerel Xcode hesabını/sertifikalarını bozacak bir değişiklik yapılmadı. Alternatif olarak Pods ve Runner projeleri ayrı çalıştırılarak **tam imzasız Release arşivi başarıyla oluşturuldu**: `build/ios/archive/Runner.xcarchive`. Native bağımlılıkların iOS tabanı 15'e hizalandı ve Profile yapılandırma uyarısı giderildi. Sonraki IPA exportu bu oturumda Xcode hesabını/Distribution özel anahtarını/provisioning profilini göremediği için başarısız oldu; IPA oluşmadı. Bu arşiv TestFlight'a doğrudan yüklenebilir imzalı dağıtım değildir. Yukarıdaki komutu normal macOS Terminal'de çalıştırıp Xcode çıktısını kontrol etmek gerekiyor.

Connect'te kullanılacak EN/TR açıklama, ürün yerelleştirmeleri ve review notları: [APP_STORE_CONNECT_TEXTS.md](APP_STORE_CONNECT_TEXTS.md).

Hukuki/belge incelemesi ve yayımdan önce hesap sahibi tarafından doğrulanacak konular: [APP_STORE_AUDIT.md](APP_STORE_AUDIT.md).

### Cihazda tamamlanacak testler

- [ ] Eski kurulum üstüne güncellemede mevcut tüm diziler, notlar, favoriler ve geçmiş korunuyor.
- [ ] Yeni Free kullanıcı 5 dizi ekliyor; 6. dizi Premium'u açıyor; vazgeçince kayıt eklenmiyor. Bir dizi silmek yeni yer açıyor.
- [ ] Mevcut diziyi düzenlemek ve bölüm işaretlemek 5 ve 5 üzerindeki kayıtlarda çalışıyor.
- [ ] İlk ücretsiz oturum reklam tercihini soruyor; reddetmek Free özelliklerini kapatmıyor. İzin vermeden SDK başlatılmıyor; geri çekme banner'ı kaldırıyor ve sonraki açılışta SDK kapalı kalıyor.
- [ ] Banner güvenli alanda, navigation'dan ayrı; dar ekran, iPad ve döndürmede doğru. Yükleme hatasında boş alan yok. Detay/Premium ekranı açıldığında reklam kaldırılıyor.
- [ ] Sandbox satın alma gerçek ürünü ve aylık yerel fiyatı gösteriyor. TR/ABD/Avrupa storefront farkları uygulama dili değiştirilmeden de doğru.
- [ ] Satın alma Premium'u açıyor; banner kaldırılıyor; 6 ve üzeri dizi kaydı çalışıyor. Uygulama kapat/aç sonrası erişim korunuyor.
- [ ] Satın alma iptali, pending/Ask to Buy, çevrimdışı durum, geri yükleme, yenileme ve refund kontrolleri yapıldı.
- [ ] Aboneliği iptal etmek imzalı bitiş tarihine kadar erişimi koruyor; süre dolunca Free kuralları dönüyor ve veri silinmiyor. Billing grace açıldıysa o senaryo da test edildi.
- [ ] Geri yükleme aynı Apple Hesabındaki aboneliği getiriyor; yerel kütüphaneyi bulut yedeğinden getirdiği izlenimi vermiyor.
- [ ] Gizlilik/EULA ve Aboneliği Yönet bağlantıları gerçek cihazda açılıyor. VoiceOver, büyük yazı ve TR/EN ekranları kontrol edildi.

QA'da test reklamı kullanıldıysa **Review öncesi yeni build numarasıyla** üretim reklamlı arşiv oluştur (örneğin QA 5, üretim 6; önce `pubspec.yaml` build numarasını güncelle):

```bash
bash scripts/release_ios.sh --build
```

Bu son build'i de TestFlight'ta açılış/Premium/reklam görünürlüğü bakımından kontrol et. Canlı reklamları test tıklamalarıyla doğrulamaya çalışma. Review kararı cihaz kontrollerinden sonra kullanıcıya aittir.

## GitHub sürüm dalı ve TestFlight yükleme

Sürüm dalı: `version_1.1.0_5`. Bu dalın oluşturulması `main` dalını veya web belgelerinin canlı yayımlanmasını değiştirmez.

İmzalı QA build oluşturup TestFlight için App Store Connect'e yüklemek:

```bash
bash scripts/release_ios.sh --upload-testflight
```

Bu işlem App Review'e göndermez ve abonelik/fiyat ayarlarını değiştirmez. Yüklemenin tamamlanmasından sonra Apple'ın build'i işlemesi gerekir. Doğrulanmış bir arşivden dağıtımı yeniden denemek için `--upload-existing` kullanılabilir; arşiv mevcut kaynak sürümüyle eşleşmelidir.
