import 'package:flutter/widgets.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/features/community/domain/community_models.dart';

class CommunityStrings {
  CommunityStrings.of(BuildContext context)
    : tr = AppStrings.of(context).isTurkish;
  final bool tr;
  String text(String en, String turkish) => tr ? turkish : en;
  String get title => text('Series discussion', 'Dizi yorumları');
  String get subtitle => text(
    'Share a thought. Discover another perspective.',
    'Fikrini paylaş. Başka bir bakış keşfet.',
  );
  String get publicIdentity => text('Community identity', 'Topluluk kimliği');
  String get identityBody => text(
    'Choose exactly how your name appears with comments. Your account email and sign-in name are never filled in here.',
    'Yorumlarda adının nasıl görüneceğini sen seç. Hesap e-postan ve girişteki adın buraya kendiliğinden eklenmez.',
  );
  String get handle => text('Username', 'Kullanıcı adı');
  String get handleHelp => text(
    '3–20 lowercase letters, numbers or _. Start with a letter. It cannot be changed after saving.',
    '3–20 küçük harf, sayı veya _. Harfle başlamalı. Kaydettikten sonra değiştirilemez.',
  );
  String get nickname => text('Nickname', 'Takma ad');
  String get nicknameHelp => text(
    'Optional, 3–24 characters. Avoid your real name or contact information.',
    'İsteğe bağlı, 3–24 karakter. Gerçek adını veya iletişim bilgilerini kullanma.',
  );
  String get displayAs =>
      text('Display my comments as', 'Yorumlarımda görünecek ad');
  String get preview => text('Public preview', 'Herkese açık önizleme');
  String get acceptTerms => text(
    'I accept the community rules and sending my submitted text and chosen public name to Cloudflare and OpenAI for automatic safety checks. Approved comments are public.',
    'Topluluk kurallarını ve gönderdiğim metin ile seçtiğim görünen adın otomatik güvenlik kontrolü için Cloudflare ve OpenAI hizmetlerine iletilmesini kabul ediyorum. Onaylanan yorumlar herkese açıktır.',
  );
  String get guidelines => text('Community guidelines', 'Topluluk kuralları');
  String get save => text('Save public identity', 'Topluluk kimliğini kaydet');
  String get signIn =>
      text('Sign in to participate', 'Katılmak için giriş yap');
  String get verification => text(
    'Verify your account to participate. You can manage verification from your account page.',
    'Katılmak için hesabını doğrula. Hesap sayfandan doğrulamayı yönetebilirsin.',
  );
  String get manageAccount => text('Manage account', 'Hesabımı yönet');
  String get write => text('Write a comment', 'Yorum yaz');
  String get reply => text('Reply', 'Yanıtla');
  String get delete => text('Delete', 'Sil');
  String get cancel => text('Cancel', 'Vazgeç');
  String get report => text('Report', 'Şikâyet et');
  String get block => text('Block author', 'Yazarı engelle');
  String get refresh => text('Refresh', 'Yenile');
  String get retry => text('Try again', 'Tekrar dene');
  String get pendingTitle => text('Your submissions', 'Senin gönderilerin');
  String get pending => text(
    'Automatic checks pending · not public yet',
    'Otomatik kontrol bekliyor · henüz herkese açık değil',
  );
  String get rejected => text(
    'Not published after safety checks',
    'Güvenlik kontrolü sonrasında yayımlanmadı',
  );
  String get sent => text(
    'Comment saved for automatic safety checks.',
    'Yorumun otomatik güvenlik kontrolü için kaydedildi.',
  );
  String get moderation => text(
    'Automatic safety checks run before publication. Do not share personal details. Use report and block for abuse.',
    'Yorumlar yayımlanmadan önce otomatik güvenlik kontrolünden geçer. Kişisel bilgilerini paylaşma. Kötüye kullanım için şikâyet ve engelleme seçeneklerini kullan.',
  );
  String get empty =>
      text('Start a thoughtful discussion', 'İlk düşünceni paylaş');
  String get emptyBody => text(
    'No approved comments yet. Your first thought could start the conversation.',
    'Henüz onaylanmış yorum yok. İlk düşüncen sohbeti başlatabilir.',
  );
  String get paused => text(
    'Community submissions are not available yet. Approved discussions remain readable. Please check again later.',
    'Topluluk gönderimleri henüz açık değil. Onaylanmış yorumları okuyabilirsin. Daha sonra tekrar kontrol et.',
  );
  String get unavailable => text(
    'Discussions could not be loaded. Check your connection and try again.',
    'Yorumlar yüklenemedi. Bağlantını kontrol edip tekrar dene.',
  );
  String get unavailableDevice => text(
    'Community is available in the configured iOS app. Your private library remains available.',
    'Topluluk, bağlantıları yapılandırılmış iOS uygulamasında kullanılabilir. Özel kütüphaneni kullanmaya devam edebilirsin.',
  );
  String get reportSent => text(
    'Report received. The moderation team will review this comment.',
    'Şikâyetin alındı. Moderasyon ekibi bu yorumu inceleyecek.',
  );
  String get blocked => text(
    'Author blocked. Their comments are hidden for you.',
    'Yazar engellendi. Yorumları senin için gizlendi.',
  );
  String get deleted => text('Comment deleted.', 'Yorum silindi.');
  String get deleteConfirm => text(
    'Delete this comment? Replies from other people may remain without your original comment.',
    'Bu yorum silinsin mi? Başkalarının yanıtları, senin yorumun olmadan kalabilir.',
  );
  String get blockConfirm => text(
    'Hide all comments from this author? You can undo this in Community identity.',
    'Bu yazarın tüm yorumları gizlensin mi? Topluluk kimliğinden bu işlemi geri alabilirsin.',
  );
  String get spoiler => text('Contains spoilers', 'Spoiler içeriyor');
  String get revealSpoiler => text(
    'Spoiler hidden · tap to reveal',
    'Spoiler gizlendi · göstermek için dokun',
  );
  String get hideSpoiler => text('Hide spoiler', 'Spoilerı gizle');
  String get commentHint => text(
    'What did you think of this series?',
    'Bu dizi hakkında ne düşünüyorsun?',
  );
  String get submit =>
      text('Send for safety checks', 'Güvenlik kontrolüne gönder');
  String get replyContext =>
      text('Reply to an earlier comment', 'Önceki bir yoruma yanıt');
  String get reportTitle =>
      text('Why are you reporting this?', 'Neden şikâyet ediyorsun?');
  String get support =>
      text('Contact community support', 'Topluluk desteğine ulaş');
  String get more => text('Comment actions', 'Yorum seçenekleri');
  String get recent =>
      text('Latest approved comments', 'Son onaylanan yorumlar');
  String get pageLimit => text(
    'Showing up to 50 approved comments in the selected order. Refresh for updates.',
    'Seçtiğin sıralamada en fazla 50 onaylı yorum gösteriliyor. Güncellemeler için yenileyebilirsin.',
  );
  String get best => text('Best comments', 'En iyi yorumlar');
  String get newest => text('Newest first', 'En yeni önce');
  String get sortComments => text('Comment order', 'Yorum sıralaması');
  String get upVote => text('Upvote', 'Olumlu oy');
  String get downVote => text('Downvote', 'Olumsuz oy');
  String get noSelfVote => text(
    'You cannot vote on your own comment.',
    'Kendi yorumuna oy veremezsin.',
  );
  String get score => text('Score', 'Puan');
  String get processingHelp => text(
    'Saved comments are checked automatically. If the service is busy, checks retry later; you do not need to submit again.',
    'Kaydedilen yorumlar otomatik kontrol edilir. Hizmet yoğunsa kontrol daha sonra yeniden denenir; tekrar göndermene gerek yok.',
  );
  String get renewConsent => text(
    'Review and accept the updated community terms before submitting comments or voting. Your chosen public name stays under your control.',
    'Yorum göndermeden veya oy vermeden önce güncel topluluk koşullarını inceleyip kabul et. Görünen adını seçme hakkın sende kalır.',
  );
  String voteFailure(Object error) =>
      error is CommunityException &&
          error.failure == CommunityFailure.permissionDenied
      ? text(
          'Your vote could not be recorded. Wait a moment, refresh, or review your community consent.',
          'Oyun kaydedilemedi. Biraz bekle, yenile veya topluluk iznini kontrol et.',
        )
      : failure(error);
  String get blockedAccounts => text('Blocked accounts', 'Engellenen hesaplar');
  String get noBlocks =>
      text('You have not blocked anyone.', 'Henüz kimseyi engellemedin.');
  String get unblock => text('Unblock', 'Engeli kaldır');
  String get blockedPrivacy => text(
    'Only an anonymous account reference is retained for blocks. Public profile details are not copied here.',
    'Engeller için yalnızca rastgele hesap referansı tutulur. Herkese açık profil bilgileri buraya kopyalanmaz.',
  );
  String reason(CommunityReportReason value) => switch (value) {
    CommunityReportReason.abuse => text(
      'Harassment or threats',
      'Taciz veya tehdit',
    ),
    CommunityReportReason.hate => text(
      'Hate or discrimination',
      'Nefret veya ayrımcılık',
    ),
    CommunityReportReason.sexual => text(
      'Sexual or unsafe content',
      'Cinsel veya zararlı içerik',
    ),
    CommunityReportReason.spam => text(
      'Spam or advertising',
      'Spam veya reklam',
    ),
    CommunityReportReason.spoiler => text(
      'Unmarked spoiler',
      'İşaretlenmemiş spoiler',
    ),
    CommunityReportReason.other => text(
      'Other guideline violation',
      'Başka bir kural ihlali',
    ),
  };

