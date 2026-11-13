# Topluluk yetkilendirmesi

Kod incelemesinde doğrulanan eksikler: yerel `User.emailVerified` ile Firestore'un
ID token claim'leri farklı zamanlarda güncellenebiliyordu; topluluk bootstrap'inden
önce zorunlu yenileme yoktu. Ayrıca Firebase hataları işlem bağlamını kaybediyordu.
Bunlar düzeltildi. Bildirilen production olayının kesin kök nedeni, ilgili oturumun
teşhis kaydı olmadan kanıtlanmış değildir.

Diğer olasılıklar: eski production kuralları, farklı Firebase UID, eski topluluk
onayı, silinme kilidi veya topluluk yapılandırması. Yorum sınırları da aynı
permission-denied kodunu verebilir. Sabit işlem adı ve SDK hata kodu loglanır;
örnek: `community operation=accountBootstrap code=permission-denied`.
UID, e-posta, token ve yorum metni loglanmaz. `post`/`editComment` atomik
belge+sayaç işlemleridir; Firestore hangi kural koşulunun reddettiğini istemciye
bildirmez. Kuralları gevşetmeden emülatörde ilgili durumu yeniden üretin.

## Kalıcı topluluk onayı

Onay `communityProfiles/{uid}.acceptedPolicyVersion` ve `acceptedPolicyAt`
alanlarında sunucuda tutulur. Uygulamayı yeniden yüklemek bunu silmez. Aynı UID ve
güncel politika ile onay kutusu tekrar gerekmez; politika sürümü değişince açık
onay gerekir. Eksik kullanıcı kökü bootstrap edilir; var olan kök, yedek,
profil, yorum ve oy sıfırlanmaz. Yeni UID eski UID'nin onayını veya yorumlarını
miras almaz.

## Güvenli sağlayıcı bağlama

Apple'ın gizli e-posta adresi ve farklı sağlayıcı hesapları ayrı UID oluşturabilir.
E-posta benzerliği hesap sahipliği kanıtı değildir. Mevcut hesabın içinden
Hesap ekranındaki Apple/Google bağlama akışını kullanın (`linkWithProvider` /
`linkWithCredential`). Böylece Firebase UID korunur. Hesap sahibi önce asıl
hesabında oturum açmalı; gerekli durumlarda yeniden kimlik doğrulamalıdır.
`credential-already-in-use` durumunda otomatik birleştirme, Auth hesabı silme veya
veri taşıma yapmayın. İki hesabı da kullanıcının doğruladığı ayrı bir kurtarma
süreci gerekir. Bu değişiklik hesap birleştirme veya veri taşıma yapmaz.

## Dağıtım ve cihaz kontrolü

1. `bash scripts/deploy_firebase.sh --check`: yalnız demo emülatörleri.
2. Firebase hedef projesini kontrol edip `bash scripts/deploy_firebase.sh --deploy`
   komutunu elle çalıştırın. Bu mevcut kuralları ve indeksleri dağıtır.
3. Güncel Flutter iOS sürümünü cihazda/TestFlight'ta yükleyin. Worker değişmedi;
   Worker dağıtımı gerekmez.
4. Apple, Google, doğrulanmış/doğrulanmamış e-posta oturumlarını gerçek cihazda
   deneyin. Yorum/yanıt oluşturma, düzenlemede tekrar pending olma, başkasının
   yorumuna müdahalenin reddi ve kendi yorumunu silmeyi kontrol edin.
5. Onay verip uygulamayı silin, yeniden kurun ve aynı Firebase hesabına girin:
   güncel onay geri gelmeli. Sağlayıcı değiştiriliyorsa UID'nin aynı olduğunu
   Firebase Console'da özel olarak kontrol edin; bunu kullanıcı loglarına eklemeyin.

Emülatör sağlayıcı testleri sentetik claim kullanır; gerçek Apple/Google OAuth
alışverişini test etmez. Üretim kuralları ve kullanıcı belgeleri bu çalışma
sırasında okunmadı veya değiştirilmedi.
