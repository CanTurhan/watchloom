# Watchloom — App Store ve hukuki yayın incelemesi

Tarih: 5 Kasım 2026. İncelenen güncel kaynak: `feature/firebase-auth-sync`, sürüm `1.1.0+6`. Yayımlanmış `version_1.1.0_5` anlık görüntüsü korunuyor.
Bu kayıt teknik ve belge kontrollerinin sonucudur. Sağlayıcı sözleşmelerinin kabulünü, içerik hak sahipliğini veya tüm ülkelerde hukuki uygunluğu tek başına kanıtlamaz.

## Düzeltilen eksikler

| Bulgu | Yapılan düzeltme |
| --- | --- |
| Reklam SDK'sı için gerçek kullanıcı tercihi/geri çekme ekranı yoktu | İlk ücretsiz oturumda Reklam ve Gizlilik açılır. İzin verilene kadar SDK başlatılmaz. İki seçenek aynı görünürlükte; reddetmek Free özelliklerini veya Premium'u kapatmaz. Karar/sürüm/tarih yerelde saklanır. Eski veya bozuk izin kaydı reklamı açmaz. |
| Yalnızca `setUserConsent(false)` tüm veri işleme duruyormuş izlenimi verebilirdi | Uygulama tercihi ayrıca SDK'yı sınırlar. Kişiselleştirilmiş reklam onayı/konum takibi kapalı kalır. Başlatılmış SDK'nın oturum içindeki teknik işlemleri ve sonraki açılış davranışı açıkça anlatılır. |
| İsteğe bağlı AppMetrica uygulama/reklam raporlaması açık bırakılmıştı | Native köprü `setAppAdAnalyticsReportingEnabled(false)` çağrısını SDK başlamadan uygular. Bu, zorunlu teknik reklam işlemenin tamamen durduğu iddiası değildir. |
| Gerçek arşivde AppMetricaAdSupport izleme beyanı taşıyor | IDFA ve konum raporlaması public AppMetrica API'leriyle SDK başlamadan ve başladıktan sonra kapatıldı. İzin geri çekilince AppMetrica gönderimi tüm reporter'lar için kapatılır. Vendor manifesti değiştirilmedi; App Privacy yanıtları bu koşullu beyanın gerçek kullanımı doğrulanarak verilmeli. |
| Banner için ayrı uygunsuz reklam bildirim yolu yoktu | Banner yanında Reklam Bildir düğmesi, destek yönlendirmesi ve reklam tercihlerini değiştirme açıklaması eklendi. |
| Gizlilik bağlantısı fiyat ekranında dış web sayfasına bağımlıydı | Tam EN/TR politika uygulamada çevrimdışı açılır. Web politika, sağlayıcı, iletişim, Apple EULA/iade ve TVmaze lisans bağlantıları gerçek düğmelerdir. |
| Gizlilik metni saklama, silme, paylaşım ve yurt dışı işlemeyi eksik anlatıyordu | Veri sorumlusu adı, amaçlar, işleme sebepleri, alıcılar, yerel/sağlayıcı saklaması, paylaşım, geri çekme ve uygulanabilen haklar eklendi; web metinleriyle eşlendi. |
| Profil Ayarlar ekranında anlatılan veri silme yolu bulunmuyordu | Her iki Ayarlar ekranına aynı veri silme bileşeni eklendi. |
| Veri silme bildirimi aboneliğin devam ettiğini söylemiyordu | Açık uyarı ve Apple aboneliğini yönetme eylemi eklendi. İşlem Apple erişimini veya ödemeyi değiştirmez. Dil/gizlilik tercihlerinin korunduğu açıklanır. |
| Silinen izleme verileri geçici paylaşım görsellerinde kalabiliyordu | Veri silme, yalnızca uygulamanın oluşturduğu `watchloom_*.png` dosyalarını da kaldırır; ilgisiz dosya ve sembolik bağlantılara dokunmaz. |
| TVmaze lisansı yalnızca genel kaynak adıyla anılıyordu | CC BY-SA 4.0 ve kaynak bağlantıları, yapılan biçimlendirme açıklaması eklendi. Aylık paylaşım görseli ve paylaşım metni kaynak/lisans atfı taşır. Uygulamanın tamamının veya kişisel notların bu lisansa girdiği iddia edilmez. |
| Native SDK lisansları uygulama içi lisans listesinde eksikti | CocoaPods'un 29 lisans bildirimi değiştirilmeden uygulamaya eklendi; Ayarlar → Açık Kaynak Lisansları listesinde gösterilir. |
| iOS bundle desteklenen uygulama dillerini açıkça bildirmiyordu | Mevcut EN/TR yerelleştirmeleri `CFBundleLocalizations` ile iOS metadata'sına eklendi. |
| Bazı Pods hedefleri uygulamanın iOS 15 tabanının altında kalmıştı | Post-install, uygulamanın desteklemediği iOS 11–13 hedeflerini 15'e yükseltir; daha yüksek hedefi olan bağımlılığı düşürmez. |
| Uygulama gizlilik manifestinde yerel tercih kullanımı açıklanmıyordu | UserDefaults için `CA92.1` gerekçesi eklendi. SDK manifestleri kendi beyanlarını korur. Envanter komutu hazırlandı. |

