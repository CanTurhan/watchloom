import 'package:flutter/material.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/localization/app_library_strings.dart';
import 'package:watchloom/core/localization/app_show_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/localization/app_monetization_strings.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';
import 'package:watchloom/features/library/domain/library_access_policy.dart';
import 'package:watchloom/features/premium/presentation/premium_page.dart';
import 'package:watchloom/features/shows/domain/entities/tv_episode.dart';
import 'package:watchloom/features/shows/domain/entities/tv_show.dart';

class LibraryEditSheet extends StatefulWidget {
  const LibraryEditSheet({required this.show, super.key});

  final TvShow show;

  static Future<bool?> open(BuildContext context, TvShow show) async {
    final library = AppScope.of(context).libraryController;
    if (library.findByShowId(show.id) == null && !library.canAddShow) {
      await PremiumPage.open(context, libraryLimitReached: true);
      if (!context.mounted || !library.canAddShow) return false;
    }
    if (!context.mounted) return false;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (_) => LibraryEditSheet(show: show),
    );
  }

  @override
  State<LibraryEditSheet> createState() {
    return _LibraryEditSheetState();
  }
}

class _LibraryEditSheetState extends State<LibraryEditSheet> {
  LibraryStatus _status = LibraryStatus.watchlist;

  List<TvEpisode> _episodes = const [];
  bool _isLoadingEpisodes = true;
  bool _hasProgress = false;
  bool _initialized = false;
  bool _isSaving = false;
  Object? _episodeError;

  int? _selectedSeason;
  int? _selectedEpisodeId;

