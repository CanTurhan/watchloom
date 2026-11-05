import Flutter
import YandexMobileAds
import AppMetricaCore

/// Called only after the user permits limited ads and before SDK initialization.
/// This app does not opt users into AppMetrica app/ad analytics reporting.
@MainActor
final class WatchloomAdvertisingPrivacyPlugin: NSObject, @preconcurrency FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "watchloom/advertising_privacy", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(WatchloomAdvertisingPrivacyPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "configure" || call.method == "withdraw" else {
      result(FlutterMethodNotImplemented)
      return
    }
    // The Ads SDK depends on AdSupport. Disable IDFA explicitly even if an
    // older app version was granted ATT permission. Keep vendor manifests intact.
    AppMetrica.isAdvertisingIdentifierTrackingEnabled = false
    AppMetrica.isLocationTrackingEnabled = false
    YandexAds.setAppAdAnalyticsReportingEnabled(false)
    if call.method == "withdraw" {
      // Public SDK API: applies to reporters initialized with other API keys too.
      AppMetrica.setDataSendingEnabled(false)
      YandexAds.setUserConsent(false)
      YandexAds.setLocationTracking(false)
    }
    result(nil)
  }
}