  String failure(Object error) {
    if (error is! CommunityException) return unavailable;
    return switch (error.failure) {
      CommunityFailure.verificationRequired => verification,
      CommunityFailure.identityRequired => text(
        'Choose a public identity before participating.',
        'Katılmadan önce topluluk kimliğini seç.',
      ),
      CommunityFailure.termsRequired => text(
        'Please review and accept the current community guidelines in Community identity.',
        'Topluluk kimliğinden güncel topluluk kurallarını inceleyip kabul et.',
      ),
      CommunityFailure.invalidIdentity => text(
        'Check your username and nickname. A nickname is required when it is selected for display.',
        'Kullanıcı adını ve takma adını kontrol et. Görünen ad olarak takma adı seçtiğinde doldurman gerekir.',
      ),
      CommunityFailure.handleUnavailable => text(
        'This username is already in use. Choose another.',
        'Bu kullanıcı adı kullanılıyor. Başka bir ad seç.',
      ),
      CommunityFailure.prohibitedText => text(
        'Please revise this text. Prohibited language, private contact details or unsupported control characters are not allowed.',
        'Lütfen metni düzenle. Yasak dil, özel iletişim bilgileri veya desteklenmeyen kontrol karakterleri kullanılamaz.',
      ),
      CommunityFailure.rateLimited => text(
        'You are sending too quickly or reached the daily limit. Please try again later.',
        'Çok hızlı gönderiyorsun veya günlük sınıra ulaştın. Daha sonra tekrar dene.',
      ),
      CommunityFailure.invalidContent => text(
        'This discussion is no longer available. Refresh and try again.',
        'Bu yorum artık kullanılamıyor. Yenileyip tekrar dene.',
      ),
      CommunityFailure.permissionDenied => text(
        'This action could not be authorized. Check account verification or contact support.',
        'Bu işlem yetkilendirilemedi. Hesap doğrulamanı kontrol et veya desteğe yaz.',
      ),
      _ => unavailable,
    };
  }
}
