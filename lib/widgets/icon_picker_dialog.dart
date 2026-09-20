import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../utils/exercise_assets.dart';

class IconPickerDialog extends StatefulWidget {
  final String currentIconKey;

  const IconPickerDialog({super.key, required this.currentIconKey});

  static Future<String?> show(BuildContext context, String currentIconKey) {
    return showDialog<String>(
      context: context,
      builder: (_) => IconPickerDialog(currentIconKey: currentIconKey),
    );
  }

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  String _search = '';
  List<IconOption>? _options;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final options = await getAllIconOptions();
    if (mounted) setState(() => _options = options);
  }

  @override
  Widget build(BuildContext context) {
    final allOptions = _options ?? [];
    final filtered = filterIconOptions(allOptions, _search);

    return AlertDialog(
      title: const Text('Icon wählen'),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Suchen...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 8),
            if (_options == null)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (filtered.isEmpty)
              const Expanded(child: Center(child: Text('Keine Ergebnisse', style: TextStyle(color: AppTheme.muted))))
            else
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final option = filtered[i];
                    final isSelected = option.key == widget.currentIconKey;
                    return GestureDetector(
                      onTap: () => Navigator.pop(context, option.key),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
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
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  option.imagePath!,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.fitness_center,
                                    color: AppTheme.primary,
                                    size: 56,
                                  ),
                                ),
                              )
                            else
                              const Icon(
                                Icons.fitness_center,
                                color: AppTheme.primary,
                                size: 56,
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
          ],
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
