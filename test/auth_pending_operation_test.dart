import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/features/account/presentation/auth_controller.dart';
import 'package:watchloom/features/account/presentation/sign_in_page.dart';

void main() {
  testWidgets(
    'slow native Apple sign-in stops spinner but retains operation lock',
    (tester) async {
      tester.view.physicalSize = const Size(700, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final firebase = _Auth();
      final auth = AuthController.withAuth(firebase);
      await tester.pumpWidget(MaterialApp(home: SignInPage(auth: auth)));
      final first = auth.apple();
      await tester.pump();
      expect(auth.busy, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 45));
      expect(auth.operationSlow, isTrue);
      expect(auth.busy, isTrue);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.textContaining('taking longer than expected'),
        findsOneWidget,
      );
      final apple = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Continue with Apple'),
      );
      expect(apple.onPressed, isNull);
      final back = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Continue as guest'),
      );
      expect(back.onPressed, isNotNull);
      expect(await auth.apple(), isFalse);
      expect(firebase.providerCalls, 1);
      firebase.gate.complete(_Credential());
      expect(await first, isTrue);
      await tester.pump();
      expect(auth.busy, isFalse);
      expect(auth.operationSlow, isFalse);
      expect(auth.errorCode, isNull);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );

  testWidgets('native cancellation clears a previous slow-operation notice', (
    tester,
  ) async {
    final firebase = _Auth();
    final auth = AuthController.withAuth(firebase);
    final pending = auth.apple();
    await tester.pump(const Duration(seconds: 45));
    expect(auth.errorCode, 'operation-pending');
    firebase.gate.completeError(PlatformException(code: 'sign_in_canceled'));
    expect(await pending, isFalse);
    expect(auth.busy, isFalse);
    expect(auth.operationSlow, isFalse);
    expect(auth.errorCode, isNull);
    auth.dispose();
  });

  testWidgets('a stale session failure never signs out a different account', (
    tester,
  ) async {
    final first = _User('first');
    final firebase = _Auth()..current = first;
    final auth = AuthController.withAuth(firebase);
    auth.didChangeAppLifecycleState(AppLifecycleState.resumed);
    auth.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(first.reloadCalls, 1);
    firebase.current = _User('next');
    first.reloadGate.completeError(
      FirebaseAuthException(code: 'user-disabled'),
    );
    await tester.pump();
    expect(firebase.signOutCalls, 0);
    expect(firebase.currentUser!.uid, 'next');
    auth.dispose();
  });

  testWidgets('refresh timeout releases busy state and preserves the account', (
    tester,
  ) async {
    final first = _User('first');
    final firebase = _Auth()..current = first;
    final auth = AuthController.withAuth(firebase);
    final pending = auth.refreshUser();
    await tester.pump(const Duration(seconds: 16));
    expect(await pending, isFalse);
    expect(auth.busy, isFalse);
    expect(firebase.currentUser!.uid, 'first');
    expect(firebase.signOutCalls, 0);
    first.reloadGate.complete();
    await tester.pump();
    auth.dispose();
  });

  testWidgets('late native failure releases lock and a retry can start', (
    tester,
  ) async {
    final firebase = _Auth();
    final auth = AuthController.withAuth(firebase);
    final first = auth.apple();
    await tester.pump(const Duration(seconds: 45));
    firebase.gate.completeError(
      FirebaseAuthException(code: 'web-context-cancelled'),
    );
    expect(await first, isFalse);
    expect(auth.busy, isFalse);
    expect(auth.operationSlow, isFalse);
    expect(auth.errorCode, 'web-context-cancelled');
    firebase.gate = Completer<UserCredential>();
    final retry = auth.apple();
    expect(firebase.providerCalls, 2);
    expect(auth.errorCode, isNull);
    firebase.gate.complete(_Credential());
    expect(await retry, isTrue);
    auth.dispose();
  });

  testWidgets(
    'late native completion after controller disposal never notifies',
    (tester) async {
      final firebase = _Auth();
      final auth = AuthController.withAuth(firebase);
      var notices = 0;
      auth.addListener(() => notices++);
      final pending = auth.apple();
      expect(notices, 1);
      auth.dispose();
      await tester.pump(const Duration(minutes: 1));
      firebase.gate.complete(_Credential());
      await pending;
      expect(notices, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Auth implements FirebaseAuth {
  Completer<UserCredential> gate = Completer<UserCredential>();
  int providerCalls = 0;
  int signOutCalls = 0;
  User? current;
  @override
  User? get currentUser => current;
  @override
  Future<void> signOut() async {
    signOutCalls++;
    current = null;
  }

  @override
  Future<UserCredential> signInWithProvider(AuthProvider provider) {
    providerCalls++;
    return gate.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Credential implements UserCredential {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  final reloadGate = Completer<void>();
  int reloadCalls = 0;
  @override
  Future<void> reload() {
    reloadCalls++;
    return reloadGate.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