## Mevcut ve korunan yayın davranışı

- Ödemeler Apple StoreKit 2 üzerinden; harici ödeme/satın alma bağlantısı yok.
- Aylık abonelik adı, süresi, Apple'ın yerel fiyatı, otomatik yenileme/iptal açıklaması, geri yükleme ve yönetim erişimi var. Deneme süresi vaadi yok.
- İptal/ödeme bekleme/hata Premium'u doğrulama olmadan açmaz. Doğrulanmış erişim kendi bitiş süresinden sonra uzatılmaz. Satın alma geri yüklemek yerel kütüphane yedeği olarak sunulmaz.
- Free 5 kayıt, Premium sınırsız takip/reklamsız kullanım. Eski kayıtlar ve geçmiş korunur. Diğer takip özellikleri Free'de açıktır.
- Apple, Google ve e-posta ile isteğe bağlı Firebase hesabı, ayrı hesap/misafir kütüphaneleri ve bulut yedeği var. E-posta doğrulaması, açık misafir kopyalama seçimi, çakışma çözümü ve uygulama içi hesap silme eklendi. Premium yalnızca StoreKit tarafından doğrulanır.
- Kütüphane, notlar ve arama tercihleri reklam isteğine eklenmez. Sistem paylaşımı yalnızca kullanıcı eylemiyle başlar.
- Yerel StoreKit fixture'ı uygulama paketine dahil edilmez; QA reklamları üretimden ayrı derleme seçeneğidir. Eski IPA, yeni export yolundan ayrılarak saklanır.

## Yayından önce hesap/sağlayıcı düzeyinde tamamlanacaklar

