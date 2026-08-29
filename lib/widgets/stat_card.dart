import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: AppTheme.muted, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
