import 'package:watchloom/core/localization/app_strings.dart';

extension AppAccountStrings on AppStrings {
  String get linkIdentityConsent => value(
    en: 'This links the selected identity to this same Watchloom account. Anyone who signs in with either linked method can access this account library and backup. If you used Hide My Email with Apple, linking Google can associate your name and Google email with that Apple identity. Continue only if you want this association.',
    tr: 'Seçtiğin kimlik bu Watchloom hesabına bağlanır. Bağlı yöntemlerden biriyle giriş yapan kişi bu hesabın kütüphanesine ve yedeğine erişir. Apple ile E-postamı Gizle kullandıysan Google hesabını bağlamak, adını ve Google e-postanı o Apple kimliğiyle ilişkilendirebilir. Yalnızca bu ilişkilendirmeyi istiyorsan devam et.',
  );
  String get deletionPendingTitle =>
      value(en: 'Finish account deletion', tr: 'Hesap silmeyi tamamla');
  String get deletionPendingBody => value(
    en: 'Deletion was started for this account. Backup and library access are locked to prevent another device from restoring deleted data. Connect to the internet and choose Delete permanently to finish. If the connection or cloud service limit interrupts deletion, retry here; the account is not reported as deleted until it completes.',
    tr: 'Bu hesap için silme başlatılmış. Başka bir cihazın silinen verileri geri yüklememesi için yedekleme ve kütüphane erişimi kilitli. İnternete bağlanıp Kalıcı olarak sil ile tamamlayabilirsin. Bağlantı veya bulut hizmeti sınırı işlemi keserse buradan tekrar dene; işlem tamamlanana kadar hesap silinmiş sayılmaz.',
  );
  String get accountTitle =>
      value(en: 'Account & backup', tr: 'Hesap ve yedekleme');
  String get signInTitle =>
      value(en: 'Your shows. Everywhere.', tr: 'Dizilerin. Her yerde.');
  String get signInBody => value(
    en: 'Save your library, notes and episode history to your Watchloom account.',
    tr: 'Kütüphaneni, notlarını ve bölüm geçmişini Watchloom hesabında yedekle.',
  );
  String get signIn => value(en: 'Sign in', tr: 'Giriş yap');
  String get createAccount => value(en: 'Create account', tr: 'Hesap oluştur');
  String get guestContinue =>
      value(en: 'Continue as guest', tr: 'Misafir olarak devam et');
  String get guestLabel =>
      value(en: 'Guest library', tr: 'Misafir kütüphanesi');
  String get guestBody => value(
    en: 'Stored on this device. Sign in to back up and restore your library.',
    tr: 'Bu cihazda saklanır. Kütüphaneni yedeklemek ve geri getirmek için giriş yap.',
  );
  String get googleSignIn =>
      value(en: 'Continue with Google', tr: 'Google ile devam et');
  String get appleSignIn =>
      value(en: 'Continue with Apple', tr: 'Apple ile devam et');
  String get emailLabel => value(en: 'Email address', tr: 'E-posta adresi');
  String get passwordLabel => value(en: 'Password', tr: 'Parola');
  String get emailInvalid => value(
    en: 'Enter a valid email address.',
    tr: 'Geçerli bir e-posta adresi yaz.',
  );
  String get passwordInvalid =>
      value(en: 'Use at least 8 characters.', tr: 'En az 8 karakter kullan.');
  String get passwordRequired =>
      value(en: 'Enter your password.', tr: 'Parolanı yaz.');
  String get forgotPassword =>
      value(en: 'Forgot password?', tr: 'Parolamı unuttum');
  String get resetSent => value(
    en: 'If an account exists for this address, a password reset email has been sent. Check your inbox and spam folder.',
    tr: 'Bu adresle bir hesap varsa parola sıfırlama e-postası gönderildi. Gelen kutunu ve spam klasörünü kontrol et.',
  );
  String get emailVerify => value(
    en: 'Verify your email to enable cloud backup.',
    tr: 'Bulut yedeklemeyi açmak için e-posta adresini doğrula.',
  );
  String get resendEmail =>
      value(en: 'Send verification email', tr: 'Doğrulama e-postası gönder');
  String get verifyCheck =>
      value(en: 'I have verified my email', tr: 'E-postamı doğruladım');
  String get mailSent => value(
    en: 'Verification email sent. Check your inbox and spam folder.',
    tr: 'Doğrulama e-postası gönderildi. Gelen kutunu ve spam klasörünü kontrol et.',
  );
  String get authUnavailable => value(
    en: 'Account sign-in is temporarily unavailable. You can continue using your guest library.',
    tr: 'Hesapla giriş şu anda kullanılamıyor. Misafir kütüphaneni kullanmaya devam edebilirsin.',
  );
  String get authConsent => value(
    en: 'Signing in enables cloud backup of your library, notes and viewing history. Review our Privacy Policy and Terms of Use before continuing.',
    tr: 'Giriş yaptığında kütüphanen, notların ve izleme geçmişin bulutta yedeklenir. Devam etmeden önce Gizlilik Politikası ve Kullanım Koşullarını inceleyebilirsin.',
  );
  String get premiumAccountNote => value(
    en: 'Premium is managed by Apple. Restore purchases with the Apple Account used for the subscription; your Watchloom login does not transfer a subscription between Apple Accounts.',
    tr: 'Premium Apple tarafından yönetilir. Satın alımları abonelikte kullandığın Apple Hesabı ile geri yükle; Watchloom girişi aboneliği Apple Hesapları arasında taşımaz.',
  );
  String get backupNow => value(en: 'Back up now', tr: 'Şimdi yedekle');
  String get backupDisclosure => value(
    en: 'Changes are backed up automatically when online. Sign in to the same Watchloom account to restore them after reinstalling. If devices have conflicting changes, choose which copy to keep.',
    tr: 'Değişiklikler çevrimiçiyken otomatik yedeklenir. Yeniden yüklemeden sonra aynı Watchloom hesabıyla giriş yaparak geri getirebilirsin. Cihazlarda çakışan değişiklikler varsa korunacak kopyayı sen seçersin.',
  );
  String get backupConflict => value(
    en: 'Changes on another device need your choice.',
    tr: 'Başka cihazdaki değişiklikler için seçim yapman gerekiyor.',
  );
  String get useCloud =>
      value(en: 'Use cloud copy', tr: 'Buluttaki kopyayı kullan');
  String get useDevice =>
      value(en: 'Use this device', tr: 'Bu cihazdaki kopyayı kullan');
  String get conflictConfirm => value(
    en: 'This replaces the other copy of your library, notes and history. Review your choice before continuing.',
    tr: 'Bu işlem kütüphanenin, notlarının ve geçmişinin diğer kopyasını değiştirir. Devam etmeden önce seçimini kontrol et.',
  );
  String get importGuestTitle => value(
    en: 'Copy guest library to account',
    tr: 'Misafir kütüphanesini hesaba kopyala',
  );
  String get importGuestBody => value(
    en: 'Available when your account library is empty and cloud backup is up to date. Your original guest records stay on this device. No records are uploaded without your choice.',
    tr: 'Hesap kütüphanen boşken ve bulut yedeğin güncelken kullanılabilir. Mevcut misafir kayıtların bu cihazda korunur. Seçimin olmadan misafir kayıtların yüklenmez.',
  );
  String get importFailed => value(
    en: 'Copy could not be completed. Check that the account library is empty and backup is up to date.',
    tr: 'Kopyalama tamamlanamadı. Hesap kütüphanesinin boş ve yedeğinin güncel olduğunu kontrol et.',
  );
  String get signOut => value(en: 'Sign out', tr: 'Çıkış yap');
  String get signOutBody => value(
    en: 'Your guest library will open. Your account library will only be visible when you sign in to this account again.',
    tr: 'Misafir kütüphanen açılacak. Hesap kütüphanen yalnızca bu hesaba yeniden giriş yaptığında görünür.',
  );
  String get unsavedSignOut => value(
    en: 'Some changes are not backed up yet. They will stay on this device, but cannot be restored after deleting the app until a backup succeeds.',
    tr: 'Bazı değişiklikler henüz yedeklenmedi. Bu cihazda kalırlar; yedekleme başarılı olmadan uygulamayı silersen geri getirilemezler.',
  );
  String get deleteAccount => value(en: 'Delete account', tr: 'Hesabımı sil');
  String get deleteAccountBody => value(
    en: 'Permanently delete your Watchloom account, cloud backups, community profile, your comments and replies, your reports and block preferences, and this account’s data on this device. Replies written by others can remain without your original comment. Your separate guest library is kept. You will be asked to authenticate again and need an internet connection. This does not cancel your Apple subscription; manage it separately in Apple subscription settings.',
    tr: 'Watchloom hesabın, bulut yedeklerin, topluluk profilin, kendi yorum ve yanıtların, şikâyet ve engelleme tercihlerin ve bu hesaba ait bu cihazdaki veriler kalıcı olarak silinir. Başkalarının yanıtları, senin yorumun olmadan kalabilir. Ayrı misafir kütüphanen korunur. Kimliğini yeniden doğrulaman ve internet bağlantısı gerekir. Bu işlem Apple aboneliğini iptal etmez; aboneliğini Apple abonelik ayarlarından ayrıca yönet.',
  );
  String get deleteAccountConfirm =>
      value(en: 'Delete permanently', tr: 'Kalıcı olarak sil');
  String get deleteFailed => value(
    en: 'Account deletion could not be completed. Sign in again and retry with an internet connection.',
    tr: 'Hesap silme tamamlanamadı. İnternet bağlantısıyla yeniden giriş yapıp tekrar dene.',
  );
  String authError(String? code) => switch (code) {
    'email-already-in-use' => value(
      en: 'This email already has an account. Sign in or reset your password.',
      tr: 'Bu e-posta ile bir hesap var. Giriş yap veya parolanı sıfırla.',
    ),
    'invalid-credential' || 'wrong-password' || 'user-not-found' => value(
      en: 'Email or password is incorrect.',
      tr: 'E-posta veya parola hatalı.',
    ),
    'invalid-email' => emailInvalid,
    'weak-password' => passwordInvalid,
    'too-many-requests' => value(
      en: 'Too many attempts. Please wait and try again.',
      tr: 'Çok fazla deneme yapıldı. Biraz bekleyip tekrar dene.',
    ),
    'account-exists-with-different-credential' ||
    'credential-already-in-use' => value(
      en: 'Use your original sign-in method for this account. You can link another provider in account settings after signing in.',
      tr: 'Bu hesap için ilk kullandığın giriş yöntemini kullan. Giriş yaptıktan sonra hesap ayarlarında diğer sağlayıcıyı bağlayabilirsin.',
    ),
    'user-disabled' => value(
      en: 'This account is disabled. Contact support.',
      tr: 'Bu hesap devre dışı. Destek ile iletişime geç.',
    ),
    'canceled' || 'web-context-cancelled' => value(
      en: 'Sign-in cancelled.',
      tr: 'Giriş iptal edildi.',
    ),
    _ => value(
      en: 'Could not complete the request. Check your connection and try again.',
      tr: 'İşlem tamamlanamadı. Bağlantını kontrol edip tekrar dene.',
    ),
  };
}
