import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/shows/domain/entities/tv_show.dart';

/// Resolve artwork from the saved movie identity, including older library rows
/// without an image URL. Never use a title search that can match another movie.
List<String> moviePosterUrls(int movieId, String? imageUrl) {
  final number = movieId - TvShow.movieIdOffset;
  if (number <= 0 || number > 9999999999) return const [];
  final imdb = 'tt${number.toString().padLeft(7, '0')}';
  final urls = <String>{};
  final source = Uri.tryParse(imageUrl?.trim() ?? '');
  if (source != null &&
      source.scheme == 'https' &&
      source.host.isNotEmpty &&
      source.userInfo.isEmpty) {
    if (['images.metahub.space', 'live.metahub.space'].contains(source.host)) {
      // Normalize provider thumbnails, and reject a mismatched saved identity.
      if (RegExp(
        '^/poster/(small|medium|large)/$imdb/img\$',
      ).hasMatch(source.path)) {
        urls.add(Uri.https(source.host, '/poster/medium/$imdb/img').toString());
      }
    } else {
      urls.add(source.toString());
    }
  }
  urls.add('https://images.metahub.space/poster/medium/$imdb/img');
  urls.add('https://live.metahub.space/poster/medium/$imdb/img');
  return urls.toList(growable: false);
}

class MovieArtwork extends StatelessWidget {
  const MovieArtwork({
    required this.movieId,
    this.imageUrl,
    this.shade = false,
    super.key,
  });
  final int movieId;
  final String? imageUrl;
  final bool shade;

  Widget _image(List<String> urls, int index) {
    if (index >= urls.length) return const MovieArtworkLogo();
    return CachedNetworkImage(
      key: ValueKey(urls[index]),
      imageUrl: urls[index],
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => const MovieArtworkLogo(),
      errorWidget: (_, _, _) => _image(urls, index + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = _image(moviePosterUrls(movieId, imageUrl), 0);
    if (!shade) return image;
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
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

class MovieArtworkLogo extends StatelessWidget {
  const MovieArtworkLogo({super.key});
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.surfaceLight,
    child: Center(
      child: FractionallySizedBox(
        widthFactor: 0.78,
        heightFactor: 0.78,
        child: Image.asset(
          'assets/branding/watchloom_icon.png',
          key: const ValueKey('movie-artwork-logo'),
          fit: BoxFit.contain,
          semanticLabel: 'Watchloom',
        ),
      ),
    ),
  );
}
