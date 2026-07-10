import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/localization/app_recommendation_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';
import 'package:watchloom/features/library/presentation/controllers/library_controller.dart';
import 'package:watchloom/features/shows/domain/entities/tv_show.dart';
import 'package:watchloom/features/shows/presentation/show_detail_page.dart';

class RecommendationSection extends StatefulWidget {
  const RecommendationSection({super.key});

  @override
  State<RecommendationSection> createState() {
    return _RecommendationSectionState();
  }
}

class _RecommendationSectionState extends State<RecommendationSection> {
  LibraryController? _libraryController;
  Future<List<_RecommendationItem>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final controller = AppScope.of(context).libraryController;

    if (identical(controller, _libraryController)) {
      return;
    }

    _libraryController?.removeListener(_handleLibraryChange);

    _libraryController = controller;

    controller.addListener(_handleLibraryChange);

    _future = _loadRecommendations();
  }

  @override
  void dispose() {
    _libraryController?.removeListener(_handleLibraryChange);

    super.dispose();
  }

  void _handleLibraryChange() {
    final controller = _libraryController;

    if (!mounted || controller == null || controller.isLoading) {
      return;
    }

    _reload();
  }

  Future<void> _reload() async {
    final future = _loadRecommendations();

    if (!mounted) {
      return;
    }

    setState(() {
      _future = future;
    });

    await future;
  }

  Future<List<_RecommendationItem>> _loadRecommendations() async {
    final scope = AppScope.of(context);
    final libraryEntries = scope.libraryController.entries.toList();

    final existingShowIds = libraryEntries.map((entry) => entry.showId).toSet();

    final genreWeights = _buildGenreWeights(libraryEntries);

    final now = DateTime.now();

    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;

    final pages = <int>{0, 1 + (dayOfYear % 12), 13 + (dayOfYear % 12)};

    final candidates = <int, _RecommendationItem>{};

    for (final page in pages) {
      try {
        final shows = await scope.showRepository.getShowsPage(page);

        for (final show in shows) {
          if (existingShowIds.contains(show.id) || show.imageMedium == null) {
            continue;
          }

          final match = _calculateGenreMatch(show, genreWeights);

          final rating = show.ratingAverage ?? 0;

          if (genreWeights.isEmpty) {
            if (rating < 7) {
              continue;
            }
          } else if (match.score == 0) {
            continue;
          }

          final score = (match.score * 10) + rating;

          final candidate = _RecommendationItem(
            show: show,
            matchedGenre: match.genre,
            score: score,
          );

          final existing = candidates[show.id];

          if (existing == null || candidate.score > existing.score) {
            candidates[show.id] = candidate;
          }
        }
      } catch (_) {
        continue;
      }
    }

    final results = candidates.values.toList()
      ..sort((first, second) {
        final scoreComparison = second.score.compareTo(first.score);

        if (scoreComparison != 0) {
          return scoreComparison;
        }

        return (second.show.ratingAverage ?? 0).compareTo(
          first.show.ratingAverage ?? 0,
        );
      });

    return results.take(10).toList(growable: false);
  }

  Map<String, int> _buildGenreWeights(List<LibraryEntry> entries) {
    final weights = <String, int>{};

    for (final entry in entries) {
      final statusWeight = switch (entry.status) {
        LibraryStatus.watching => 4,
        LibraryStatus.completed => 4,
        LibraryStatus.paused => 2,
        LibraryStatus.watchlist => 1,
        LibraryStatus.dropped => 0,
      };

      if (statusWeight == 0) {
        continue;
      }

      for (final genre in entry.genres) {
        final normalizedGenre = genre.trim().toLowerCase();

        if (normalizedGenre.isEmpty) {
          continue;
        }

        weights.update(
          normalizedGenre,
          (current) => current + statusWeight,
          ifAbsent: () => statusWeight,
        );
      }
    }

    return weights;
  }

  _GenreMatch _calculateGenreMatch(TvShow show, Map<String, int> genreWeights) {
    var totalScore = 0;
    String? bestGenre;
    var bestGenreWeight = 0;

    for (final genre in show.genres) {
      final normalizedGenre = genre.trim().toLowerCase();

      final weight = genreWeights[normalizedGenre] ?? 0;

      totalScore += weight;

      if (weight > bestGenreWeight) {
        bestGenreWeight = weight;
        bestGenre = genre;
      }
    }

    return _GenreMatch(score: totalScore, genre: bestGenre);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                strings.recommendationsTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            TextButton(
              onPressed: _reload,
              child: Text(strings.refreshRecommendations),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<_RecommendationItem>>(
          future: _future ?? _loadRecommendations(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _LoadingCard(text: strings.recommendationsLoading);
            }

            if (snapshot.hasError) {
              return _MessageCard(
                icon: Icons.cloud_off_rounded,
                text: strings.recommendationsFailed,
              );
            }

            final recommendations =
                snapshot.data ?? const <_RecommendationItem>[];

            if (recommendations.isEmpty) {
              return _MessageCard(
                icon: Icons.auto_awesome_outlined,
                text: strings.recommendationsEmpty,
              );
            }

            return SizedBox(
              height: 242,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recommendations.length,
                separatorBuilder: (context, index) {
                  return const SizedBox(width: 12);
                },
                itemBuilder: (context, index) {
                  final recommendation = recommendations[index];

                  return _RecommendationCard(
                    recommendation: recommendation,
                    strings: strings,
                    onTap: () {
                      final scope = AppScope.of(context);

                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ShowDetailPage(
                            showRepository: scope.showRepository,
                            initialShow: recommendation.show,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RecommendationItem {
  const _RecommendationItem({
    required this.show,
    required this.score,
    this.matchedGenre,
  });

  final TvShow show;
  final String? matchedGenre;
  final double score;
}

class _GenreMatch {
  const _GenreMatch({required this.score, required this.genre});

  final int score;
  final String? genre;
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    required this.strings,
    required this.onTap,
  });

  final _RecommendationItem recommendation;
  final AppStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final show = recommendation.show;
    final matchedGenre = recommendation.matchedGenre;

    final reason = matchedGenre == null
        ? strings.recommendationPopularReason
        : strings.recommendationGenreReason(matchedGenre);

    return SizedBox(
      width: 148,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: show.imageMedium!,
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
                    ),
                    if (show.ratingAverage != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: AppColors.yellow,
                                size: 13,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                show.ratingAverage!.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 10, 11, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      show.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.text});

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
