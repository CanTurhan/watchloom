# Worker TLS incelemesi — 2026-11-18

## Doğrulanan durum

Endpoint: `https://watchloom-community.watchloom-canturhan.workers.dev/`.

- Cloudflare yönetim API'sinde Worker'ın `workers.dev` yayını açık, üç secret bağlantısı mevcut ve cron `* * * * *`. Secret değerleri okunup loglanmadı. Son yayın 2026-11-12 tarihli.
- Mevcut ağda Node HTTPS, curl ve Apple URLSession bağlantısı başarısız. URLSession sonucu `NSURLErrorDomain -1200`.
- Aynı Cloudflare IP'sine, beklenen sunucu adını ve sertifika doğrulamasını koruyarak yapılan el sıkışmalarında `developers.cloudflare.com` TLS 1.3 ile başarılı; hem `workers.dev` hem Watchloom Worker adı `ERR_SSL_WRONG_VERSION_NUMBER` ile başarısız.
- İki şifreli DNS sağlayıcısından alınan farklı Cloudflare IP'lerinde de Worker bağlantısı başarısız. Sistem DNS/proxy ayarları değiştirilmedi.
- Ücretsiz Pages kontrol adresleri zaman aşımı/bağlantı sıfırlaması verdi. Hesaptaki mevcut Pages projesinin adresi ayrıca çözümlenemedi. Başka uygulamanın yapılandırması değiştirilmedi.

Bu bulgular alan adına göre değişen bir TLS erişim yolunu gösteriyor.
Ağ/operatör/SNI filtrelemesi olasıdır; hangi ara bileşenin veya sağlayıcının
nedeni olduğu kanıtlanmadı. Cloudflare yönetim API'sine erişebilmek, Worker'ın
halka açık girişine veya canlı moderasyon sağlayıcılarına erişimi doğrulamaz.

## Uygulanan değişiklik

`scripts/diagnose_worker_network.mjs` artık DNS'ten elde edilen aynı IP üzerinde
Worker, `workers.dev` ve normal Cloudflare kontrol adıyla paralel, doğrulanmış
TLS el sıkışmaları yapar. Sonuçlar sabit tanı kodlarıyla raporlanır:

- `workers_domain_tls_route_failure`: kontrol başarılı, Worker ve ana alan adı başarısız.
- `worker_hostname_tls_route_failure`: kontrol başarılı, Worker başarısız.
- `worker_tls_same_address_verified`: Worker el sıkışması başarılı; bu tek başına HTTP sağlık veya moderasyon onayı değildir.
- `tls_route_comparison_inconclusive`: kontrol eksik/başarısız; ağ nedeni hakkında kesin sonuç verilmez.

Güncel ağdaki sonuç `workers_domain_tls_route_failure`; sağlık sonucu hâlâ
`worker_http_unreachable`. İlgili tanı/istemci testlerinin 19'u geçti.

Komut:

```sh
node scripts/diagnose_worker_network.mjs https://watchloom-community.watchloom-canturhan.workers.dev
```

Bu komut yalnızca herkese açık bağlantıları sınar. Firebase ID token'ı,
moderasyon anahtarı veya hesap bilgisi göndermez. Sertifika kontrolü kapatılmaz,
HTTP'ye geçilmez ve kimlik bilgileri farklı bir alan adına yönlendirilmez.

## İlk inceleme sonrasındaki durum

1. Aynı Mac'i farklı bir operatörün telefon erişim noktasına veya bağımsız bir ağa bağlayıp komutu yeniden çalıştırın. VPN/özel DNS durumunu kaydedin; mevcut güvenlik yazılımını/sertifika denetimini kapatmayın.
2. `worker_public_health_verified` alındığında `node scripts/configure_community_automation.cjs verify` çalıştırın. Bu ikinci kontrol gerçek sağlayıcı/IAM/index hazırlığını da doğrular; halka açık sağlık yanıtı tek başına yeterli değildir.
3. Doğrudan HTTPS erişimi için kullanıcıya ait, Cloudflare'a bağlanabilecek özel alan adı bir seçenektir. Sertifika ve uçtan uca sağlık doğrulanmadan canlı endpoint değiştirilmemeli. Aşağıdaki kuyruk yolu, uygulamanın yorum göndermek için bu doğrudan bağlantıya bağımlılığını kaldırır.

Cloudflare'ın [Custom Domains belgesi](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/)
özel alan adını Worker'a yönlendirme ve sertifika sürecini açıklar. Kullanıcının
mevcut bir alan adı yok; bu inceleme sırasında alan adı satın alınmadı, ücretli
hizmet açılmadı veya varsayımsal bir alternatif devreye alınmadı.

Bu çalışma TLS sorununu çözülmüş saymaz. Uygulama yorumları önce Firestore'a
kaydeder; başarısız HTTP moderasyon çağrısı kaydı geri almaz. Yayına çıkış hâlâ
sunucu moderasyonuna bağlıdır; bu ağdan canlı erişim henüz doğrulanmamıştır.

## Aynı ağda tamamlanan çözüm: doğrulanmış sunucu kuyruğu

