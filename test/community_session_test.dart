import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/features/community/data/community_session.dart';
import 'package:watchloom/features/community/domain/community_models.dart';

void main() {
  for (final phase in ['reload', 'token']) {
    testWidgets('session $phase timeout stops subsequent authorization work', (
      tester,
    ) async {
      final gate = Completer<void>();
      final user = _User('apple.com');
      if (phase == 'reload') {
        user.reloadGate = gate.future;
      } else {
        user.tokenGate = gate.future;
      }
      Object? failure;
      final pending = prepareCommunitySession(_Auth(user), 'owner').catchError((
        Object error,
      ) {
        failure = error;
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 21));
      await pending;
      expect(
        failure,
        isA<CommunityException>().having(
          (e) => e.failure,
          'failure',
          CommunityFailure.timedOut,
        ),
      );
      gate.complete();
      await tester.pump();
      expect(
        user.events,
        phase == 'reload' ? ['reload'] : ['reload', 'token:true'],
      );
    });
  }
  final denied = isA<CommunityException>().having(
    (e) => e.failure,
    'failure',
    CommunityFailure.verificationRequired,
  );
  for (final provider in ['apple.com', 'google.com', 'password']) {
    test('$provider authorizes from fresh claims after reload', () async {
      final user = _User(provider, verified: provider == 'password');
      final auth = _Auth(user);
      await prepareCommunitySession(auth, 'owner');
      expect(user.events, ['reload', 'token:true']);
    });
  }
  test(
    'unverified password cannot inherit trust from local emailVerified',
    () async {
      final user = _User('password', verified: false);
      expect(user.emailVerified, isTrue);
      await expectLater(
        prepareCommunitySession(_Auth(user), 'owner'),
        throwsA(denied),
      );
    },
  );
  test(
    'verification performed outside app is reflected by fresh token',
    () async {
      final user = _User('password', verified: false);
      user.onReload = () => user.verified = true;
      await prepareCommunitySession(_Auth(user), 'owner');
      expect(user.events, ['reload', 'token:true']);
    },
  );
  test('account switches during reload or token refresh fail closed', () async {
    for (final duringToken in [false, true]) {
      final user = _User('apple.com');
      final auth = _Auth(user);
      void switchAccount() => auth.current = _User('google.com', uid: 'other');
      if (duringToken) {
        user.onToken = switchAccount;
      } else {
        user.onReload = switchAccount;
      }
      await expectLater(
        prepareCommunitySession(auth, 'owner'),
        throwsA(denied),
      );
    }
  });
  test('signed out and stale repository bindings fail closed', () async {
    await expectLater(
      prepareCommunitySession(_Auth(null), 'owner'),
      throwsA(denied),
    );
    await expectLater(
      prepareCommunitySession(_Auth(_User('apple.com')), 'other'),
      throwsA(denied),
    );
  });
}

class _Auth implements FirebaseAuth {
  _Auth(this.current);
  User? current;
  @override
  User? get currentUser => current;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  _User(this.provider, {this.verified = false, this.uid = 'owner'});
  final String provider;
  bool verified;
  @override
  final String uid;
  final events = <String>[];
  void Function()? onReload, onToken;
  Future<void>? reloadGate, tokenGate;
  @override
  bool get emailVerified => true; // Intentionally stale local state.
  @override
  Future<void> reload() async {
    events.add('reload');
    if (reloadGate != null) await reloadGate;
    onReload?.call();
  }

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async {
    events.add('token:$forceRefresh');
    if (tokenGate != null) await tokenGate;
    onToken?.call();
    return _Token(provider, verified);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Token implements IdTokenResult {
  _Token(this.signInProvider, this.verified);
  @override
  final String signInProvider;
  final bool verified;
  @override
  Map<String, dynamic> get claims => {'email_verified': verified};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
