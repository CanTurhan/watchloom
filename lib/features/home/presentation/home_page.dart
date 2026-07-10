import 'package:cached_network_image/cached_network_image.dart';
import 'package:watchloom/features/recommendations/presentation/widgets/recommendation_section.dart';
import 'package:flutter/material.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/localization/app_activity_strings.dart';
import 'package:watchloom/core/localization/app_library_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/activity/domain/entities/episode_watch_log.dart';
import 'package:watchloom/features/activity/presentation/controllers/watch_activity_controller.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';
import 'package:watchloom/features/library/presentation/controllers/library_controller.dart';
import 'package:watchloom/features/shows/domain/entities/tv_episode.dart';
import 'package:watchloom/features/shows/presentation/show_detail_page.dart';
import 'package:watchloom/features/shows/presentation/show_search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() {
    return _HomePageState();
  }
}

class _HomePageState extends State<HomePage> {
  LibraryController? _libraryController;

  Future<List<_UpcomingEpisode>>? _upcomingFuture;

  bool _ignoreLibraryNotifications = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final controller = AppScope.of(context).libraryController;

    if (identical(_libraryController, controller)) {
      return;
    }

    _libraryController?.removeListener(_handleLibraryChange);

    _libraryController = controller;

    controller.addListener(_handleLibraryChange);

