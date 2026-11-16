import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchloom/features/account/data/firestore_account_store.dart';
import 'package:watchloom/firebase_options.dart';

class AuthController extends ChangeNotifier with WidgetsBindingObserver {
  factory AuthController.guestOnly() => AuthController._(null, null);
  AuthController._(
    this.auth,
    this._google, {
    this.slowOperationAfter = const Duration(seconds: 45),
  });

  @visibleForTesting
  factory AuthController.withAuth(
    FirebaseAuth auth, {
    Duration slowOperationAfter = const Duration(seconds: 45),
  }) => AuthController._(auth, null, slowOperationAfter: slowOperationAfter);

  final Duration slowOperationAfter;
  static const _sessionTimeout = Duration(seconds: 15);
  Timer? _operationTimer;
  bool operationSlow = false;
  bool _disposed = false;
  bool _refreshingSession = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  final FirebaseAuth? auth;
  final GoogleSignIn? _google;
  StreamSubscription<User?>? _subscription;
  bool busy = false;
  String? errorCode;
  bool verificationSent = false;
  String? lastDeletedUserId;
  DeletionRecoveryStore? _deletionRecovery;
  String? _tokenOwner;
  String? _signInProvider;
  int _tokenGeneration = 0;
  bool get available => auth != null;
  User? get user => auth?.currentUser;
  bool get canBackup =>
      user != null &&
      (user!.emailVerified ||
          (_tokenOwner == user!.uid &&
              ['apple.com', 'google.com'].contains(_signInProvider)));

  static Future<AuthController> create() async {
    final options = WatchloomFirebaseOptions.ios;
    if (options == null || defaultTargetPlatform != TargetPlatform.iOS) {
      return AuthController._(null, null);
    }
    try {
      final app = await Firebase.initializeApp(options: options);
      final auth = FirebaseAuth.instanceFor(app: app);
      final firestore = FirebaseFirestore.instanceFor(app: app);
      firestore.settings = const Settings(persistenceEnabled: false);
      final controller = AuthController._(
        auth,
        GoogleSignIn(clientId: options.iosClientId),
      );
      controller._deletionRecovery = DeletionRecoveryStore(
        firestore,
        await SharedPreferences.getInstance(),
      );
      unawaited(controller._deletionRecovery!.retry());
      WidgetsBinding.instance.addObserver(controller);
      controller._subscription = auth.userChanges().listen((_) {
        unawaited(controller._refreshTokenIdentity());
      });
      return controller;
    } catch (_) {
      final controller = AuthController._(null, null);
      controller.errorCode = 'configuration';
      return controller;
    }
  }

