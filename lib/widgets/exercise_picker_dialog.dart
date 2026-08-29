import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column, Index;
import '../database/app_database.dart';
import '../theme/app_theme.dart';

class ExercisePickerDialog extends StatefulWidget {
  final AppDatabase db;

  const ExercisePickerDialog({super.key, required this.db});

  @override
  State<ExercisePickerDialog> createState() => _ExercisePickerDialogState();
}

class _ExercisePickerDialogState extends State<ExercisePickerDialog> {
  String _search = '';
  List<_ExerciseWithAlias> _exercises = [];

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final query = widget.db.select(widget.db.exercises).join([
      leftOuterJoin(widget.db.exerciseAliases,
          widget.db.exerciseAliases.exerciseId.equalsExp(widget.db.exercises.id)),
    ]);

    if (_search.isNotEmpty) {
      query.where(
          widget.db.exercises.name.like('%$_search%') |
          widget.db.exerciseAliases.alias.like('%$_search%'));
    }

    final results = await query.get();
    final map = <int, _ExerciseWithAlias>{};
    for (final row in results) {
      final ex = row.readTableOrNull(widget.db.exercises);
      final alias = row.readTableOrNull(widget.db.exerciseAliases);
      if (ex == null) continue;
      map.putIfAbsent(ex.id, () => _ExerciseWithAlias(exercise: ex));
      if (alias != null) {
        map[ex.id]!.aliases.add(alias.alias);
      }
    }

    setState(() => _exercises = map.values.toList()
      ..sort((a, b) => a.exercise.name.compareTo(b.exercise.name)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Übung auswählen'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Suchen...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) {
                setState(() => _search = v);
                _loadExercises();
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _exercises.length,
                itemBuilder: (context, i) {
                  final e = _exercises[i];
                  return ListTile(
                    title: Text(e.exercise.name),
                    subtitle: Text(e.exercise.category,
                        style: const TextStyle(
                            color: AppTheme.muted, fontSize: 12)),
                    onTap: () => Navigator.pop(context, e.exercise),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseWithAlias {
  final Exercise exercise;
  final List<String> aliases = [];

  _ExerciseWithAlias({required this.exercise});
}
