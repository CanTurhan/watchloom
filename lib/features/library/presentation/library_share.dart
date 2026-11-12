import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/localization/app_library_strings.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';

String libraryShareText(
  Iterable<LibraryEntry> entries,
  AppStrings strings, {
  required bool wishlist,
}) {
  final title = wishlist
      ? strings.value(
          en: 'My Watchloom watchlist',
          tr: 'Watchloom izleme listem',
        )
      : strings.value(en: 'My Watchloom library', tr: 'Watchloom kütüphanem');
  final lines = entries
      .map((entry) {
        final url = Uri.tryParse(entry.tvMazeUrl ?? '');
        return '• ${entry.name} — ${strings.statusName(entry.status)}'
            '${entry.progressCode.isEmpty ? '' : ' · ${entry.progressCode}'}'
            '${url != null && url.scheme == 'https' ? '\n$url' : ''}';
      })
      .join('\n\n');
  // Personal notes, account details and backup contents are never shared.
  return '$title\n\n$lines\n\nWatchloom'
      '${entries.any((e) => !e.isMovie) ? '\nSeries metadata: TVMaze · CC BY-SA 4.0 · https://www.tvmaze.com' : ''}'
      '${entries.any((e) => e.isMovie) ? '\nMovie metadata: Cinemeta · https://www.stremio.com' : ''}';
}

Future<void> shareLibrary(
  BuildContext context,
  List<LibraryEntry> entries, {
  required bool wishlist,
}) async {
  final strings = AppStrings.of(context);
  final selected = entries
      .where((e) => !wishlist || e.status == LibraryStatus.watchlist)
      .toList();
  if (selected.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          strings.value(en: 'This list is empty.', tr: 'Bu liste boş.'),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    return;
  }
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: libraryShareText(selected, strings, wishlist: wishlist),
        sharePositionOrigin: origin,
      ),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.value(
              en: 'Sharing failed. Please try again.',
              tr: 'Paylaşılamadı. Lütfen tekrar deneyin.',
            ),
          ),
        ),
      );
    }
  }
}
