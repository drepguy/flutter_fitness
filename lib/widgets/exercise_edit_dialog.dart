import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column, Index;
import '../database/app_database.dart';
import '../utils/constants.dart';

class ExerciseEditDialog extends StatefulWidget {
  final AppDatabase db;
  final Exercise? exercise;
  final int gymId;

  const ExerciseEditDialog({
    super.key,
    required this.db,
    this.exercise,
    required this.gymId,
  });

  @override
  State<ExerciseEditDialog> createState() => _ExerciseEditDialogState();
}

class _ExerciseEditDialogState extends State<ExerciseEditDialog> {
  final _nameController = TextEditingController();
  String _category = 'Sonstiges';
  String _kind = 'free_weight';
  String _iconKey = 'dumbbell';
  final _aliasController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.exercise != null) {
      _nameController.text = widget.exercise!.name;
      _category = widget.exercise!.category;
      _kind = widget.exercise!.kind;
      _iconKey = widget.exercise!.iconKey;
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
              gymId: Value(widget.gymId),
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
              onChanged: (v) => setState(() => _category = v!),
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
            DropdownButtonFormField<String>(
              initialValue: _iconKey,
              decoration: const InputDecoration(labelText: 'Icon'),
              items: iconLabels.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _iconKey = v!),
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
