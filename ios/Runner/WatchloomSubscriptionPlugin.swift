import Flutter
import StoreKit
import UIKit

/// StoreKit owns purchase verification and the regional subscription price.
/// No entitlement is stored in UserDefaults.
@MainActor
final class WatchloomSubscriptionPlugin: NSObject,
  @preconcurrency FlutterPlugin, @preconcurrency FlutterStreamHandler {
  static let productID = "com.canturhan.watchloom.premium.monthly"
  private var eventSink: FlutterEventSink?
  private var transactionTask: Task<Void, Never>?
  private var storefrontTask: Task<Void, Never>?
  private var purchasing = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = WatchloomSubscriptionPlugin()
    let methods = FlutterMethodChannel(
      name: "watchloom/subscriptions", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(
      name: "watchloom/subscription_updates", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    events.setStreamHandler(instance)
    instance.observeTransactions()
  }

  deinit {
    transactionTask?.cancel()
    storefrontTask?.cancel()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    Task { @MainActor in
      do {
        switch call.method {
        case "entitlement":
          result(try await entitlement())
        case "product":
          let product = try await monthlyProduct()
          result([
            "id": product.id,
            "displayPrice": product.displayPrice,
            "currencyCode": product.priceFormatStyle.currencyCode,
          ])
        case "purchase":
          guard !purchasing else {
            result(FlutterError(code: "busy", message: nil, details: nil))
            return
          }
          purchasing = true
          defer { purchasing = false }
          let product = try await monthlyProduct()
          switch try await product.purchase() {
          case .success(let verification):
            let transaction = try verified(verification)
            guard transaction.productID == Self.productID else {
              throw SubscriptionError.invalidProduct
            }
            await transaction.finish()
            result("purchased")
          case .pending:
            result("pending")
          case .userCancelled:
            result("cancelled")
          @unknown default:
            throw SubscriptionError.unavailable
          }
        case "restore":
          // Only this explicit user action may request App Store authentication.
          try await AppStore.sync()
          result(try await entitlement())
        case "manage":
          guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            throw SubscriptionError.unavailable
          }
          try await AppStore.showManageSubscriptions(in: scene)
          result(nil)
        case "privacy", "terms":
          let address = call.method == "privacy"
            ? "https://canturhan.github.io/watchloom/privacy.html"
            : "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
          let opened = await UIApplication.shared.open(URL(string: address)!)
          if !opened { throw SubscriptionError.unavailable }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "store_error", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func monthlyProduct() async throws -> Product {
    guard let product = try await Product.products(for: [Self.productID]).first,
      product.type == .autoRenewable,
      let subscription = product.subscription,
      subscription.subscriptionPeriod.unit == .month,
      subscription.subscriptionPeriod.value == 1 else {
      throw SubscriptionError.invalidProduct
    }
    return product
  }

  private func entitlement() async throws -> [String: Any] {
    // currentEntitlements is StoreKit's signed, locally available transaction
    // history. Checking access does not depend on fetching a product price.
    for await verification in Transaction.currentEntitlements {
      let transaction = try verified(verification)
      guard transaction.productID == Self.productID,
        transaction.revocationDate == nil,
        var accessUntil = transaction.expirationDate else { continue }

      var autoRenew: Bool?
      if let groupID = transaction.subscriptionGroupID,
        let statuses = try? await Product.SubscriptionInfo.status(for: groupID) {
        for status in statuses {
          guard let statusTransaction = try? verified(status.transaction),
            statusTransaction.id == transaction.id,
            let renewal = try? verified(status.renewalInfo) else { continue }
          autoRenew = renewal.willAutoRenew
          if status.state == .inGracePeriod,
            let graceEnd = renewal.gracePeriodExpirationDate {
            accessUntil = max(accessUntil, graceEnd)
          }
        }
      }

      guard accessUntil > Date() else { continue }
      var value: [String: Any] = [
        "status": "subscribed",
        "accessUntil": accessUntil.timeIntervalSince1970 * 1000,
      ]
      if let autoRenew { value["willAutoRenew"] = autoRenew }
      return value
    }

    return ["status": "free"]
  }

  private func verified<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
    switch result {
    case .verified(let value): return value
    case .unverified: throw SubscriptionError.unverified
    }
  }

  private func observeTransactions() {
    transactionTask = Task { [weak self] in
      for await verification in Transaction.updates {
        guard let self else { return }
        // Ignore unrelated products without letting an unverified transaction
        // grant access. Revocations trigger the same entitlement refresh.
        if let transaction = try? self.verified(verification),
          transaction.productID == Self.productID {
          await transaction.finish()
        }
        self.eventSink?("changed")
      }
    }
    storefrontTask = Task { [weak self] in
      for await _ in Storefront.updates {
        guard let self else { return }
        self.eventSink?("storefrontChanged")
      }
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private enum SubscriptionError: Error {
    case invalidProduct, unavailable, unverified
  }
}
