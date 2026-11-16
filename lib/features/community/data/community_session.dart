import 'package:firebase_auth/firebase_auth.dart';
import '../domain/community_models.dart';
import '../domain/community_read.dart';

/// Trust the refreshed session's claims, never a linked provider list or email
/// address. Binding checks prevent an account switch from preparing another UID.
Future<void> prepareCommunitySession(FirebaseAuth auth, String? uid) async {
  final user = auth.currentUser;
  if (user == null || user.uid != uid) {
    throw const CommunityException(CommunityFailure.verificationRequired);
  }
  await CommunityRead.run('sessionReload', user.reload);
  final current = auth.currentUser;
  if (current == null || current.uid != uid) {
    throw const CommunityException(CommunityFailure.verificationRequired);
  }
  final token = await CommunityRead.run(
    'sessionToken',
    () => current.getIdTokenResult(true),
  );
  if (auth.currentUser?.uid != uid ||
      !(token.claims?['email_verified'] == true ||
          ['apple.com', 'google.com'].contains(token.signInProvider))) {
    throw const CommunityException(CommunityFailure.verificationRequired);
  }
}
