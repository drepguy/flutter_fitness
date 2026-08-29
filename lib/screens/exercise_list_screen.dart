import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column, Index;
import '../database/app_database.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/exercise_edit_dialog.dart';

class ExerciseListScreen extends StatefulWidget {
  final AppDatabase db;

  const ExerciseListScreen({super.key, required this.db});

  @override
  State<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen> {
  List<Gym> _gyms = [];
  int? _selectedGymId;
  String _search = '';
  List<_ExerciseWithAliases> _exercises = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final gyms = await widget.db.select(widget.db.gyms).get();
    await _loadExercises();
    setState(() => _gyms = gyms);
  }

  Future<void> _loadExercises() async {
    final query = widget.db.select(widget.db.exercises).join([
      leftOuterJoin(widget.db.exerciseAliases,
          widget.db.exerciseAliases.exerciseId.equalsExp(widget.db.exercises.id)),
    ]);

    if (_selectedGymId != null) {
      query.where(widget.db.exercises.gymId.equals(_selectedGymId!));
    }

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
    if (_selectedGymId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte zuerst ein Studio auswählen')),
        );
      }
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ExerciseEditDialog(
        db: widget.db,
        gymId: _selectedGymId!,
      ),
    );
    if (result == true) _loadExercises();
  }

  Future<void> _editExercise(Exercise ex) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ExerciseEditDialog(
        db: widget.db,
        exercise: ex,
        gymId: ex.gymId ?? _selectedGymId!,
      ),
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
      appBar: AppBar(title: const Text('Übungen verwalten')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DropdownButtonFormField<int?>(
              initialValue: _selectedGymId,
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Alle Studios')),
                for (final g in _gyms)
                  DropdownMenuItem(value: g.id, child: Text(g.name)),
              ],
              onChanged: (v) {
                setState(() => _selectedGymId = v);
                _loadExercises();
              },
            ),
          ),
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
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryContainer,
                      child: Text(
                        e.exercise.name.substring(0, 2).toUpperCase(),
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ),
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
