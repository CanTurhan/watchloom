import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/localization/app_library_strings.dart';
import 'package:watchloom/features/library/presentation/widgets/library_edit_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchloom/core/localization/app_show_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/shows/domain/entities/tv_episode.dart';
import 'package:watchloom/features/shows/domain/entities/tv_show.dart';
import 'package:watchloom/features/shows/domain/repositories/show_repository.dart';
import 'package:watchloom/features/shows/presentation/widgets/show_detail_personal_panel.dart';
import 'package:watchloom/features/community/presentation/community_page.dart';
import 'package:watchloom/features/community/presentation/community_strings.dart';

class ShowDetailPage extends StatefulWidget {
  const ShowDetailPage({
    required this.showRepository,
    required this.initialShow,
    super.key,
  });

  final ShowRepository showRepository;
  final TvShow initialShow;

  @override
  State<ShowDetailPage> createState() => _ShowDetailPageState();
}

class _ShowDetailPageState extends State<ShowDetailPage> {
  late TvShow _show;

  ShowFailure? _failure;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _show = widget.initialShow;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _failure = null;
    });

    try {
      final show = await widget.showRepository.getShow(_show.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _show = show;
        _isLoading = false;
      });
    } on ShowFailure catch (failure) {
      if (!mounted) {
        return;
      }

      setState(() {
        _failure = failure;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 365,
            title: Text(_show.name),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'show-${_show.id}',
                child: _BackdropImage(
                  imageUrl: _show.imageOriginal ?? _show.imageMedium,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: ShowDetailPersonalPanel(show: widget.initialShow),
            ),
          ),
          if (_isLoading)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_failure != null)
            SliverToBoxAdapter(
              child: _FailureBanner(
                message: _failureMessage(strings, _failure!.type),
                retryText: strings.retry,
                onRetry: _loadDetails,
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ShowHeader(show: _show),
                const SizedBox(height: 20),
                ListenableBuilder(
                  listenable: AppScope.of(context).libraryController,
                  builder: (context, _) {
                    final controller = AppScope.of(context).libraryController;
                    final existing = controller.findByShowId(_show.id);

                    return SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final saved = await LibraryEditSheet.open(
                            context,
                            _show,
                          );

                          if (saved == true && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(strings.savedToLibrary)),
                            );
                          }
                        },
                        icon: Icon(
                          existing == null
                              ? Icons.add_rounded
                              : Icons.edit_rounded,
                        ),
                        label: Text(
                          existing == null
                              ? strings.addToLibrary
                              : strings.editLibraryEntry,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.forum_outlined),
                    title: Text(CommunityStrings.of(context).title),
                    subtitle: Text(CommunityStrings.of(context).subtitle),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => CommunityPage.open(
                      context,
                      showId: _show.id,
                      seriesName: _show.name,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                _SectionTitle(strings.summaryTitle),
                const SizedBox(height: 10),
                Text(
                  _show.summary.isEmpty ? strings.noSummary : _show.summary,
                  style: const TextStyle(
                    color: Color(0xFFD2D3DA),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                _SectionTitle(strings.nextEpisodeTitle),
                const SizedBox(height: 12),
                if (_show.nextEpisode != null)
                  _EpisodeCard(
                    episode: _show.nextEpisode!,
                    dateLabel: _episodeDateLabel(strings, _show.nextEpisode!),
                    accent: AppColors.accent,
                  )
                else
                  _EmptyEpisodeCard(text: strings.noUpcomingEpisode),
                if (_show.previousEpisode != null) ...[
                  const SizedBox(height: 28),
                  _SectionTitle(strings.previousEpisodeTitle),
                  const SizedBox(height: 12),
                  _EpisodeCard(
                    episode: _show.previousEpisode!,
                    dateLabel:
                        _show.previousEpisode!.airDate ??
                        strings.releaseDateUnknown,
                    accent: AppColors.green,
                  ),
                ],
                const SizedBox(height: 30),
                Center(
                  child: TextButton.icon(
                    onPressed: _openTvMaze,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(strings.dataByTvMaze),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _episodeDateLabel(AppStrings strings, TvEpisode episode) {
    final rawDate = episode.airDate;
    final date = DateTime.tryParse(rawDate ?? '');

    if (date == null) {
      return strings.releaseDateUnknown;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final releaseDate = DateTime(date.year, date.month, date.day);

    final difference = releaseDate.difference(today).inDays;

    if (difference == 0) {
      return '${episode.airDate} · ${strings.today}';
    }

    if (difference == 1) {
      return '${episode.airDate} · ${strings.tomorrow}';
    }

    if (difference > 1) {
      return '${episode.airDate} · ${strings.inDays(difference)}';
    }

    return '${episode.airDate} · ${strings.aired}';
  }

  String _failureMessage(AppStrings strings, ShowFailureType type) {
    switch (type) {
      case ShowFailureType.network:
        return strings.networkError;
      case ShowFailureType.rateLimited:
        return strings.rateLimitError;
      case ShowFailureType.notFound:
        return strings.notFoundError;
      case ShowFailureType.invalidResponse:
        return strings.invalidResponseError;
      case ShowFailureType.unknown:
        return strings.unknownError;
    }
  }

  Future<void> _openTvMaze() async {
    final uri = Uri.tryParse(_show.tvMazeUrl ?? 'https://www.tvmaze.com');

    if (uri == null) {
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _BackdropImage extends StatelessWidget {
  const _BackdropImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;

    if (url == null) {
      return const ColoredBox(
        color: AppColors.surface,
        child: Center(
          child: Icon(
            Icons.live_tv_rounded,
            size: 80,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          placeholder: (_, _) => const ColoredBox(
            color: AppColors.surface,
            child: Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (_, _, _) => const ColoredBox(
            color: AppColors.surface,
            child: Center(child: Icon(Icons.broken_image_outlined, size: 54)),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x22000000),
                Color(0x66000000),
                AppColors.background,
              ],
              stops: [0, 0.62, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShowHeader extends StatelessWidget {
  const _ShowHeader({required this.show});

  final TvShow show;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                show.name,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
            ),
            if (show.ratingAverage != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: AppColors.yellow,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      show.ratingAverage!.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (show.genres.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: show.genres
                .map((genre) => _InfoPill(text: genre))
                .toList(growable: false),
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (show.status != null)
              _MetadataItem(label: strings.statusLabel, value: show.status!),
            if (show.channelName != null)
              _MetadataItem(
                label: strings.channelLabel,
                value: show.channelName!,
              ),
            if (show.premiered != null)
              _MetadataItem(
                label: strings.premieredLabel,
                value: show.premiered!,
              ),
          ],
        ),
      ],
    );
  }
}

class _MetadataItem extends StatelessWidget {
  const _MetadataItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.accentSoft,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.episode,
    required this.dateLabel,
    required this.accent,
  });

  final TvEpisode episode;
  final String dateLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (episode.imageUrl != null)
            SizedBox(
              width: double.infinity,
              height: 175,
              child: CachedNetworkImage(
                imageUrl: episode.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => const ColoredBox(
                  color: AppColors.surfaceLight,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, _, _) => const ColoredBox(
                  color: AppColors.surfaceLight,
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  episode.code,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  episode.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (episode.summary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    episode.summary,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFC9CAD1),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyEpisodeCard extends StatelessWidget {
  const _EmptyEpisodeCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_busy_rounded, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({
    required this.message,
    required this.retryText,
    required this.onRetry,
  });

  final String message;
  final String retryText;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.orange),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
          TextButton(onPressed: onRetry, child: Text(retryText)),
        ],
      ),
    );
  }
}
