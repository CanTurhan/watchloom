import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:watchloom/core/localization/app_library_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';

class LibraryShowMetadata extends StatefulWidget {
  const LibraryShowMetadata({required this.entry, super.key});

  final LibraryEntry entry;

  @override
  State<LibraryShowMetadata> createState() {
    return _LibraryShowMetadataState();
  }
}

class _LibraryShowMetadataState extends State<LibraryShowMetadata> {
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
  void didUpdateWidget(covariant LibraryShowMetadata oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.entry.showId != widget.entry.showId) {
      _future = _loadMetadata();
    }
  }

  Future<_ShowMetadata> _loadMetadata() {
    return _cache.putIfAbsent(widget.entry.showId, () async {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '/shows/${widget.entry.showId}',
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

        platform ??= widget.entry.channelName;

        final releaseDate =
            data['premiered']?.toString() ?? widget.entry.premiered;

        final castNames = <String>[];

        final embedded = data['_embedded'];

        if (embedded is Map) {
          final cast = embedded['cast'];

          if (cast is List) {
            for (final castItem in cast) {
              if (castItem is! Map) {
                continue;
              }

              final person = castItem['person'];

              if (person is! Map) {
                continue;
              }

              final name = person['name']?.toString();

              if (name == null ||
                  name.trim().isEmpty ||
                  castNames.contains(name)) {
                continue;
              }

              castNames.add(name.trim());

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
          platform: widget.entry.channelName,
          releaseDate: widget.entry.premiered,
          castNames: const [],
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return FutureBuilder<_ShowMetadata>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Container(
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final metadata = snapshot.data;

        final platform = metadata?.platform?.trim();

        final releaseDate = metadata?.releaseDate?.trim();

        final castNames = metadata?.castNames ?? const <String>[];

        return Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 18,
                runSpacing: 9,
                children: [
                  _MetadataItem(
                    icon: Icons.tv_rounded,
                    label: strings.platformLabel,
                    value: platform?.isNotEmpty == true ? platform! : '—',
                  ),
                  _MetadataItem(
                    icon: Icons.calendar_today_rounded,
                    label: strings.releaseLabel,
                    value: releaseDate?.isNotEmpty == true ? releaseDate! : '—',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.groups_2_rounded,
                    color: AppColors.accentSoft,
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${strings.castLabel}: '
                      '${castNames.isEmpty ? '—' : castNames.join(', ')}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetadataItem extends StatelessWidget {
  const _MetadataItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.accentSoft, size: 16),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ),
      ],
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
