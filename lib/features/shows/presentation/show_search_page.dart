import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:watchloom/core/localization/app_show_strings.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/shows/domain/entities/tv_show.dart';
import 'package:watchloom/features/shows/domain/repositories/show_repository.dart';
import 'package:watchloom/features/shows/presentation/show_detail_page.dart';

class ShowSearchPage extends StatefulWidget {
  const ShowSearchPage({
    required this.showRepository,
    this.autofocus = false,
    super.key,
  });

  final ShowRepository showRepository;
  final bool autofocus;

  @override
  State<ShowSearchPage> createState() => _ShowSearchPageState();
}

class _ShowSearchPageState extends State<ShowSearchPage> {
  final TextEditingController _controller = TextEditingController();

  Timer? _debounce;
  List<TvShow> _results = const [];
  ShowFailure? _failure;

  bool _isLoading = false;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();

    final query = value.trim();

    if (query.length < 2) {
      _requestId++;

      setState(() {
        _results = const [];
        _failure = null;
        _isLoading = false;
      });

      return;
    }

    _debounce = Timer(const Duration(milliseconds: 450), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String rawQuery) async {
    final query = rawQuery.trim();

    if (query.length < 2) {
      return;
    }

    final currentRequestId = ++_requestId;

    setState(() {
      _isLoading = true;
      _failure = null;
    });

    try {
      final results = await widget.showRepository.searchShows(query);

      if (!mounted || currentRequestId != _requestId) {
        return;
      }

      setState(() {
        _results = results;
        _isLoading = false;
      });
    } on ShowFailure catch (failure) {
      if (!mounted || currentRequestId != _requestId) {
        return;
      }

      setState(() {
        _failure = failure;
        _results = const [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.searchShows)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _controller,
                autofocus: widget.autofocus,
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                onSubmitted: (value) {
                  _debounce?.cancel();
                  _runSearch(value);
                },
                decoration: InputDecoration(
                  hintText: strings.searchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).deleteButtonTooltip,
                          onPressed: () {
                            _controller.clear();
                            _onQueryChanged('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
            ),
            if (_isLoading) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _buildContent(strings)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppStrings strings) {
    if (_failure != null) {
      return _ErrorState(
        message: _failureMessage(strings, _failure!.type),
        retryText: strings.retry,
        onRetry: () {
          _runSearch(_controller.text);
        },
      );
    }

    final query = _controller.text.trim();

    if (query.length < 2) {
      return _MessageState(
        icon: Icons.manage_search_rounded,
        title: strings.searchIntro,
        description: strings.minimumTwoCharacters,
      );
    }

    if (!_isLoading && _results.isEmpty) {
      return _MessageState(
        icon: Icons.tv_off_rounded,
        title: strings.noShowsFound,
        description: strings.tryAnotherSearch,
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final show = _results[index];

        return _ShowResultCard(
          show: show,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ShowDetailPage(
                  showRepository: widget.showRepository,
                  initialShow: show,
                ),
              ),
            );
          },
        );
      },
    );
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
}

class _ShowResultCard extends StatelessWidget {
  const _ShowResultCard({required this.show, required this.onTap});

  final TvShow show;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      if (show.premiereYear != null) show.premiereYear!,
      if (show.genres.isNotEmpty) show.genres.take(2).join(' • '),
      if (show.channelName != null) show.channelName!,
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 142,
          child: Row(
            children: [
              Hero(
                tag: 'show-${show.id}',
                child: SizedBox(
                  width: 96,
                  height: double.infinity,
                  child: _PosterImage(imageUrl: show.imageMedium),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              show.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (show.ratingAverage != null) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.star_rounded,
                              color: AppColors.yellow,
                              size: 16,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              show.ratingAverage!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (metadata.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          metadata.join('  ·  '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          show.summary.isEmpty
                              ? AppStrings.of(context).noSummary
                              : show.summary,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFC7C8D0),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;

    if (url == null) {
      return const ColoredBox(
        color: AppColors.surfaceLight,
        child: Center(
          child: Icon(
            Icons.live_tv_rounded,
            color: AppColors.textSecondary,
            size: 34,
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => const ColoredBox(
        color: AppColors.surfaceLight,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, _, _) => const ColoredBox(
        color: AppColors.surfaceLight,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(icon, color: AppColors.accentSoft, size: 42),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.retryText,
    required this.onRetry,
  });

  final String message;
  final String retryText;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.accentSoft,
              size: 54,
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(retryText),
            ),
          ],
        ),
      ),
    );
  }
}
