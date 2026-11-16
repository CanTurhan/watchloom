# Giriş ve topluluk yükleme kurtarması

Bu değişiklikler daha önce yüklenen 1.2.4 (15) paketinde yoktur; cihazda
denenebilmesi için yeni bir iOS build'i gerekir.

## Bekleme sınırları

- Topluluk ekranındaki her okuma 20 saniye ile sınırlıdır. Profil okuması
  başarısızsa yeni kimlik oluşturma formu gösterilmez; hata ve tekrar deneme
  sunulur. Profil başarılı, engel listesi başarısızsa profil ve mevcut onay
  korunur; okunamayan engel listesi yanlışlıkla boşmuş gibi gösterilmez.
- Okuma sonucunu yalnız aynı hesap, ekran revizyonu ve yükleme denemesi kullanır.
  Süresi dolan veya kapatılan ekranın geç sonucu yeni hesabı değiştiremez.
- Mevcut sürümde kabul edilmiş topluluk onayı sunucudan yüklenince korunur.
  Yeni veya eski politika onayı olan hesaplarda açık onay şartı devam eder.
- Firebase oturum yenileme adımları 15 saniyede zaman aşımına uğrar. Arka planda
  üst üste yenileme başlatılmaz. Başka hesaba ait geç hata yeni hesabı çıkışa
  zorlamaz. Topluluk oturum doğrulama okumalarında 20 saniye sınırı uygulanır.
- Apple/Google yerel giriş isteği Dart Future'ı zaman aşımına uğratılarak iptal
  edilmiş sayılmaz. 45 saniye sonra giriş ekranındaki dönen gösterge yerine
  açıklama gösterilir ve ekrandan geri dönülebilir. İlk işlem gerçek sonucunu
  verene kadar ikinci giriş isteği başlatılmaz. Yerel sağlayıcı ekranı açıksa
  kullanıcı işlemi oradan tamamlamalı veya iptal etmelidir.
- Girişten sonra bildirim temizliği ve yerel kütüphane hazırlığı toplam
  20 saniyede tamamlanmazsa ana ekrandaki yükleme biter ve tekrar deneme sunulur.
  Önceki kütüphane/veritabanı silinmez; hazırlanamayan yeni controller'lar
  bırakılır, geç sonuçlar başka oturuma kurulmaz.
- Kaydedilmiş yorumun moderasyon uyandırma isteği en fazla 15 saniye beklenir.
  Uyandırma başarısızlığı kaydedilmiş yorumu yeniden göndermeye neden olmaz;
  mevcut sunucu kuyruğu ve zamanlanmış işlem korunur.

Okuma zaman aşımı yardımcısı yorum/profil yazmalarına uygulanmaz. Sunucuda geç
tamamlanabilen bir yazma iptal olmuş sayılmaz veya otomatik yeniden gönderilmez.
Sahiplik, politika, moderasyon ve spam kuralları değiştirilmemiştir. Gizli
bilgiler yerine yalnız sabit işlem adları ve hata kodları loglanır.

## Doğrulama

- Flutter: 218 test başarılı; `flutter analyze --no-pub` temiz.
- Firebase Auth + Firestore demo emülatörleri: 20 test başarılı.
- Node: 64 test; Python: 33 test başarılı.
- Testler yanıt vermeyen istekleri, geç sonuçları, hesap değişimini, ekranın
  kapanmasını, yerel giriş iptalini, ikinci giriş kilidini, profil/engel listesi
  kısmi başarısını ve kayıtlı onayı kapsar. Gerçek Apple/Google OAuth akışı ve
  cihazdaki satın alma/yedekleme kontrollerinin yerine geçmez.

## Worker TLS hâlâ açık

Mevcut ağda Worker DNS çözülüyor fakat Node ve sistem curl HTTPS/TLS
bağlantısında `EPROTO` / `CURL_35` alıyor. Daha önce farklı ağda aynı Worker'a
TLS 1.3 ve HTTP 200 ile erişilmiş olması ağ yolunun etkili olduğunu gösterir;
kesin operatör/filtre nedeni kanıtlanmamıştır.

Bu değişiklikler TLS arızasını gidermez; hatanın uygulamayı beklemede bırakmasını
sınırlar. Sertifika doğrulaması kapatılmadı, HTTP'ye düşülmedi, bilinmeyen
sunucuya kimlik bilgisi gönderilmedi. Worker veya production Firebase ayarı
değiştirilmedi.

Cloudflare hesabındaki salt okunur sorguda bağlı özel alan adı bulunmadı.
Kalıcı alternatif için kullanıcıya ait bir alan adı seçilmeli; Worker'a bağlama,
sertifika, Flutter ve sunucu araçlarındaki belirli alan adı izinleri, canlı
doğrulama ve kontrollü endpoint geçişi birlikte yapılmalıdır. Genel bir alan adı
izni açılmamalıdır. Resmî başvuru:
https://developers.cloudflare.com/workers/configuration/routing/custom-domains/

## Yeni build ile cihaz kontrolü

1. İnterneti kapatıp topluluk kimliğini açın: yükleme sonlanmalı; bağlantı
   geri geldiğinde tekrar deneme kayıtlı kimlik ve güncel onayı getirmeli.
2. Eski politika onayının yeni onay istemesini, güncel onayın yeniden kurulumda
   aynı Firebase UID üzerinden geri yüklenmesini kontrol edin.
3. Apple girişini tamamlayın ve iptal edin; uzun beklemede ikinci girişin
   başlamadığını, işlemin sonucu geldiğinde düğmelerin açıldığını kontrol edin.
4. Hesap değiştirin; önceki kullanıcının profil/yorum/oy bilgisi görünmemeli.
5. Worker erişimi yokken kaydedilen yorumun pending kalmasını; bağlantı ve
   moderasyon düzeldiğinde yayınlanmasını kontrol edin. TLS sorununu bu
   senaryonun başarılı olmasıyla çözülmüş saymayın.
6. Kütüphane, yedek geri yükleme, Premium ve satın alma geri yükleme akışlarını
   yeni build üzerinde kontrol edin; mevcut testler regresyon kanıtıdır,
   hatasızlık garantisi değildir.
