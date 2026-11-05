# Watchloom — Apple ile giriş kurulumu

Kod ve native entitlement hazır. Hesap sahibi Watchloom App ID için Apple
Developer’da Sign in with Apple özelliğini etkinleştirdiğini bildirdi. Runner’ın
Debug/Profile/Release yapılandırmalarında yetki dosyası ve automatic signing
tanımlı ve Xcode build settings üzerinden doğrulandı. Hesap sahibi
`com.canturhan.watchloom.auth` Service ID’sini Watchloom primary App ID’sine
bağlayıp belirtilen Firebase domain/dönüş adresini kaydettiğini bildirdi.
Hesap sahibi Sign in with Apple anahtarını oluşturdu; yerel dosyanın P-256 biçimi
doğrulandı ve depo içindeki kopya Git dışında, kullanıcıya özel izinli klasöre
taşındı. Hesap sahibinin normal Terminal’inde Firebase Apple sağlayıcısı
yapılandırıldı ve sunucudan tekrar okundu: enabled, Service ID, takım,
Key ID varlığı ve bundle eşleşmesi başarılı. Özel anahtar uygulamaya/depo
içine kopyalanmadı. Bu sonuç gerçek Apple girişini veya token revocation’ı
henüz kanıtlamaz. Hesap sahibi Firebase gönderici e-posta kaydını ve SPF işlemini
tamamladığını bildirdi; gerçek teslim testi bekliyor. İmzalı profil ve cihaz
testleri TestFlight QA üzerinden tamamlanacak.
Firebase Spark ve Firestore dağıtımı tamamlandı. Bu işlemler ücretli Firebase
planı, Cloud Functions veya Identity Platform yükseltmesi gerektiren bir adım
içermez. Apple portalında aşağıdaki kayıtları hesap sahibi oluşturur; Firebase
bağlantısı mevcut CLI oturumuyla hazırlanmış araç üzerinden yapılabilir.

## 1. Watchloom App ID

