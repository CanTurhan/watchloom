import 'community_models.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';

CommunityWatchContext watchContextForEntry(LibraryEntry? entry) {
  if (entry == null) return const CommunityWatchContext(status: 'not_started');
  if (entry.isMovie) {
    return CommunityWatchContext(
      status: entry.status == LibraryStatus.completed || entry.hasProgress
          ? 'watched'
          : 'not_started',
    );
  }
  return CommunityWatchContext(
    status: entry.status == LibraryStatus.completed
        ? 'watched'
        : entry.hasProgress
        ? 'watching'
        : 'not_started',
    season: entry.hasProgress ? entry.lastSeason : null,
    episode: entry.hasProgress ? entry.lastEpisode : null,
  );
}
