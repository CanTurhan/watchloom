import 'package:flutter/material.dart';
import 'package:watchloom/core/theme/app_colors.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({required this.title, required this.body, super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          child: Text(
            body,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.65,
            ),
          ),
        ),
      ),
    );
  }
}
