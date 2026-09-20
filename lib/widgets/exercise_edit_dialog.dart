import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column, Index;
import '../database/app_database.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../utils/exercise_assets.dart';
import 'icon_picker_dialog.dart';

class ExerciseEditDialog extends StatefulWidget {
  final AppDatabase db;
  final Exercise? exercise;

  const ExerciseEditDialog({
    super.key,
    required this.db,
    this.exercise,
  });

  @override
  State<ExerciseEditDialog> createState() => _ExerciseEditDialogState();
}

class _ExerciseEditDialogState extends State<ExerciseEditDialog> {
  final _nameController = TextEditingController();
  String _category = 'Sonstiges';
  String _kind = 'free_weight';
  String _iconKey = 'dumbbell';
  bool _iconManuallySet = false;
  final _aliasController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.exercise != null) {
      _nameController.text = widget.exercise!.name;
      _category = widget.exercise!.category;
      _kind = widget.exercise!.kind;
      _iconKey = widget.exercise!.iconKey;
      _iconManuallySet = true;
      _loadAliases();
    }
  }

  Future<void> _loadAliases() async {
    final aliases = await (widget.db.select(widget.db.exerciseAliases)
          ..where((a) => a.exerciseId.equals(widget.exercise!.id)))
        .get();
    _aliasController.text = aliases.map((a) => a.alias).join(', ');
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;

    final now = DateTime.now();
    if (widget.exercise != null) {
      await (widget.db.update(widget.db.exercises)
            ..where((e) => e.id.equals(widget.exercise!.id)))
          .write(ExercisesCompanion(
        name: Value(_nameController.text.trim()),
        category: Value(_category),
        kind: Value(_kind),
        iconKey: Value(_iconKey),
      ));
      await _syncAliases(widget.exercise!.id);
    } else {
      final id = await widget.db.into(widget.db.exercises).insert(
            ExercisesCompanion.insert(
              name: _nameController.text.trim(),
              category: Value(_category),
              kind: Value(_kind),
              iconKey: Value(_iconKey),
              createdAt: now,
            ),
          );
      await _syncAliases(id);
    }

    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _syncAliases(int exerciseId) async {
    final newAliases = _aliasController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final existing = await (widget.db.select(widget.db.exerciseAliases)
          ..where((a) => a.exerciseId.equals(exerciseId)))
        .get();

    final existingStrings = existing.map((a) => a.alias).toSet();

    for (final alias in newAliases) {
      if (!existingStrings.contains(alias)) {
        await widget.db.into(widget.db.exerciseAliases).insert(
              ExerciseAliasesCompanion.insert(
                exerciseId: exerciseId,
                alias: alias,
                createdAt: DateTime.now(),
              ),
            );
      }
    }

    for (final old in existing) {
      if (!newAliases.contains(old.alias)) {
        await (widget.db.delete(widget.db.exerciseAliases)
              ..where((a) => a.id.equals(old.id)))
            .go();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.exercise != null ? 'Übung bearbeiten' : 'Neue Übung'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name *'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Kategorie'),
              items: exerciseCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _category = v!;
                  if (!_iconManuallySet && _nameController.text.isNotEmpty) {
                    _iconKey = autoAssignIconKey(_nameController.text, _category);
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Art'),
              items: exerciseKindLabels.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _kind = v!),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final picked = await IconPickerDialog.show(context, _iconKey);
                if (picked != null) {
                  setState(() {
                    _iconKey = picked;
                    _iconManuallySet = true;
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Icon'),
                child: Row(
                  children: [
                    _CurrentIcon(iconKey: _iconKey, exerciseName: _nameController.text),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: AppTheme.muted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aliasController,
              decoration: const InputDecoration(
                labelText: 'Aliase (kommasepariert)',
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
        ElevatedButton(
          onPressed: _save,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

class _CurrentIcon extends StatelessWidget {
  final String iconKey;
  final String? exerciseName;

  const _CurrentIcon({required this.iconKey, this.exerciseName});

  @override
  Widget build(BuildContext context) {
    final imagePath = getIconAsset(iconKey) ?? (exerciseName != null ? getExerciseImage(exerciseName!) : null);
    if (imagePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          imagePath,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            iconData[iconKey] ?? Icons.fitness_center,
            size: 24,
            color: AppTheme.primary,
          ),
        ),
      );
    }
    return Icon(
      iconData[iconKey] ?? Icons.fitness_center,
      size: 24,
      color: AppTheme.primary,
    );
  }
}
