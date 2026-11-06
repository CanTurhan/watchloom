import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/community_models.dart';
import '../domain/community_vote.dart';

abstract final class CommunityVoteTransaction {
  static Future<void> apply({
    required FirebaseFirestore firestore,
    required String uid,
    required String commentId,
    required int value,
    bool erasing = false,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9]{20}$').hasMatch(commentId) ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(uid) ||
        ![-1, 0, 1].contains(value) ||
        (erasing && value != 0)) {
      throw const CommunityException(CommunityFailure.invalidContent);
    }
    final profileRef = firestore.doc('communityProfiles/$uid');
    final commentRef = firestore.doc('communityComments/$commentId');
    final voteRef = firestore.doc('users/$uid/communityVotes/$commentId');
    Future<void> attempt({
      required bool updateTarget,
    }) => firestore.runTransaction((tx) async {
      final profile = (await tx.get(profileRef)).data();
      // A previous voter cannot read a now-hidden comment. Neutral withdrawal
      // needs no body/author read; rules prove the paired numeric transforms.
      final comment = value == 0 ? null : (await tx.get(commentRef)).data();
      final vote = (await tx.get(voteRef)).data();
      if (profile == null) {
        throw const CommunityException(CommunityFailure.identityRequired);
      }
      final oldValue = vote == null ? 0 : vote['value'];
      if (oldValue is! int ||
          ![-1, 0, 1].contains(oldValue) ||
          (vote != null && oldValue == 0)) {
        throw const CommunityException(CommunityFailure.invalidContent);
      }
      if (oldValue == value) return;
      if (value != 0) {
        if (profile['acceptedPolicyVersion'] != communityPolicyVersion) {
          throw const CommunityException(CommunityFailure.termsRequired);
        }
        if (comment == null ||
            comment['status'] != 'approved' ||
            comment['authorUid'] == uid) {
          throw const CommunityException(CommunityFailure.permissionDenied);
        }
      }
      final count = profile['voteCount'] ?? 0;
      if (count is! int) {
        throw const CommunityException(CommunityFailure.invalidContent);
      }
      final nextCount = count + (value == 0 ? 0 : 1) - (oldValue == 0 ? 0 : 1);
      if (nextCount < 0 || nextCount > CommunityVoteTotals.maxCount) {
        throw const CommunityException(CommunityFailure.invalidContent);
      }
      if (value == 0 && updateTarget) {
        tx.update(commentRef, {
          'scoreSchema': 1,
          'upVotes': FieldValue.increment(oldValue == 1 ? -1 : 0),
          'downVotes': FieldValue.increment(oldValue == -1 ? -1 : 0),
          'score': FieldValue.increment(-oldValue),
        });
      } else if (comment != null) {
        final up = comment['upVotes'] ?? 0, down = comment['downVotes'] ?? 0;
        if (up is! int || down is! int) {
          throw const CommunityException(CommunityFailure.invalidContent);
        }
        final totals = CommunityVoteTotals(
          upVotes: up,
          downVotes: down,
        ).change(previous: oldValue, next: value);
        tx.update(commentRef, {
          'upVotes': totals.upVotes,
          'downVotes': totals.downVotes,
          'score': totals.score,
          'scoreSchema': 1,
        });
      }
      if (value == 0) {
        tx.delete(voteRef);
      } else {
        tx.set(voteRef, {
          'commentId': commentId,
          'value': value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      tx.update(profileRef, {
        'voteCount': nextCount,
        'lastVoteId': commentId,
        'lastVoteAt': FieldValue.serverTimestamp(),
      });
    });
    try {
      await attempt(updateTarget: true);
    } on FirebaseException catch (error) {
      if (value != 0 ||
          !['not-found', 'permission-denied'].contains(error.code)) {
        rethrow;
      }
      // Missing targets can return either code. The fallback still pairs the
      // vote/profile writes, and rules reject it if the target actually exists.
      // Unknown/network failures are never converted into successful cleanup.
      await attempt(updateTarget: false);
    }
  }
}
