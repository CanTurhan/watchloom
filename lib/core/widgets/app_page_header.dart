import 'package:flutter/material.dart';
import 'package:watchloom/core/theme/app_colors.dart';

/// Consistent page rhythm, with text allowed to grow for accessibility.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.action,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (eyebrow != null) ...[
        Text(
          eyebrow!,
          style: const TextStyle(
            color: AppColors.accentSoft,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 9),
      ],
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          if (action != null) ...[const SizedBox(width: 12), action!],
        ],
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 9),
        Text(
          subtitle!,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    ],
  );
}

class AppSectionHeading extends StatelessWidget {
  const AppSectionHeading(this.title, {this.action, super.key});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null) ...[const SizedBox(width: 8), action!],
      ],
    ),
  );
}