  LibraryEntry? _existingEntry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) {
      return;
    }

    _initialized = true;

    final controller = AppScope.of(context).libraryController;
    _existingEntry = controller.findByShowId(widget.show.id);

    final existingEntry = _existingEntry;

    if (existingEntry != null) {
      _status = existingEntry.status;
      _hasProgress = existingEntry.hasProgress;
      _selectedSeason = existingEntry.lastSeason;
      _selectedEpisodeId = existingEntry.lastEpisodeId;
    }

    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    setState(() {
      _isLoadingEpisodes = true;
      _episodeError = null;
    });

    try {
      final repository = AppScope.of(context).showRepository;
      final episodes = await repository.getEpisodes(widget.show.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _episodes = episodes;
        _isLoadingEpisodes = false;

        if (_hasProgress && episodes.isNotEmpty) {
          final seasons = _availableSeasons;

          if (!seasons.contains(_selectedSeason)) {
            _selectedSeason = seasons.first;
          }

          final seasonEpisodes = _episodesForSelectedSeason;

          final episodeExists = seasonEpisodes.any(
            (episode) => episode.id == _selectedEpisodeId,
          );

          if (!episodeExists && seasonEpisodes.isNotEmpty) {
            _selectedEpisodeId = seasonEpisodes.first.id;
          }
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _episodeError = error;
        _isLoadingEpisodes = false;
      });
    }
  }

  List<int> get _availableSeasons {
    final seasons = _episodes
        .map((episode) => episode.season)
        .whereType<int>()
        .toSet()
        .toList();

    seasons.sort();
    return seasons;
  }

  List<TvEpisode> get _episodesForSelectedSeason {
    final selectedSeason = _selectedSeason;

    if (selectedSeason == null) {
      return const [];
    }

    final episodes = _episodes
        .where((episode) => episode.season == selectedSeason)
        .toList();

    episodes.sort(
      (first, second) => (first.number ?? 0).compareTo(second.number ?? 0),
    );

    return episodes;
  }

  TvEpisode? get _selectedEpisode {
    final selectedId = _selectedEpisodeId;

    if (selectedId == null) {
      return null;
    }

    for (final episode in _episodes) {
      if (episode.id == selectedId) {
        return episode;
      }
    }

    return null;
  }

  void _toggleProgress(bool enabled) {
    setState(() {
      _hasProgress = enabled;

      if (!enabled) {
        _selectedSeason = null;
        _selectedEpisodeId = null;
        return;
      }

      final seasons = _availableSeasons;

      if (seasons.isEmpty) {
        _hasProgress = false;
        return;
      }

      _selectedSeason ??= seasons.first;

      final episodes = _episodesForSelectedSeason;

      if (episodes.isNotEmpty) {
        _selectedEpisodeId ??= episodes.first.id;
      }
    });
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final now = DateTime.now();
    final selectedEpisode = _hasProgress ? _selectedEpisode : null;
    final existingEntry = _existingEntry;

    final entry = LibraryEntry(
      showId: widget.show.id,
      name: widget.show.name,
      summary: widget.show.summary,
      genres: widget.show.genres,
      status: _status,
      imageMedium: widget.show.imageMedium,
      imageOriginal: widget.show.imageOriginal,
      ratingAverage: widget.show.ratingAverage,
      channelName: widget.show.channelName,
      premiered: widget.show.premiered,
      tvMazeUrl: widget.show.tvMazeUrl,
      lastSeason: selectedEpisode?.season,
      lastEpisode: selectedEpisode?.number,
      lastEpisodeId: selectedEpisode?.id,
      isFavorite: existingEntry?.isFavorite ?? false,
      personalNote: existingEntry?.personalNote ?? '',
      addedAt: existingEntry?.addedAt ?? now,
      updatedAt: now,
    );

    try {
      await AppScope.of(context).libraryController.saveEntry(entry);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on LibraryLimitReached {
      if (!mounted) return;
      setState(() => _isSaving = false);
      await PremiumPage.open(context, libraryLimitReached: true);
      if (mounted && AppScope.of(context).libraryController.canAddShow) {
        await _save();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).librarySaveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              _existingEntry == null
                  ? strings.addToLibrary
                  : strings.editLibraryEntry,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.show.name,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 26),
            Text(
              strings.libraryStatus,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<LibraryStatus>(
                  value: _status,
                  isExpanded: true,
                  items: LibraryStatus.values
                      .map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(strings.statusName(status)),
                        );
                      })
                      .toList(growable: false),
                  onChanged: (status) {
                    if (status == null) {
                      return;
                    }

                    setState(() {
                      _status = status;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              strings.progress,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (_isLoadingEpisodes)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(strings.loadingEpisodes),
                  ],
                ),
              )
            else if (_episodeError != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(strings.couldNotLoadEpisodes)),
                    TextButton(
                      onPressed: _loadEpisodes,
                      child: Text(strings.retry),
                    ),
                  ],
                ),
              )
            else if (_episodes.isEmpty)
              Text(
                strings.noEpisodes,
                style: const TextStyle(color: AppColors.textSecondary),
              )
            else ...[
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SwitchListTile(
                  value: _hasProgress,
                  title: Text(strings.trackProgress),
                  onChanged: _toggleProgress,
                ),
              ),
              if (_hasProgress) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DropdownContainer(
                        label: strings.season,
                        child: DropdownButton<int>(
                          value: _selectedSeason,
                          isExpanded: true,
                          items: _availableSeasons
                              .map((season) {
                                return DropdownMenuItem(
                                  value: season,
                                  child: Text('${strings.season} $season'),
                                );
                              })
                              .toList(growable: false),
                          onChanged: (season) {
                            if (season == null) {
                              return;
                            }

                            setState(() {
                              _selectedSeason = season;

                              final episodes = _episodesForSelectedSeason;

                              _selectedEpisodeId = episodes.isEmpty
                                  ? null
                                  : episodes.first.id;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DropdownContainer(
                        label: strings.episode,
                        child: DropdownButton<int>(
                          value: _selectedEpisodeId,
                          isExpanded: true,
                          items: _episodesForSelectedSeason
                              .map((episode) {
                                return DropdownMenuItem(
                                  value: episode.id,
                                  child: Text(
                                    '${strings.episode} '
                                    '${episode.number ?? '-'}',
                                  ),
                                );
                              })
                              .toList(growable: false),
                          onChanged: (episodeId) {
                            setState(() {
                              _selectedEpisodeId = episodeId;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(strings.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownContainer extends StatelessWidget {
  const _DropdownContainer({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 8, 13, 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
