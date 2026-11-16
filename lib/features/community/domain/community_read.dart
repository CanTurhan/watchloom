import 'dart:async';
import 'package:flutter/foundation.dart';
import 'community_models.dart';

/// Only reads may be abandoned. A timed-out write can still commit on the
/// server, so writes must never use this helper or be automatically repeated.
abstract final class CommunityRead {
  static const timeout = Duration(seconds: 20);

  static Future<T> run<T>(String operation, Future<T> Function() read) async {
    try {
      return await read().timeout(timeout);
    } on TimeoutException {
      debugPrint('community operation=$operation code=deadline-exceeded');
      throw const CommunityException(CommunityFailure.timedOut);
    }
  }
}