  Future<void> _refreshTokenIdentity() async {
    final generation = ++_tokenGeneration;
    final current = user;
    if (_tokenOwner != current?.uid) {
      _tokenOwner = null;
      _signInProvider = null;
    }
    try {
      final token = await current?.getIdTokenResult().timeout(_sessionTimeout);
      if (generation != _tokenGeneration || user?.uid != current?.uid) return;
      _tokenOwner = current?.uid;
      _signInProvider = token?.signInProvider;
    } catch (_) {
      /* Verified email still works offline; no local entitlement. */
    }
    if (generation == _tokenGeneration) _notify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && user != null && !busy) {
      unawaited(_refreshSession());
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_deletionRecovery?.retry() ?? Future.value());
    }
  }

  Future<void> _refreshSession() async {
    if (_refreshingSession || _disposed) return;
    _refreshingSession = true;
    final previous = user;
    try {
      await previous?.reload().timeout(_sessionTimeout);
      if (user?.uid == previous?.uid) {
        await user?.getIdToken(true).timeout(_sessionTimeout);
        await _refreshTokenIdentity();
      }
    } on FirebaseAuthException catch (error) {
      if (_disposed || user?.uid != previous?.uid) return;
      if (error.code == 'user-not-found') lastDeletedUserId = previous?.uid;
      if ([
        'user-not-found',
        'user-disabled',
        'invalid-user-token',
        'user-token-expired',
      ].contains(error.code)) {
        await auth?.signOut();
      }
      // Network failures preserve the existing offline session.
    } catch (_) {
      /* Keep the offline session. */
    } finally {
      _refreshingSession = false;
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (_disposed || busy || !available) return false;
    busy = true;
    operationSlow = false;
    errorCode = null;
    // A native provider sheet/Firebase write cannot be cancelled by timing out
    // its Dart Future. Keep the operation lock until the real result arrives.
    _operationTimer = Timer(slowOperationAfter, () {
      if (_disposed || !busy) return;
      operationSlow = true;
      errorCode = 'operation-pending';
      debugPrint('auth operation=pending code=slow-operation');
      _notify();
    });
    _notify();
    try {
      await action();
      if (errorCode == 'operation-pending') errorCode = null;
      return true;
    } on FirebaseAuthException catch (error) {
      errorCode = error.code;
    } on PlatformException catch (error) {
      errorCode = ['sign_in_canceled', 'canceled'].contains(error.code)
          ? null
          : 'provider-error';
    } catch (_) {
      errorCode = 'network-request-failed';
    } finally {
      _operationTimer?.cancel();
      _operationTimer = null;
      busy = false;
      operationSlow = false;
      _notify();
    }
    return false;
  }

  Future<bool> email({
    required String email,
    required String password,
    required bool create,
    required String language,
  }) => _run(() async {
    await auth!.setLanguageCode(language);
    if (create) {
      final result = await auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      try {
        await result.user!.sendEmailVerification();
        verificationSent = true;
      } on FirebaseAuthException {
        // Account exists even when mail delivery fails; resend is available.
        verificationSent = false;
      }
    } else {
      await auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    }
  });

  Future<AuthCredential?> _googleCredential() async {
    final account = await _google!.signIn();
    if (account == null) return null;
    final tokens = await account.authentication;
    return GoogleAuthProvider.credential(
      accessToken: tokens.accessToken,
      idToken: tokens.idToken,
    );
  }

  Future<bool> google({bool link = false}) => _run(() async {
    final owner = user;
    final credential = await _googleCredential();
    if (credential == null) return;
    if (link) {
      if (owner == null || user?.uid != owner.uid) {
        throw FirebaseAuthException(code: 'user-mismatch');
      }
      await owner.linkWithCredential(credential);
    } else {
      await auth!.signInWithCredential(credential);
    }
  });

  Future<bool> apple({bool link = false}) => _run(() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    if (link) {
      await user!.linkWithProvider(provider);
    } else {
      await auth!.signInWithProvider(provider);
    }
  });

  Future<bool> resetPassword(String email, String language) => _run(() async {
    await auth!.setLanguageCode(language);
    try {
      await auth!.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      // Identical UI for an unknown address, preventing email enumeration.
      if (error.code != 'user-not-found') rethrow;
    }
  });

  Future<bool> resendVerification(String language) => _run(() async {
    await auth!.setLanguageCode(language);
    await user!.sendEmailVerification();
    verificationSent = true;
  });

  Future<bool> refreshUser() => _run(() async {
    final owner = user;
    if (owner == null) throw FirebaseAuthException(code: 'user-mismatch');
    await owner.reload().timeout(_sessionTimeout);
    if (user?.uid != owner.uid) {
      throw FirebaseAuthException(code: 'user-mismatch');
    }
    await user!.getIdToken(true).timeout(_sessionTimeout);
    if (user?.uid != owner.uid) {
      throw FirebaseAuthException(code: 'user-mismatch');
    }
    await _refreshTokenIdentity();
  });

  Future<bool> signOut() => _run(() async {
    await auth!.signOut();
    try {
      await _google?.signOut();
    } catch (_) {
      /* Firebase is signed out. */
    }
  });

  Future<void> localDeletionCacheCleared(String uid) async {
    await _deletionRecovery?.cacheCleared(uid);
    unawaited(_deletionRecovery?.retry() ?? Future.value());
  }

  /// Fresh provider authentication is mandatory for destructive deletion.
  /// Apple authorization is revoked before removing the Firebase identity.
  Future<bool> deleteAccount({String? password}) => _run(() async {
    final current = user!;
    final providers = current.providerData.map((p) => p.providerId).toSet();
    if (providers.contains('apple.com')) {
      final result = await current.reauthenticateWithProvider(
        AppleAuthProvider(),
      );
      final code = result.additionalUserInfo?.authorizationCode;
      if (code == null || code.isEmpty) throw StateError('missing-apple-code');
      await auth!.revokeTokenWithAuthorizationCode(code);
    } else if (providers.contains('google.com')) {
      final credential = await _googleCredential();
      if (credential == null) throw StateError('cancelled');
      await current.reauthenticateWithCredential(credential);
    } else {
      await current.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: current.email!,
          password: password ?? '',
        ),
      );
    }
    final cloud = FirestoreAccountStore(
      FirebaseFirestore.instanceFor(app: auth!.app),
      current.uid,
    );
    final proof = await cloud.eraseCloudData();
    await _deletionRecovery!.prepare(current.uid, proof);
    await current.delete();
    lastDeletedUserId = current.uid;
    try {
      await _deletionRecovery!.deleted(current.uid);
    } catch (_) {
      /* Only the content-free replay guard may await cleanup. */
    }
    try {
      await _google?.signOut();
    } catch (_) {
      /* No local Google session. */
    }
  });

  @override
  void dispose() {
    _disposed = true;
    _tokenGeneration++;
    _operationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }
}
