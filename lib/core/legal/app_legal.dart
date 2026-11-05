/// Public legal and support destinations, shared by every settings entry point.
abstract final class AppLegal {
  static const controllerName = 'Yunus Can Turhan';
  static const supportEmail = 'can.turhan.web@gmail.com';
  static const privacy = 'https://canturhan.github.io/watchloom/privacy.html';
  static const terms = 'https://canturhan.github.io/watchloom/terms.html';
  static const support = 'https://canturhan.github.io/watchloom/support.html';
  static const supportIssues =
      'https://github.com/CanTurhan/watchloom/issues/new';
  static const appleEula =
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
  static const appleRefund = 'https://reportaproblem.apple.com/';
  static const yandexPrivacy = 'https://yandex.com/legal/confidential/';
  static const firebasePrivacy = 'https://firebase.google.com/support/privacy';
  static const googlePrivacy = 'https://policies.google.com/privacy';
  static const tvmaze = 'https://www.tvmaze.com';
  static const tvmazeLicense =
      'https://creativecommons.org/licenses/by-sa/4.0/';
  static const tvmazeApi = 'https://www.tvmaze.com/api#licensing';
  static String get contact =>
      supportEmail.isEmpty ? supportIssues : 'mailto:$supportEmail';
}