    _upcomingFuture = _loadUpcomingEpisodes();
  }

  @override
  void dispose() {
    _libraryController?.removeListener(_handleLibraryChange);

    super.dispose();
  }

  void _handleLibraryChange() {
    final controller = _libraryController;

    if (!mounted ||
        _ignoreLibraryNotifications ||
        controller == null ||
        controller.isLoading) {
      return;
    }

    _reloadUpcoming();
  }

  Future<void> _reloadUpcoming() async {
    final future = _loadUpcomingEpisodes();

    if (!mounted) {
      return;
    }

    setState(() {
      _upcomingFuture = future;
    });

    await future;
  }

  Future<void> _refresh() async {
    final scope = AppScope.of(context);

    _ignoreLibraryNotifications = true;

    try {
      await scope.libraryController.load();
      await scope.activityController.load();
    } finally {
      _ignoreLibraryNotifications = false;
    }

    await _reloadUpcoming();
  }

  Future<List<_UpcomingEpisode>> _loadUpcomingEpisodes() async {
    final scope = AppScope.of(context);

    final entries = scope.libraryController.entries
        .where(
          (entry) =>
              entry.status != LibraryStatus.completed &&
              entry.status != LibraryStatus.dropped,
        )
        .take(8)
        .toList(growable: false);

    if (entries.isEmpty) {
      return const [];
    }

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final upcomingItems = <_UpcomingEpisode>[];

    for (final entry in entries) {
      try {
        final episodes = await scope.showRepository.getEpisodes(entry.showId);

        _UpcomingEpisode? earliestEpisode;

        for (final episode in episodes) {
          final dateValue = episode.airDate;

          if (dateValue == null ||
              episode.season == null ||
              episode.number == null) {
            continue;
          }

          final parsedDate = DateTime.tryParse(dateValue);

          if (parsedDate == null) {
            continue;
          }

          final airDate = DateTime(
            parsedDate.year,
            parsedDate.month,
            parsedDate.day,
          );

          if (airDate.isBefore(today)) {
            continue;
          }

          final candidate = _UpcomingEpisode(
            entry: entry,
            episode: episode,
            airDate: airDate,
          );

          if (earliestEpisode == null ||
              candidate.airDate.isBefore(earliestEpisode.airDate)) {
            earliestEpisode = candidate;
          }
        }

        if (earliestEpisode != null) {
          upcomingItems.add(earliestEpisode);
        }
      } catch (_) {
        // Bir dizinin bölümleri yüklenemezse diğer
        // dizilerin kontrolüne devam edilir.
      }
    }

    upcomingItems.sort(
      (first, second) => first.airDate.compareTo(second.airDate),
    );

    return upcomingItems.take(5).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final scope = AppScope.of(context);

    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: scope.libraryController,
        builder: (context, child) {
          return ListenableBuilder(
            listenable: scope.activityController,
            builder: (context, child) {
              final libraryEntries = scope.libraryController.entries;

              final activeEntries = libraryEntries
                  .where(
                    (entry) =>
                        entry.status == LibraryStatus.watching ||
                        entry.status == LibraryStatus.paused,
                  )
                  .toList(growable: false);

              final watchlistEntries = libraryEntries
                  .where((entry) => entry.status == LibraryStatus.watchlist)
                  .take(8)
                  .toList(growable: false);

              final activeEntry = activeEntries.isEmpty
                  ? null
                  : activeEntries.first;

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    _HomeHeader(strings: strings),
                    const SizedBox(height: 24),
                    if (activeEntry == null)
                      _NoActiveShowCard(strings: strings)
                    else
                      _ContinueWatchingCard(
                        entry: activeEntry,
                        isProcessing: scope.activityController.isProcessing(
                          activeEntry.showId,
                        ),
                        strings: strings,
                        onOpen: () {
                          _openShow(context, activeEntry);
                        },
                        onMarkNext: () {
                          _markNextEpisode(context, strings, activeEntry);
                        },
                      ),
                    const SizedBox(height: 28),
                    _SectionHeader(title: strings.upcomingEpisodesTitle),
                    const SizedBox(height: 12),
                    _UpcomingSection(
                      future: _upcomingFuture ?? _loadUpcomingEpisodes(),
                      strings: strings,
                      onOpen: (entry) {
                        _openShow(context, entry);
                      },
                    ),
                    const SizedBox(height: 28),
                    _SectionHeader(
                      title: strings.homeWatchlistTitle,
                      actionText: watchlistEntries.isEmpty
                          ? null
                          : '${watchlistEntries.length}',
                    ),
                    const SizedBox(height: 12),
                    if (watchlistEntries.isEmpty)
                      _EmptySectionCard(
                        icon: Icons.bookmark_border_rounded,
                        text: strings.homeNoActiveShowDescription,
                      )
                    else
                      SizedBox(
                        height: 208,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: watchlistEntries.length,
                          separatorBuilder: (context, index) {
                            return const SizedBox(width: 12);
                          },
                          itemBuilder: (context, index) {
                            final entry = watchlistEntries[index];

                            return _WatchlistCard(
                              entry: entry,
                              onTap: () {
                                _openShow(context, entry);
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 28),
                    const RecommendationSection(),
                    const SizedBox(height: 28),
                    _SectionHeader(
                      title: strings.homeRecentActivityTitle,
                      actionText: scope.activityController.canUndoLatest
                          ? strings.undoLastWatchAction
                          : null,
                      onAction: scope.activityController.canUndoLatest
                          ? () {
                              _undoLastEpisode(context, strings);
                            }
                          : null,
                    ),
                    const SizedBox(height: 12),
                    if (scope.activityController.logs.isEmpty)
                      _EmptySectionCard(
                        icon: Icons.history_rounded,
                        text: strings.homeNoRecentActivity,
                      )
                    else
                      ...scope.activityController.logs
                          .take(4)
                          .map(
                            (log) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ActivityCard(log: log),
                            ),
                          ),
                    const SizedBox(height: 18),
                    _MonthlySummaryCard(
                      strings: strings,
                      episodes: scope.activityController.monthEpisodeCount,
                      shows: scope.activityController.monthShowCount,
                      minutes: scope.activityController.monthWatchMinutes,
                      dailyStreak: scope.activityController.currentDailyStreak,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openShow(BuildContext context, LibraryEntry entry) {
    final scope = AppScope.of(context);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShowDetailPage(
          showRepository: scope.showRepository,
          initialShow: entry.toTvShow(),
        ),
      ),
    );
  }

  Future<void> _markNextEpisode(
    BuildContext context,
    AppStrings strings,
    LibraryEntry entry,
  ) async {
    final controller = AppScope.of(context).activityController;

    final result = await controller.markNextEpisode(entry);

    if (!context.mounted) {
      return;
    }

    late final String message;

    switch (result.status) {
      case MarkNextEpisodeStatus.success:
        final episode = result.episode!;

        message = strings.episodeLoggedMessage(
          episode.season!,
          episode.number!,
        );

      case MarkNextEpisodeStatus.noAvailableEpisode:
        message = strings.noNextEpisodeMessage;

      case MarkNextEpisodeStatus.alreadyRecorded:
        message = strings.episodeAlreadyLoggedMessage;

      case MarkNextEpisodeStatus.failed:
        message = strings.episodeLogFailedMessage;
    }

    final succeeded = result.status == MarkNextEpisodeStatus.success;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: succeeded
            ? SnackBarAction(
                label: strings.undoAction,
                onPressed: () {
                  _undoLastEpisode(context, strings);
                },
              )
            : null,
      ),
    );
  }

  Future<void> _undoLastEpisode(
    BuildContext context,
    AppStrings strings,
  ) async {
    final result = await AppScope.of(
      context,
    ).activityController.undoLastEpisode();

    if (!context.mounted) {
      return;
    }

    late final String message;

    switch (result.status) {
      case UndoLatestEpisodeStatus.success:
        final log = result.log!;

        message = strings.watchUndoneMessage(
          log.showName,
          log.season,
          log.episodeNumber,
        );

      case UndoLatestEpisodeStatus.nothingToUndo:
        message = strings.nothingToUndoMessage;

      case UndoLatestEpisodeStatus.libraryEntryMissing:
        message = strings.undoLibraryMissingMessage;

      case UndoLatestEpisodeStatus.failed:
        message = strings.undoFailedMessage;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _UpcomingEpisode {
  const _UpcomingEpisode({
    required this.entry,
    required this.episode,
    required this.airDate,
  });

  final LibraryEntry entry;
  final TvEpisode episode;
  final DateTime airDate;
}

class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({
    required this.future,
    required this.strings,
    required this.onOpen,
  });

  final Future<List<_UpcomingEpisode>> future;
  final AppStrings strings;
  final ValueChanged<LibraryEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_UpcomingEpisode>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _UpcomingLoadingCard();
        }

        if (snapshot.hasError) {
          return _EmptySectionCard(
            icon: Icons.cloud_off_rounded,
            text: strings.upcomingLoadFailed,
          );
        }

        final items = snapshot.data ?? const <_UpcomingEpisode>[];

        if (items.isEmpty) {
          return _EmptySectionCard(
            icon: Icons.event_busy_rounded,
            text: strings.noUpcomingEpisodesDescription,
          );
        }

        return Column(
          children: items
              .map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _UpcomingEpisodeCard(
                    item: item,
                    strings: strings,
                    onTap: () {
                      onOpen(item.entry);
                    },
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}

class _UpcomingLoadingCard extends StatelessWidget {
  const _UpcomingLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 14),
          Expanded(child: LinearProgressIndicator()),
        ],
      ),
    );
  }
}

