import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchloom/core/localization/app_strings.dart';

int? trailerAge(String? rating) {
  final value = rating?.trim().toUpperCase();
  if (value == null || value.isEmpty) return null;
  if (['R', 'NC-17', 'TV-MA', '18', '18+', '+18'].contains(value)) return 18;
  if (['PG-13', '13', '13+', '+13'].contains(value)) return 13;
  if (value == 'TV-14') return 14;
  final numeric = int.tryParse(value.replaceAll('+', ''));
  if (numeric != null && numeric >= 13) return numeric;
  if (['G', 'PG', 'TV-G', 'TV-PG', 'U'].contains(value)) return 0;
  return null;
}

class TrailerButton extends StatelessWidget {
  const TrailerButton({required this.url, this.rating, super.key});
  final String url;
  final String? rating;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final age = trailerAge(rating);
    return OutlinedButton.icon(
      icon: const Icon(Icons.play_circle_outline),
      label: Text(
        '${strings.value(en: 'Watch trailer', tr: 'Fragmanı izle')}${age != null && age > 0 ? ' · $age+' : ''}',
      ),
      onPressed: () async {
        final uri = Uri.tryParse(url);
        if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;
        if (age == null || age > 0) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                age == null
                    ? strings.value(
                        en: 'Age rating unavailable',
                        tr: 'Yaş sınıflandırması bilinmiyor',
                      )
                    : '$age+',
              ),
              content: Text(
                age == null
                    ? strings.value(
                        en: 'This trailer may contain mature content. Continue?',
                        tr: 'Bu fragman yetişkin içerik barındırabilir. Devam edilsin mi?',
                      )
                    : strings.value(
                        en: 'This title is rated $age+. Continue to the trailer?',
                        tr: 'Bu yapım $age+ olarak sınıflandırılmıştır. Fragman açılsın mı?',
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(strings.value(en: 'Cancel', tr: 'Vazgeç')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(strings.value(en: 'Continue', tr: 'Devam et')),
                ),
              ],
            ),
          );
          if (confirmed != true || !context.mounted) return;
        }
        try {
          final opened = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (!opened) throw StateError('trailer-unavailable');
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  strings.value(
                    en: 'Trailer could not be opened.',
                    tr: 'Fragman açılamadı.',
                  ),
                ),
              ),
            );
          }
        }
      },
    );
  }
}
