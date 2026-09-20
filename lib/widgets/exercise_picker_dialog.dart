import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column, Index;
import '../database/app_database.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../utils/exercise_assets.dart';

class ExercisePickerDialog extends StatefulWidget {
  final AppDatabase db;
  final Exercise? suggestedExercise;

  const ExercisePickerDialog({
    super.key,
    required this.db,
    this.suggestedExercise,
  });

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
      leftOuterJoin(
          widget.db.exerciseAliases,
          widget.db.exerciseAliases.exerciseId
              .equalsExp(widget.db.exercises.id)),
    ]);

    if (_search.isNotEmpty) {
      query.where(widget.db.exercises.name.like('%$_search%') |
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
    final suggested = widget.suggestedExercise;

    return AlertDialog(
      title: const Text('Übung auswählen'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            if (suggested != null && _search.isEmpty) ...[
              ListTile(
                leading: const Icon(Icons.auto_awesome,
                    color: AppTheme.primary, size: 20),
                title: Text(suggested.name),
                subtitle: Text('Empfohlen',
                    style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                tileColor: AppTheme.primaryContainer.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                onTap: () => Navigator.pop(context, suggested),
              ),
              const SizedBox(height: 4),
            ],
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
                  final isSuggested =
                      suggested != null && e.exercise.id == suggested.id;
                  return ListTile(
                    leading: _buildExerciseIcon(e.exercise),
                    title: Text(e.exercise.name),
                    subtitle: Text(e.exercise.category,
                        style: const TextStyle(
                            color: AppTheme.muted, fontSize: 12)),
                    tileColor:
                        isSuggested ? AppTheme.primaryContainer.withValues(alpha: 0.3) : null,
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

  Widget _buildExerciseIcon(Exercise exercise) {
    final imagePath = getIconAsset(exercise.iconKey) ?? getExerciseImage(exercise.name);
    if (imagePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          imagePath,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackIcon(exercise),
        ),
      );
    }
    return _buildFallbackIcon(exercise);
  }

  Widget _buildFallbackIcon(Exercise exercise) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData[exercise.iconKey] ?? Icons.fitness_center,
        color: AppTheme.primary,
        size: 22,
      ),
    );
  }
}

class _ExerciseWithAlias {
  final Exercise exercise;
  final List<String> aliases = [];

  _ExerciseWithAlias({required this.exercise});
}