1. **İletişim:** Veri sorumlusu/sağlayıcı adı `Yunus Can Turhan`. Kullanıcının verdiği `can.turhan.web@gmail.com`, uygulama ve EN/TR web kaynaklarında özel destek/gizlilik iletişimi olarak eklendi. Canlı web sayfaları ayrıca yayımlanıp doğrulanmalı.
2. **Reklam ve yurt dışı aktarım:** Firebase/Google ve gerçek Yandex publisher hesabının koşulları, ilgili veri alıcısı/işleyen rolleri ve gerekli sözleşme/güvenceler hesap sahibi tarafından doğrulanmalı. Uygulamadaki reklam tercihi, KVKK m.9 veya GDPR kapsamındaki uluslararası aktarım şartlarının yerine geçen genel izin değildir. Sürekli yurt dışı aktarımını yalnızca arızi aktarım istisnasına dayandırma. Sağlayıcı düzenlemeleri doğrulanamıyorsa reklamlı üretim yayını hazır kabul edilmemeli; SDK'yı başlatmadan yapılan QA ayrı değerlendirilebilir. [KVKK güncel aktarım açıklaması](https://www.kvkk.gov.tr/Icerik/2053/Yurtdisina-Aktarim), [Yandex politikası](https://yandex.com/legal/confidential/en/).
3. **Canlı sayfalar:** Yerelde EN/TR web belgeleri hazır. GitHub API, repoyu public ve issues/Pages etkin gösteriyor; bu oturumda Pages adreslerine HTTP erişimi doğrulanamadı. Yeni dosyalar yayımlandıktan sonra Support/Privacy URL'lerini oturum açmadan ve telefondan açarak kontrol et. Yerel dosyalar henüz yayımlanmış kabul edilmez.
4. **App Privacy:** İsteğe bağlı hesap nedeniyle hesap kimliği, sağlanan e-posta/ad ve Firebase’e yüklenen kütüphane, notlar ve izleme geçmişi için uygulama işlevi amacı değerlendirilmeli. Firebase Analytics açık değil. Gerçek arşivde `AppMetricaAdSupport.bundle/PrivacyInfo.xcprivacy`, `NSPrivacyTracking=true` ve tracking domainleri beyan ediyor. Uygulama public SDK API'siyle IDFA raporlamasını kapatıyor; bu, vendor dosyasını silme veya değiştirme gerekçesi değildir. Sağlayıcının bu yapılandırmayı desteklediğini ve cihazda izleme yapılmadığını doğrula. Yalnızca uygulamanın kendi manifesti `false` diye otomatik olarak Not Tracking seçme. `Data Not Collected` seçimini de varsayma. SDK manifesti, kapatılan isteğe bağlı raporlama ve gerçek arşivin Xcode Privacy Report'unu birlikte değerlendir. Manifestte bir alanın bulunması, bu yapılandırmada her alanın toplandığını tek başına kanıtlamaz. IDFA/ATT izni istenmiyor; yeni bir SDK ya da mediation ağı eklenirse bu değerlendirme yenilenmeli.
5. **İçerik/yaş:** TVmaze metadata lisansı ve resmî kaynak bağlantıları mevcut. Afişler ve diğer üçüncü taraf görseller için yayın kullanımının ilgili haklarla uyumunu doğrula; yalnızca kaynak göstermek ek hakları otomatik vermez. TV katalog özet ve görsellerini de hesaba katarak gerçek yaş derecelendirmesi sorularını yanıtla; uygulama çocuk kategorisine yönelik hazırlanmadı. [TVmaze API lisansı](https://www.tvmaze.com/api#licensing), [TVmaze copyright policy](https://www.tvmaze.com/site/copyright).
6. **Abonelik ve ticari bilgiler:** Yeni ürünü, ülke fiyatlarını, satış bölgelerini, sözleşme/vergi/banka bilgilerini Connect'te tamamla. AB dağıtımında DSA trader durumu ve gerekiyorsa Apple'ın istediği adres/e-posta/telefon doğrulamasını gerçek ticari durumuna göre yap. Abonelik/reklamdan gelir elde etme, Apple'ın değerlendirme etkenlerindendir; yalnızca bireysel geliştirici hesabı olmak otomatik olarak non-trader anlamına gelmez. [Apple DSA rehberi](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements).
7. **Review:** İlk aboneliği uygulama sürümüyle ilişkilendir; uygulama açıklamasına Apple standart EULA bağlantısını ekle. İnceleme notlarında Premium yollarını, 5 dizi sınırını ve sürekli sınırsız takip/reklamsız kullanım değerini açıkla. Fiyat/satın alma testi Connect ürünü hazırlandıktan sonra gerçek Sandbox/TestFlight'ta yapılmalı.

## Kanıt ve derleme

Uygulanan kontroller ve son build sonucu `WATCHLOOM_PREMIUM_RELEASE.md` içinde kayıtlıdır. Yeni testler kullanıcı tercihi, geri çekme, eski izin kaydı, çevrimdışı politika erişimi, veri silme uyarısı ve geçici kişisel veri temizliğini kapsar. Fiziksel cihaz ve App Store Connect işlemleri bu testlerle tamamlanmış sayılmaz.

SDK manifest envanteri:

```bash
python3 scripts/privacy_manifest_inventory.py ios/Pods --output build/release-audit/sdk-privacy.json
```

Arşiv başarılı olduktan sonra aynı komutu `build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app` üzerinde de çalıştır. App Privacy cevapları için sonuçları otomatik kopyalama.

Güncel doğrulama: **51 Flutter testi, 21 Python kontrolü ve 7 Node kuruluma/güvenliğe ilişkin test başarılı; Dart analizi temiz.** Kullanıcının normal Terminal’inde sekiz Firebase Emulator kontrolü geçti. Spark faturalandırma kontrolü, varsayılan Firestore veritabanı oluşturma, kurallar/indeksler ve canlı anonim erişim reddi doğrulandı. Ücretli backend kurulmadı.

Firebase iOS 12.19.3 güvenlik güncellemesi kuruldu. Core/Firestore/Internal 12.19.3, Auth 12.19.0 beklenen resmi bileşen sürümleridir. Güncel kaynakla **tam imzasız Release arşivi** başarılı: `build/ios/archive/AuthSpark-SecurityPatch-Unsigned.xcarchive`. Arşivde sürüm 1.1.0 (6), iOS 15.0, doğru Firebase projesi, güncel native SDK sürümleri ve yerel StoreKit fixture’ının bulunmadığı doğrulandı. 57 native lisans bildirimi paketlenir. Eski SDK 12.6 arşivi dağıtılmamalı; yayın betiği gerçek arşiv/IPA SDK sürümlerini de denetler.

Hesap sahibi Apple Developer’da Watchloom App ID için Sign in with Apple özelliğini etkinleştirdiğini ve Service ID/Firebase domain/dönüş adresini kaydettiğini bildirdi. Runner Debug/Profile/Release yetki dosyası, automatic signing, takım ve bundle değerleri Xcode build settings üzerinden doğrulandı. Apple anahtarının yerel P-256 biçimi doğrulandı ve depo içindeki kopya Git dışına taşındı. Hesap sahibinin normal Terminal’inde Firebase Apple sağlayıcısı kaydedildi; enabled, Service ID, takım, Key ID ve bundle değerleri sunucudan tekrar okunarak eşleştirildi. [Apple kurulum adımları](APPLE_SIGN_IN_SETUP.md) ve yerel anahtarı günlüklemeden Firebase’e bağlayan araç hazırlandı. Bu ayar doğrulaması gerçek Apple girişinin veya token revocation’ın başarılı olduğunu henüz kanıtlamaz. Hesap sahibi e-posta kaynağı/SPF kaydını tamamladığını bildirdi; gerçek teslim ve imzalı profil kontrolü bekliyor. Cihaz kontrolleri kullanıcının seçimiyle TestFlight QA üzerinden yapılacak. Gerçek cihazda Google/Apple/e-posta, silme, ikinci cihaz, yeniden kurulum, Premium ve reklam testleri tamamlanmalı.

Hesap silme Spark üzerinde istemci tarafından yürütülür: taze kimlik doğrulama, yazma kilidi, tüm yedeklerin silinmesi, Auth silme ve cihaz önbelleği temizliği. Kesinti tekrar girişle tamamlanır. Eski oturumların hesabı yeniden oluşturmaması için asgari UID/zaman/rastgele kanıt kaydı tutulur; tamamlanmış kayıt iki saatlik sunucu güvenlik süresinden sonra uygulama tekrar bağlandığında temizlenir. Uygulama kaldırılırsa kayıt kalabilir. Metinler bu durumu ve özel destek yolunu açıklar; ücretli zamanlanmış sunucu temizliği vaat edilmez. Firestore disk kalıcılığı kapalıdır. App Check enforcement henüz yapılandırılmadı; etkinleştirilmeden önce istemci ve attestation yolları test edilmeli.

İmzalı build-6 IPA/TestFlight yüklemesi veya App Review gönderimi yapılmadı. Kısıtlı oturumun Xcode/Keychain erişim sorunu, normal macOS hesabındaki sertifikaların bozuk olduğunu kanıtlamaz. İmzalı QA dağıtımı normal Terminal/Xcode hesabında yapılacak; cihaz kontrolleri bu TestFlight build’i üzerinde tamamlanacak. Bu oturumun güncel arşiv denemesi No Accounts/no provisioning profile hatasıyla durdu; Keychain sorgusunda sıfır görünür imzalama kimliği vardı. EN/TR web kaynakları henüz canlı yayımlanmış sayılmaz.

Kurulum ve cihaz kontrol listesi: [FIREBASE_SETUP.md](FIREBASE_SETUP.md). Apple tarafındaki dayanak: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — 2.1/2.5.18, 3.1.1/3.1.2, 5.1 ve 5.2. Teknik testler sağlayıcı sözleşmelerini, tüm ülkelerde hukuki uygunluğu veya Apple onayını garanti etmez.