class _UpcomingEpisodeCard extends StatelessWidget {
  const _UpcomingEpisodeCard({
    required this.item,
    required this.strings,
    required this.onTap,
  });

  final _UpcomingEpisode item;
  final AppStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final daysRemaining = item.airDate.difference(today).inDays;

    final remainingText = switch (daysRemaining) {
      0 => strings.todayLabel,
      1 => strings.tomorrowLabel,
      _ => strings.daysRemainingLabel(daysRemaining),
    };

    final seasonText = item.episode.season.toString().padLeft(2, '0');

    final episodeText = item.episode.number.toString().padLeft(2, '0');

    final formattedDate = MaterialLocalizations.of(
      context,
    ).formatMediumDate(item.airDate);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 54,
                height: 72,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _PosterImage(url: item.entry.imageMedium),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'S$seasonText · E$episodeText',
                      style: const TextStyle(
                        color: AppColors.accentSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  remainingText,
                  style: const TextStyle(
                    color: AppColors.accentSoft,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WATCHLOOM',
                style: TextStyle(
                  color: AppColors.accentSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.tagline,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ShowSearchPage(
                  showRepository: scope.showRepository,
                  autofocus: true,
                ),
              ),
            );
          },
          icon: const Icon(Icons.search_rounded),
        ),
      ],
    );
  }
}

