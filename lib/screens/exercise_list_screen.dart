import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column, Index;
import '../database/app_database.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../utils/exercise_assets.dart';
import '../widgets/exercise_edit_dialog.dart';

class ExerciseListScreen extends StatefulWidget {
  final AppDatabase db;

  const ExerciseListScreen({super.key, required this.db});

  @override
  State<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen> {
  String _search = '';
  List<_ExerciseWithAliases> _exercises = [];

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
    final map = <int, _ExerciseWithAliases>{};
    for (final row in results) {
      final ex = row.readTableOrNull(widget.db.exercises);
      final alias = row.readTableOrNull(widget.db.exerciseAliases);
      if (ex == null) continue;
      map.putIfAbsent(ex.id, () => _ExerciseWithAliases(exercise: ex, aliases: []));
      if (alias != null) {
        map[ex.id]!.aliases.add(alias);
      }
    }

    setState(() => _exercises = map.values.toList()
      ..sort((a, b) => a.exercise.name.compareTo(b.exercise.name)));
  }

  Future<void> _addExercise() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ExerciseEditDialog(db: widget.db),
    );
    if (result == true) _loadExercises();
  }

  Future<void> _editExercise(Exercise ex) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ExerciseEditDialog(db: widget.db, exercise: ex),
    );
    if (result == true) _loadExercises();
  }

  Future<void> _deleteExercise(Exercise ex) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Übung löschen?'),
        content: Text('"${ex.name}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await (widget.db.delete(widget.db.exercises)
            ..where((e) => e.id.equals(ex.id)))
          .go();
      _loadExercises();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Übungen')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Suchen...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) {
                setState(() => _search = v);
                _loadExercises();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_exercises.length} Übungen',
                style: const TextStyle(color: AppTheme.muted),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _exercises.length,
              itemBuilder: (context, i) {
                final e = _exercises[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: _ExerciseThumbnail(exerciseName: e.exercise.name, iconKey: e.exercise.iconKey),
                    title: Text(e.exercise.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.exercise.category,
                            style: const TextStyle(
                                color: AppTheme.muted, fontSize: 12)),
                        Text(
                          exerciseKindLabels[e.exercise.kind] ?? e.exercise.kind,
                          style: const TextStyle(
                              color: AppTheme.primary, fontSize: 12),
                        ),
                        if (e.aliases.isNotEmpty)
                          Text(
                            'Aliases: ${e.aliases.map((a) => a.alias).join(', ')}',
                            style: const TextStyle(
                                color: AppTheme.muted, fontSize: 11),
                          ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editExercise(e.exercise),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 20, color: AppTheme.error),
                          onPressed: () => _deleteExercise(e.exercise),
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceContainerHigh,
        ),
        child: OutlinedButton.icon(
          onPressed: _addExercise,
          icon: const Icon(Icons.add),
          label: const Text('Neue Übung'),
        ),
      ),
    );
  }
}

class _ExerciseWithAliases {
  final Exercise exercise;
  final List<ExerciseAliase> aliases;

  _ExerciseWithAliases({required this.exercise, required this.aliases});
}

class _ExerciseThumbnail extends StatelessWidget {
  final String exerciseName;
  final String iconKey;

  const _ExerciseThumbnail({required this.exerciseName, required this.iconKey});

  @override
  Widget build(BuildContext context) {
    final imagePath = getExerciseImage(exerciseName);
    if (imagePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          imagePath,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(),
        ),
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        iconData[iconKey] ?? Icons.fitness_center,
        color: AppTheme.primary,
        size: 26,
      ),
    );
  }
}
