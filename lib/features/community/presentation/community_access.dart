import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/features/community/data/firestore_community_repository.dart';
import 'package:watchloom/features/community/domain/community_repository.dart';

CommunityRepository? communityRepositoryFor(BuildContext context) {
  final auth = AppScope.of(context).accountSession?.auth.auth;
  if (auth == null) return null;
  return FirestoreCommunityRepository(
    firestore: FirebaseFirestore.instanceFor(app: auth.app),
    uid: auth.currentUser?.uid,
  );
}