[Apple Developer → Identifiers](https://developer.apple.com/account/resources/identifiers/list)
içinde `com.canturhan.watchloom` kaydını aç.
Kayıt yoksa **+ → App IDs → App** ile `Watchloom` adında, Explicit Bundle ID
değeri `com.canturhan.watchloom` olan iOS uygulama kimliğini oluştur.

- Team ID: `GC8Z24R23C`.
- **Sign in with Apple** özelliğini aç.
- Yapılandırma istenirse Watchloom’u kendi **primary App ID** kaydı olarak seç.
- Kaydet. Sonraki imzalı build’de Xcode automatic signing profilini yenilemeli.

Uygulamada `Runner.entitlements`, üç Xcode yapılandırması ve Apple capability
tanımı mevcut. Portal kaydı/profil ve gerçek imzalı paket ayrıca doğrulanır.

## 2. Service ID ve yönlendirme

Identifiers → **+** → **Services IDs** üzerinden oluştur:

| Alan | Değer |
| --- | --- |
| Description | `Watchloom Firebase Authentication` |
| Identifier | `com.canturhan.watchloom.auth` |

Oluşturduğun Service ID’yi aç → **Sign in with Apple → Configure**:

| Alan | Değer |
| --- | --- |
| Primary App ID | Watchloom — `com.canturhan.watchloom` |
| Domains and Subdomains | `watchloom-canturhan.firebaseapp.com` |
| Return URLs | `https://watchloom-canturhan.firebaseapp.com/__/auth/handler` |

Done → Continue → Save ile kaydet. Alanlara boşluk/ek yol ekleme. Bu yönlendirme
Firebase Authentication’ın mevcut handler’ıdır; ayrı web hosting yayını gerekmez.
Service ID’nin adı farklı seçildiyse araçta gerçek kayıtlı değeri kullan.

## 3. Sign in with Apple anahtarı

[Apple Developer → Keys](https://developer.apple.com/account/resources/authkeys/list)
→ **+**:

1. Key Name: `Watchloom Sign in with Apple`.
2. **Sign in with Apple** seç → Configure → Watchloom primary App ID’yi seç.
3. Continue → Register ile oluştur.
4. **Key ID** değerini not al; `.p8` dosyasını indir.

Apple anahtar dosyasını yeniden indirmeye izin vermez; güvenli yedeğini sakla.
Dosya Mac’te, Watchloom/Git deposunun dışında kalmalı. İçeriğini sohbet veya
uygulama kaynaklarına yapıştırma. Kurulum aracı yerel dosyayı okur, erişimini
`0600` yapar ve yalnızca Google’ın Apple sağlayıcısı yapılandırma endpoint’ine
gönderir. İstek/yanıt gövdeleri ve anahtar hata günlüklerine yazılmaz.

## 4. Firebase bağlantısı

Mevcut Firebase CLI oturumunla normal Terminal’de:

```bash
cd /Users/canturhan/CodingSpace/watchloom
node scripts/configure_firebase_apple.cjs --configure
```

Sorulduğunda kayıtlı Service ID’yi, Apple Key ID’yi ve indirdiğin `.p8` dosyasının
tam yerel yolunu gir. Anahtar metni istenmez. Araç önce projeyi ve Spark planını
doğrular; yalnızca `watchloom-canturhan` projesindeki `apple.com` sağlayıcısını
oluşturur/günceller. Farklı mevcut Service ID görürse durur. Google/e-posta
sağlayıcılarını değiştirmez. Team ID ve bundle ID Watchloom ile eşleştirilir.

Başarılı yazma sonrası servis/ekip/anahtar kimliği/bundle değerleri tekrar okunur.
Bu doğrulama, Apple’ın anahtarı kabul ettiğini veya cihaz girişini henüz kanıtlamaz.
Özel anahtar uygulama paketine veya GitHub’a kopyalanmaz.

Salt okunur yeniden kontrol:

```bash
node scripts/configure_firebase_apple.cjs --check
```

Manuel Firebase alternatifi: Authentication → Sign-in method → Apple → Enable.
Service ID, OAuth code flow Team ID `GC8Z24R23C`, Key ID ve Apple özel anahtarını
Firebase konsoluna gir. İki yöntemin de sonrasında gerçek cihaz testi gerekir.

## 5. Hide My Email ve e-posta iletimi

Apple Developer → **Services → Sign in with Apple for Email Communication**
→ Configure → Email Sources → **+**. Firebase varsayılan göndericisi kullanılırken:

`noreply@watchloom-canturhan.firebaseapp.com`

adresini kaydet ve doğrulama sonucunu kontrol et. Firebase e-posta şablonlarında
özel gönderici kullanılırsa gerçek gönderici/domain ayrıca kaydedilip SPF/DKIM
uyumu doğrulanır. Hide My Email adresine gerçek e-posta teslimini test et.

## 6. Cihaz ve yayın koşulları

- Apple ile ilk giriş, tekrar giriş, vazgeçme ve **Hide My Email**.
- Aynı Apple kimliğiyle yeni kurulumda tamamlanmış yedeği geri getirme.
- Kullanıcı onayıyla Google/Apple kimliği bağlama; farklı hesapların verileri
  birbirine geçmemeli. Apple gizli e-posta kimliğini ilişkilendirme onayı korunur.
- Hesap silerken taze Apple doğrulaması, Apple token revocation, Firestore
  sürüm/chunk’larının ve Firebase Auth kaydının silinmesi; kesintiden toparlanma.
- İmzalı paket entitlement’ında `com.apple.developer.applesignin = [Default]` ve
  doğru takım/bundle; Xcode profilinin Apple capability desteği.
- Google ve e-posta akışları, guest kopyalama, iki cihaz çakışması, çevrimdışı
  değişiklikler ve aynı Apple Account üzerinden StoreKit Premium geri yükleme.

Güncel imzasız entegrasyon arşivi derlendi; bu testler ve imzalı dağıtım henüz
tamamlanmış sayılmaz. Üretim/QA reklam ayrımı ve yeni build numarası için
[yayın rehberini](WATCHLOOM_PREMIUM_RELEASE.md) izle.

Kaynaklar: [Firebase Apple kurulumu](https://firebase.google.com/docs/auth/ios/apple),
[Apple Service ID/web yönlendirmesi](https://developer.apple.com/help/account/capabilities/configure-sign-in-with-apple-for-the-web/),
[Apple anahtar yönetimi](https://developer.apple.com/help/account/keys/create-a-private-key/),
[Apple e-posta relay](https://developer.apple.com/help/account/capabilities/configure-private-email-relay-service/),
[Google Apple sağlayıcı API’si](https://cloud.google.com/identity-platform/docs/reference/rest/v2/projects.defaultSupportedIdpConfigs).
