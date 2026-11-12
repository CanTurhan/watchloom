import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/core/widgets/movie_artwork.dart';
import 'package:watchloom/features/shows/domain/entities/tv_show.dart';

void main() {
  const movieId = TvShow.movieIdOffset + 1375666;

  test(
    'old saved movies resolve posters by exact IMDb identity without a database edit',
    () {
      expect(moviePosterUrls(movieId, null), [
        'https://images.metahub.space/poster/medium/tt1375666/img',
        'https://live.metahub.space/poster/medium/tt1375666/img',
      ]);
      expect(
        moviePosterUrls(
          movieId,
          'https://images.metahub.space/poster/small/tt1375666/img',
        ),
        moviePosterUrls(movieId, null),
      );
      expect(
        moviePosterUrls(
          movieId,
          'https://images.metahub.space/poster/small/tt0000001/img',
        ),
        moviePosterUrls(movieId, null),
      );
      expect(moviePosterUrls(169, null), isEmpty);
      expect(
        moviePosterUrls(movieId, 'http://unsafe.example/poster'),
        moviePosterUrls(movieId, null),
      );
    },
  );

  test(
    'catalog supplied HTTPS poster is preserved ahead of provider alternatives',
    () {
      final urls = moviePosterUrls(
        movieId,
        'https://image.tmdb.org/t/p/w500/example.jpg',
      );
      expect(urls.first, 'https://image.tmdb.org/t/p/w500/example.jpg');
      expect(urls.length, 3);
    },
  );

  for (final size in [
    const Size(54, 72),
    const Size(96, 160),
    const Size(390, 365),
  ]) {
    testWidgets('logo fits ${size.width} x ${size.height} without cropping', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: size,
                child: const MovieArtworkLogo(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(
        find.byKey(const ValueKey('movie-artwork-logo')),
      );
      expect(image.fit, BoxFit.contain);
      expect(
        (image.image as AssetImage).assetName,
        'assets/branding/watchloom_icon.png',
      );
      final bounds = tester.getSize(find.byType(MovieArtworkLogo));
      expect(bounds, size);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('loading and exhausted image sources both show bundled logo', (
    tester,
  ) async {
    const artwork = MovieArtwork(movieId: movieId);
    // Inspect the real image callbacks without external networking or plugins.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final context = tester.element(find.byType(Scaffold));
    final widget = artwork.build(context) as CachedNetworkImage;
    expect(widget.fit, BoxFit.cover);
    final loading = widget.placeholder!(context, widget.imageUrl);
    expect(loading, isA<MovieArtworkLogo>());
    final alternate =
        widget.errorWidget!(
              context,
              widget.imageUrl,
              StateError('TLS unavailable'),
            )
            as CachedNetworkImage;
    expect(alternate.imageUrl, contains('live.metahub.space'));
    final fallback = alternate.errorWidget!(
      context,
      alternate.imageUrl,
      StateError('TLS unavailable'),
    );
    expect(fallback, isA<MovieArtworkLogo>());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SizedBox(width: 96, height: 144, child: fallback)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('movie-artwork-logo')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
