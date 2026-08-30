import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PRCard extends StatelessWidget {
  final String title;
  final String value;
  final String date;

  const PRCard({
    super.key,
    required this.title,
    required this.value,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: AppTheme.gold, width: 3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.emoji_events, size: 16, color: AppTheme.gold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            color: AppTheme.muted, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 2),
              Text(date,
                  style: const TextStyle(
                      color: AppTheme.muted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