Kullanıcı farklı bağlantı sağlayamayacağını belirtti ve mevcut ağdan devam
etmemizi istedi. Ücretsiz, bize ait gerçek bir Pages statik tanı yayını da
denendi. Bağımsız şifreli DNS kaydı doğru IP'leri döndürdü ancak doğrulanmış
HTTPS bağlantısı sıfırlandı. Bu adres uygulamaya eklenmedi. Geçici Pages projesi
ve CLI'nin beklenmedik şekilde açtığı ayrı tanı Worker'ı temizlendi; mevcut
moderasyon Worker'ı ve diğer uygulamalar korundu. Wrangler'ın yeni Pages
komutlarında ajan algılayıp Workers'a yönlendirebilmesi nedeniyle gelecekte
izole çıktı dizini ve açık proje kimliği kullanılmalıdır.

Uygulanan kalıcı akış:

1. Yorum/yanıt/owner düzenlemesi, aynı kurallar ve atomik rate-limit sayaçlarıyla
   Firestore'da `pending` olarak saklanır. Başarısız yazı başarıya çevrilmez.
2. İstemcinin Worker'a hızlandırıcı HTTP çağrısı arka planda, zaman sınırlı ve
   UID'ye bağlı çalışır. Bu çağrı kayıt sonucunu veya açık yorum formunu artık
   15 saniye bekletmez; hata hiçbir zaman yayımlama onayı sayılmaz.
3. Mevcut dakikalık sunucu cron'u kuyruğu işler. Dil/güvenlik, hesap, onay,
   reply/block, revision ve kota kontrolleri aynen korunur. Hizmet başarısızsa
   içerik yayımlanmaz; mevcut yeniden deneme davranışı sürer.
4. Yorum ekranı yalnızca bağlı kullanıcının o içerikteki pending/rejected
   kuyruğunu Firestore'dan dinler. Durum değiştiğinde normal yetkili feed
   sorguları yenilenir; ret geri bildirimi veya onaylı yorum ekrana gelir.
   Hesap/içerik değişiminde ve dispose sırasında eski dinleyici ayrılır.
5. Release kontrolü, Worker HTTPS'ine ağ bağlantısı kurulamadığında yalnızca
   belirli ağ hata kodları için yöneticiye kapalı bir kontrol isteği kullanır.
   Sunucunun gerçek cron'u Firebase/Auth/index ve sentetik OpenAI kontrollerini
   **kendi runtime'ında** yapıp yeni istek nonce'ına bağlı sonuç yazar. Eski,
   yabancı, başarısız veya nonce'ı eşleşmeyen sonuç hazırlık kanıtı sayılmaz.
   HTTP yetki/sağlayıcı hatası veya bozuk sertifika bu yöntemle gizlenmez.

`communityAutomation/verificationRequest` ve `communityAutomation/queueVerification`
istemci kurallarında kapalıdır. Apple, Google, doğrulanmış e-posta ve anonim
isteklerle okuma/yazma reddi emülatörlerde sınandı. Uygulama bu yönetici kanalını
kullanmaz; kullanıcı verisi, API anahtarı veya servis hesabı istemciye eklenmedi.

### Canlı sonuç

- Yeni Worker aynı isim, endpoint, secret bağlantıları ve cron ile yayımlandı.
  Deployment version: `533cf138-2ff4-441f-8995-b47daaafd7fc`.
- `node scripts/configure_community_automation.cjs verify` gerçek cron üzerinden
  başarıyla tamamlandı: `live provider/IAM/indexes and health verified (firestore-queue)`.
  Bu sonuç yerel bir simülasyon değildir; yayımlanan Worker'ın sentetik sağlayıcı
  kontrolü ve Firestore kanıtı nonce/tarih/kimlik eşleştirilerek doğrulandı.
- 235 Flutter testi, 73 Node testi, 34 Python testi, 28 Auth/Firestore emülatör
  testi ve gerçek `workerd` cron/sağlayıcı runtime testi geçti. Flutter analiz
  temiz. 1.2.6 (17) yerel imzasız iOS build yeniden üretildi; bundle ID ve
  derlenen Firebase kaynakları ayrıca kontrol edildi.
- Kullanıcı kayıtları, diziler/filmler, yorumlar, oylar ve yedekler silinmedi veya
  taşınmadı. Hiçbir gerçek kullanıcı adına test yorumu yayımlanmadı.

Bu çözüm **ağdaki workers.dev TLS engelini kaldırdığımız** anlamına gelmez;
yorum akışının bu girişe bağımlılığını kaldırır ve gerçek sunucu hazırlığını
başka bir güvenli yoldan doğrular. Gerçek cihazda sağlayıcı girişi, yorumun
cron ile onay/ret dönüşü ve mevcut kurulumun üzerine güncellemede kütüphanenin
korunması son QA adımıdır. Sonraki adımda **1.2.6 (17) TestFlight'a yüklendi**
ve Apple `VALID / READY_FOR_BETA_TESTING` olarak işledi. Ayrıntılar:
[TestFlight 1.2.6 raporu](testflight-1.2.6.md). Kullanıcı cihaz QA'sından sonra
App Store yayın sürecini kendisi ilerletecek.