class _NoActiveShowCard extends StatelessWidget {
  const _NoActiveShowCard({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.play_circle_outline_rounded,
              color: AppColors.accentSoft,
              size: 36,
            ),
          ),
          const SizedBox(height: 17),
          Text(
            strings.homeNoActiveShowTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            strings.homeNoActiveShowDescription,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ShowSearchPage(
                    showRepository: scope.showRepository,
                    autofocus: true,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.search_rounded),
            label: Text(strings.openDiscoverAction),
          ),
        ],
      ),
    );
  }
}

class _ContinueWatchingCard extends StatelessWidget {
  const _ContinueWatchingCard({
    required this.entry,
    required this.isProcessing,
    required this.strings,
    required this.onOpen,
    required this.onMarkNext,
  });

  final LibraryEntry entry;
  final bool isProcessing;
  final AppStrings strings;
  final VoidCallback onOpen;
  final VoidCallback onMarkNext;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 306,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _BackdropImage(url: entry.imageOriginal ?? entry.imageMedium),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33000000),
                    Color(0x9911131C),
                    Color(0xFF11131C),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(21),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        strings.statusName(entry.status),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    entry.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.hasProgress ? entry.progressCode : strings.notStarted,
                    style: const TextStyle(
                      color: AppColors.accentSoft,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: isProcessing ? null : onMarkNext,
                          icon: isProcessing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(
                            strings.markNextEpisodeAction,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        onPressed: onOpen,
                        tooltip: strings.viewDetailsAction,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchlistCard extends StatelessWidget {
  const _WatchlistCard({required this.entry, required this.onTap});

  final LibraryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 138,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: _PosterImage(url: entry.imageMedium),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 10, 11, 12),
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.log});

  final EpisodeWatchLog log;

  @override
  Widget build(BuildContext context) {
    final date = log.watchedAt.toLocal();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: const Color(0xFF4ADE80).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.check_rounded, color: Color(0xFF4ADE80)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.showName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  log.episodeCode,
                  style: const TextStyle(
                    color: AppColors.accentSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${date.day.toString().padLeft(2, '0')}.'
            '${date.month.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  const _MonthlySummaryCard({
    required this.strings,
    required this.episodes,
    required this.shows,
    required this.minutes,
    required this.dailyStreak,
  });

  final AppStrings strings;
  final int episodes;
  final int shows;
  final int minutes;
  final int dailyStreak;

  @override
  Widget build(BuildContext context) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    final watchTime = hours > 0
        ? '${hours}h ${remainingMinutes}m'
        : '${remainingMinutes}m';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.homeMonthlySummaryTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _SummaryValue(value: '$episodes', label: strings.episodes),
              _SummaryValue(value: '$shows', label: strings.shows),
              _SummaryValue(value: watchTime, label: strings.watchTimeLabel),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: AppColors.orange,
              ),
              const SizedBox(width: 9),
              Text(
                '$dailyStreak ${strings.dayUnit}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  strings.dailyStreakLabel,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionText, this.onAction});

  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (actionText != null)
          TextButton(onPressed: onAction, child: Text(actionText!)),
      ],
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackdropImage extends StatelessWidget {
  const _BackdropImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;

    if (imageUrl == null) {
      return const ColoredBox(
        color: AppColors.surfaceLight,
        child: Icon(Icons.live_tv_rounded, size: 70, color: Colors.white24),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      placeholder: (context, url) {
        return const ColoredBox(color: AppColors.surfaceLight);
      },
      errorWidget: (context, url, error) {
        return const ColoredBox(
          color: AppColors.surfaceLight,
          child: Icon(Icons.live_tv_rounded, size: 70, color: Colors.white24),
        );
      },
    );
  }
}

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;

    if (imageUrl == null) {
      return const ColoredBox(
        color: AppColors.surfaceLight,
        child: Icon(Icons.live_tv_rounded, color: AppColors.textSecondary),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) {
        return const ColoredBox(color: AppColors.surfaceLight);
      },
      errorWidget: (context, url, error) {
        return const ColoredBox(
          color: AppColors.surfaceLight,
          child: Icon(Icons.broken_image_outlined),
        );
      },
    );
  }
}
