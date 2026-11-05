import Flutter
import GoogleSignIn
import UIKit

class SceneDelegate: FlutterSceneDelegate {}

/// google_sign_in_ios 5.9 receives AppDelegate URL callbacks. Register its
/// existing SDK with Flutter's scene dispatcher as well, so Google redirects
/// complete under the UIScene lifecycle without consuming other app links.
final class WatchloomGoogleScenePlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  static func register(with registrar: FlutterPluginRegistrar) {
    let bridge = WatchloomGoogleScenePlugin()
    registrar.publish(bridge)
    registrar.addSceneDelegate(bridge)
  }

  func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) -> Bool {
    return contexts.reduce(false) { claimed, context in
      GIDSignIn.sharedInstance.handle(context.url) || claimed
    }
  }
}
