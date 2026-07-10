import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/localization/app_library_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';
import 'package:watchloom/features/shows/presentation/show_detail_page.dart';
import 'package:watchloom/features/shows/presentation/show_search_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  LibraryStatus? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final scope = AppScope.of(context);
    final controller = scope.libraryController;

    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final entries = controller.entries
              .where((entry) {
                final selectedStatus = _selectedStatus;

                return selectedStatus == null || entry.status == selectedStatus;
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
                      '${controller.entries.length}',
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
                        onSelected: (_) {
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
                          onSelected: (_) {
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
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppStrings strings,
    List<LibraryEntry> entries,
  ) {
    final scope = AppScope.of(context);
    final controller = scope.libraryController;

    if (controller.isLoading && controller.entries.isEmpty) {
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
      onRefresh: controller.load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final entry = entries[index];

          return _LibraryCard(
            entry: entry,
            statusText: strings.statusName(entry.status),
            notStartedText: strings.notStarted,
            removeText: strings.remove,
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
            onRemove: () => _removeEntry(context, strings, entry),
          );
        },
      ),
    );
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
    required this.onTap,
    required this.onRemove,
  });

  final LibraryEntry entry;
  final String statusText;
  final String notStartedText;
  final String removeText;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 148,
          child: Row(
            children: [
              SizedBox(
                width: 100,
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
                        entry.hasProgress ? entry.progressCode : notStartedText,
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
                itemBuilder: (_) => [
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
                ],
              ),
            ],
          ),
        ),
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
      placeholder: (_, _) => const ColoredBox(color: AppColors.surfaceLight),
      errorWidget: (_, _, _) => const ColoredBox(
        color: AppColors.surfaceLight,
        child: Icon(Icons.broken_image_outlined),
      ),
    );
  }
}
