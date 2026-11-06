import 'community_models.dart';

/// Desired votes are idempotent: repeating a confirmed request never adds a
/// second vote. The server transaction pairs these totals with the private vote.
class CommunityVoteTotals {
  const CommunityVoteTotals({required this.upVotes, required this.downVotes});
  static const maxCount = 1000000000;
  final int upVotes;
  final int downVotes;
  int get score => upVotes - downVotes;

  CommunityVoteTotals change({required int previous, required int next}) {
    if (![-1, 0, 1].contains(previous) || ![-1, 0, 1].contains(next)) {
      throw const CommunityException(CommunityFailure.invalidContent);
    }
    final up = upVotes - (previous == 1 ? 1 : 0) + (next == 1 ? 1 : 0);
    final down = downVotes - (previous == -1 ? 1 : 0) + (next == -1 ? 1 : 0);
    if (up < 0 || down < 0 || up > maxCount || down > maxCount) {
      throw const CommunityException(CommunityFailure.invalidContent);
    }
    return CommunityVoteTotals(upVotes: up, downVotes: down);
  }
}
