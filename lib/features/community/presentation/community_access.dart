import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/features/community/data/firestore_community_repository.dart';
import 'package:watchloom/features/community/domain/community_repository.dart';
import 'package:watchloom/features/community/data/community_moderation_client.dart';

CommunityRepository? communityRepositoryFor(BuildContext context) {
  final auth = AppScope.of(context).accountSession?.auth.auth;
  if (auth == null) return null;
  final uid = auth.currentUser?.uid;
  return FirestoreCommunityRepository(
    firestore: FirebaseFirestore.instanceFor(app: auth.app),
    uid: uid,
    moderationRequest: uid == null
        ? null
        : (commentId, endpoint) async {
            final client = http.Client();
            try {
              await CommunityModerationClient(
                boundUid: uid,
                currentUid: () => auth.currentUser?.uid,
                idToken: () async {
                  final user = auth.currentUser;
                  if (user?.uid != uid) return null;
                  return user!.getIdToken(true);
                },
                client: client,
              ).request(commentId, endpoint);
            } finally {
              client.close();
            }
          },
  );
}
