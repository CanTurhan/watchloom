import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:watchloom/app/app_scope.dart';
import 'package:watchloom/core/localization/app_library_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';
import 'package:watchloom/features/shows/domain/entities/tv_show.dart';

class ShowDetailPersonalPanel extends StatelessWidget {
  const ShowDetailPersonalPanel({required this.show, super.key});

  final TvShow show;

  @override
  Widget build(BuildContext context) {
    final libraryController = AppScope.of(context).libraryController;

    return ListenableBuilder(
      listenable: libraryController,
      builder: (context, child) {
        final strings = AppStrings.of(context);

        final entry = libraryController.findByShowId(show.id);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ShowDetailMetadataCard(show: show),
            const SizedBox(height: 14),
            if (entry == null)
              _LibraryRequiredCard(text: strings.personalFeaturesRequireLibrary)
            else ...[
              _PersonalActionRow(
                entry: entry,
                favoriteText: entry.isFavorite
                    ? strings.removeFromFavorites
                    : strings.addToFavorites,
                noteText: entry.hasPersonalNote
                    ? strings.editPersonalNote
                    : strings.addPersonalNote,
                onFavorite: () {
                  _toggleFavorite(context, entry);
                },
                onNote: () {
                  _editPersonalNote(context, entry);
                },
              ),
              if (entry.hasPersonalNote) ...[
                const SizedBox(height: 12),
                _PersonalNoteCard(
                  note: entry.personalNote,
                  editText: strings.editPersonalNote,
                  removeText: strings.removePersonalNote,
                  onEdit: () {
                    _editPersonalNote(context, entry);
                  },
                  onRemove: () {
                    _removePersonalNote(context, entry);
                  },
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  Future<void> _toggleFavorite(BuildContext context, LibraryEntry entry) async {
    final strings = AppStrings.of(context);
    final controller = AppScope.of(context).libraryController;

    final wasFavorite = entry.isFavorite;

    await controller.toggleFavorite(entry.showId);

    if (!context.mounted) {
      return;
    }

    _showMessage(
      context,
      wasFavorite ? strings.removedFromFavorites : strings.addedToFavorites,
      icon: wasFavorite
          ? Icons.favorite_border_rounded
          : Icons.favorite_rounded,
    );
  }

  Future<void> _editPersonalNote(
    BuildContext context,
    LibraryEntry entry,
  ) async {
    final strings = AppStrings.of(context);
    final controller = AppScope.of(context).libraryController;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _ShowPersonalNoteDialog(
          initialNote: entry.personalNote,
          title: entry.hasPersonalNote
              ? strings.editPersonalNote
              : strings.addPersonalNote,
          hintText: strings.personalNoteHint,
          cancelText: strings.cancel,
          saveText: strings.save,
          onSave: (note) {
            return controller.updatePersonalNote(
              showId: entry.showId,
              note: note,
            );
          },
        );
      },
    );

    if (saved != true || !context.mounted) {
      return;
    }

    _showMessage(
      context,
      strings.personalNoteSaved,
      icon: Icons.note_alt_rounded,
    );
  }

  Future<void> _removePersonalNote(
    BuildContext context,
    LibraryEntry entry,
  ) async {
    final strings = AppStrings.of(context);
    final controller = AppScope.of(context).libraryController;

    await controller.updatePersonalNote(showId: entry.showId, note: '');

    if (!context.mounted) {
      return;
    }

    _showMessage(
      context,
      strings.personalNoteRemoved,
      icon: Icons.delete_outline_rounded,
    );
  }

  void _showMessage(
    BuildContext context,
    String message, {
    required IconData icon,
  }) {
    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: AppColors.accentSoft),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _ShowDetailMetadataCard extends StatefulWidget {
  const _ShowDetailMetadataCard({required this.show});

  final TvShow show;

  @override
  State<_ShowDetailMetadataCard> createState() {
    return _ShowDetailMetadataCardState();
  }
}

class _ShowDetailMetadataCardState extends State<_ShowDetailMetadataCard> {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.tvmaze.com',
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  static final Map<int, Future<_ShowMetadata>> _cache = {};

  late Future<_ShowMetadata> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadMetadata();
  }

  @override
  void didUpdateWidget(covariant _ShowDetailMetadataCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.show.id != widget.show.id) {
      _future = _loadMetadata();
    }
  }

  Future<_ShowMetadata> _loadMetadata() {
    return _cache.putIfAbsent(widget.show.id, () async {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '/shows/${widget.show.id}',
          queryParameters: const {'embed': 'cast'},
        );

        final data = response.data ?? const <String, dynamic>{};

        String? platform;

        final webChannel = data['webChannel'];

        if (webChannel is Map) {
          platform = webChannel['name']?.toString();
        }

        final network = data['network'];

        if ((platform == null || platform.trim().isEmpty) && network is Map) {
          platform = network['name']?.toString();
        }

        platform ??= widget.show.channelName;

        final releaseDate =
            data['premiered']?.toString() ?? widget.show.premiered;

        final castNames = <String>[];

        final embedded = data['_embedded'];

        if (embedded is Map) {
          final cast = embedded['cast'];

          if (cast is List) {
            for (final rawCast in cast) {
              if (rawCast is! Map) {
                continue;
              }

              final person = rawCast['person'];

              if (person is! Map) {
                continue;
              }

              final name = person['name']?.toString().trim();

              if (name == null || name.isEmpty || castNames.contains(name)) {
                continue;
              }

              castNames.add(name);

              if (castNames.length == 3) {
                break;
              }
            }
          }
        }

        return _ShowMetadata(
          platform: platform,
          releaseDate: releaseDate,
          castNames: castNames,
        );
      } catch (_) {
        return _ShowMetadata(
          platform: widget.show.channelName,
          releaseDate: widget.show.premiered,
          castNames: const [],
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.18)),
      ),
      child: FutureBuilder<_ShowMetadata>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const SizedBox(
              height: 130,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final metadata = snapshot.data;

          final platform = metadata?.platform?.trim();

          final releaseDate = _formatReleaseDate(
            context,
            metadata?.releaseDate,
          );

          final castNames = metadata?.castNames ?? const <String>[];

          return Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.accentSoft,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        strings.showInformation,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                Row(
                  children: [
                    Expanded(
                      child: _MetadataValue(
                        icon: Icons.tv_rounded,
                        label: strings.platformLabel,
                        value: platform?.isNotEmpty == true ? platform! : '—',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetadataValue(
                        icon: Icons.calendar_today_rounded,
                        label: strings.releaseLabel,
                        value: releaseDate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.groups_2_rounded,
                      color: AppColors.accentSoft,
                      size: 19,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '${strings.castLabel}: '
                        '${castNames.isEmpty ? '—' : castNames.join(', ')}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatReleaseDate(BuildContext context, String? value) {
    if (value == null || value.trim().isEmpty) {
      return '—';
    }

    final parsed = DateTime.tryParse(value);

    if (parsed == null) {
      return value;
    }

    return MaterialLocalizations.of(context).formatMediumDate(parsed);
  }
}

class _MetadataValue extends StatelessWidget {
  const _MetadataValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.accentSoft),
          const SizedBox(height: 9),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PersonalActionRow extends StatelessWidget {
  const _PersonalActionRow({
    required this.entry,
    required this.favoriteText,
    required this.noteText,
    required this.onFavorite,
    required this.onNote,
  });

  final LibraryEntry entry;
  final String favoriteText;
  final String noteText;
  final VoidCallback onFavorite;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onFavorite,
            icon: Icon(
              entry.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: entry.isFavorite ? AppColors.accentSoft : null,
            ),
            label: Text(
              favoriteText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onNote,
            icon: Icon(
              entry.hasPersonalNote
                  ? Icons.note_alt_rounded
                  : Icons.note_add_outlined,
              color: entry.hasPersonalNote ? AppColors.accentSoft : null,
            ),
            label: Text(noteText, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}

class _PersonalNoteCard extends StatelessWidget {
  const _PersonalNoteCard({
    required this.note,
    required this.editText,
    required this.removeText,
    required this.onEdit,
    required this.onRemove,
  });

  final String note;
  final String editText;
  final String removeText;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.note_alt_rounded,
                size: 20,
                color: AppColors.accentSoft,
              ),
              SizedBox(width: 9),
              Text(
                'Personal Note',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            note,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: Text(editText),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                label: Text(removeText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LibraryRequiredCard extends StatelessWidget {
  const _LibraryRequiredCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.video_library_outlined,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowPersonalNoteDialog extends StatefulWidget {
  const _ShowPersonalNoteDialog({
    required this.initialNote,
    required this.title,
    required this.hintText,
    required this.cancelText,
    required this.saveText,
    required this.onSave,
  });

  final String initialNote;
  final String title;
  final String hintText;
  final String cancelText;
  final String saveText;
  final Future<void> Function(String note) onSave;

  @override
  State<_ShowPersonalNoteDialog> createState() {
    return _ShowPersonalNoteDialogState();
  }
}

class _ShowPersonalNoteDialogState extends State<_ShowPersonalNoteDialog> {
  late final TextEditingController _controller;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.onSave(_controller.text.trim());

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _controller,
          autofocus: true,
          enabled: !_saving,
          minLines: 3,
          maxLines: 7,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving
                ? null
                : () {
                    Navigator.of(context).pop(false);
                  },
            child: Text(widget.cancelText),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.saveText),
          ),
        ],
      ),
    );
  }
}

class _ShowMetadata {
  const _ShowMetadata({
    required this.platform,
    required this.releaseDate,
    required this.castNames,
  });

  final String? platform;
  final String? releaseDate;
  final List<String> castNames;
}
