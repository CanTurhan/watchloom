import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/core/database/watchloom_database.dart';
import 'package:watchloom/features/account/presentation/account_session_controller.dart';
import 'package:watchloom/features/account/presentation/auth_controller.dart';
import 'package:watchloom/features/activity/presentation/controllers/watch_activity_controller.dart';
import 'package:watchloom/features/library/domain/library_access_policy.dart';
import 'package:watchloom/features/library/presentation/controllers/library_controller.dart';
import 'package:watchloom/features/shows/domain/repositories/show_repository.dart';

void main() {
  testWidgets(
    'stuck local account setup ends with retry while preserving current data',
    (tester) async {
      final auth = AuthController.guestOnly();
      final library = _Library(), activity = _Activity();
      var gate = Completer<void>();
      var attempts = 0;
      final session = AccountSessionController(
        auth: auth,
        showRepository: _Shows(),
        accessPolicy: const LibraryAccessPolicy.free(),
        guestDatabase: WatchloomDatabase(),
        library: library,
        activity: activity,
        prepareLocalSession: () {
          attempts++;
          return gate.future;
        },
      );
      final first = session.retry();
      expect(session.switching, isTrue);
      await tester.pump(const Duration(seconds: 21));
      await first;
      expect(session.failed, isTrue);
      expect(session.switching, isFalse);
      expect(session.library, same(library));
      expect(session.activity, same(activity));
      expect(library.disposed, isFalse);
      expect(activity.disposed, isFalse);
      gate.complete();
      await tester.pump();
      expect(session.failed, isTrue);
      gate = Completer<void>();
      final retry = session.retry();
      expect(attempts, 2);
      expect(session.failed, isFalse);
      expect(session.switching, isTrue);
      gate.completeError(StateError('platform-not-ready'));
      await retry;
      expect(session.switching, isFalse);
      expect(session.failed, isTrue);
      session.dispose();
      auth.dispose();
      library.dispose();
      activity.dispose();
    },
  );

  testWidgets(
    'late native preparation after session disposal cannot install controllers',
    (tester) async {
      final auth = AuthController.guestOnly();
      final library = _Library(), activity = _Activity();
      final gate = Completer<void>();
      final session = AccountSessionController(
        auth: auth,
        showRepository: _Shows(),
        accessPolicy: const LibraryAccessPolicy.free(),
        guestDatabase: WatchloomDatabase(),
        library: library,
        activity: activity,
        prepareLocalSession: () => gate.future,
      );
      var notifications = 0;
      session.addListener(() => notifications++);
      final pending = session.retry();
      session.dispose();
      gate.complete();
      await pending;
      expect(notifications, 1);
      expect(session.library, same(library));
      expect(tester.takeException(), isNull);
      auth.dispose();
      library.dispose();
      activity.dispose();
    },
  );
}

class _Library extends ChangeNotifier implements LibraryController {
  bool disposed = false;
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Activity extends ChangeNotifier implements WatchActivityController {
  bool disposed = false;
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Shows implements ShowRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
