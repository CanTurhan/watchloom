import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/localization/app_activity_strings.dart';
import 'package:watchloom/core/localization/app_library_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/activity/presentation/controllers/watch_activity_controller.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';
import 'package:watchloom/features/shows/presentation/show_detail_page.dart';
import 'package:watchloom/features/shows/presentation/show_search_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() {
    return _LibraryPageState();
  }
}

class _LibraryPageState extends State<LibraryPage> {
  LibraryStatus? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final scope = AppScope.of(context);
    final libraryController = scope.libraryController;
    final activityController = scope.activityController;

    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: libraryController,
        builder: (context, child) {
          return ListenableBuilder(
            listenable: activityController,
            builder: (context, child) {
              final entries = libraryController.entries
                  .where((entry) {
                    final selectedStatus = _selectedStatus;

                    return selectedStatus == null ||
                        entry.status == selectedStatus;
                  })
                  .toList(growable: false);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.library,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ),
                        Text(
                          '${libraryController.entries.length}',
                          style: const TextStyle(
                            color: AppColors.accentSoft,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilterChip(
                            label: Text(strings.all),
                            selected: _selectedStatus == null,
                            onSelected: (selected) {
                              setState(() {
                                _selectedStatus = null;
                              });
                            },
                          ),
                        ),
                        ...LibraryStatus.values.map((status) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FilterChip(
                              label: Text(strings.statusName(status)),
                              selected: _selectedStatus == status,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedStatus = status;
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: _buildContent(context, strings, entries)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppStrings strings,
    List<LibraryEntry> entries,
  ) {
    final scope = AppScope.of(context);
    final libraryController = scope.libraryController;
    final activityController = scope.activityController;

    if (libraryController.isLoading && libraryController.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (entries.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              Container(
                width: 98,
                height: 98,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.video_library_outlined,
                  color: AppColors.accentSoft,
                  size: 46,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                strings.emptyLibraryTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                strings.emptyLibraryDescription,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
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
                label: Text(strings.searchAndAdd),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await libraryController.load();
        await activityController.load();
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: entries.length,
        separatorBuilder: (context, index) {
          return const SizedBox(height: 10);
        },
        itemBuilder: (context, index) {
          final entry = entries[index];

          return _LibraryCard(
            entry: entry,
            statusText: strings.statusName(entry.status),
            notStartedText: strings.notStarted,
            removeText: strings.remove,
            markText: strings.markNextEpisodeAction,
            isProcessing: activityController.isProcessing(entry.showId),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ShowDetailPage(
                    showRepository: scope.showRepository,
                    initialShow: entry.toTvShow(),
                  ),
                ),
              );
            },
            onMarkNext: () {
              _markNextEpisode(context, strings, entry);
            },
            onRemove: () {
              _removeEntry(context, strings, entry);
            },
          );
        },
      ),
    );
  }

  Future<void> _markNextEpisode(
    BuildContext context,
    AppStrings strings,
    LibraryEntry entry,
  ) async {
    final result = await AppScope.of(
      context,
    ).activityController.markNextEpisode(entry);

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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _removeEntry(
    BuildContext context,
    AppStrings strings,
    LibraryEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(strings.removeFromLibrary),
          content: Text(strings.removeConfirmation),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(strings.remove),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    await AppScope.of(context).libraryController.deleteEntry(entry.showId);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.showRemoved)));
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.entry,
    required this.statusText,
    required this.notStartedText,
    required this.removeText,
    required this.markText,
    required this.isProcessing,
    required this.onTap,
    required this.onMarkNext,
    required this.onRemove,
  });

  final LibraryEntry entry;
  final String statusText;
  final String notStartedText;
  final String removeText;
  final String markText;
  final bool isProcessing;
  final VoidCallback onTap;
  final VoidCallback onMarkNext;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 140,
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    height: double.infinity,
                    child: _Poster(url: entry.imageMedium),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(15, 14, 4, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              statusText,
                              style: const TextStyle(
                                color: AppColors.accentSoft,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            entry.hasProgress
                                ? entry.progressCode
                                : notStartedText,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'remove') {
                        onRemove();
                      }
                    },
                    itemBuilder: (context) {
                      return [
                        PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline_rounded),
                              const SizedBox(width: 10),
                              Text(removeText),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          InkWell(
            onTap: isProcessing ? null : onMarkNext,
            child: SizedBox(
              height: 50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isProcessing)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF4ADE80),
                      size: 20,
                    ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      markText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.url});

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
