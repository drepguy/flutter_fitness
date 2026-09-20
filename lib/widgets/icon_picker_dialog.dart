import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../utils/exercise_assets.dart';

class IconPickerDialog extends StatelessWidget {
  final String currentIconKey;

  const IconPickerDialog({super.key, required this.currentIconKey});

  static Future<String?> show(BuildContext context, String currentIconKey) {
    return showDialog<String>(
      context: context,
      builder: (_) => IconPickerDialog(currentIconKey: currentIconKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Icon wählen'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: allIconOptions.length,
          itemBuilder: (context, i) {
            final option = allIconOptions[i];
            final isSelected = option.key == currentIconKey;
            return GestureDetector(
              onTap: () => Navigator.pop(context, option.key),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (option.imagePath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          option.imagePath!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            iconData[option.key] ?? Icons.fitness_center,
                            color: AppTheme.primary,
                            size: 28,
                          ),
                        ),
                      )
                    else
                      Icon(
                        iconData[option.key] ?? Icons.fitness_center,
                        color: AppTheme.primary,
                        size: 28,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      option.label,
                      style: const TextStyle(fontSize: 9, color: AppTheme.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
      ],
    );
  }
}
