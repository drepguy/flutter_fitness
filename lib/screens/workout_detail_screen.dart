import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column, Index;
import '../database/app_database.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final AppDatabase db;
  final int workoutId;

  const WorkoutDetailScreen({super.key, required this.db, required this.workoutId});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  Workout? _workout;
  List<_DetailExercise> _exercises = [];
  bool _editing = false;
  bool _saving = false;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final workout = await (widget.db.select(widget.db.workouts)
          ..where((w) => w.id.equals(widget.workoutId)))
        .getSingleOrNull();
    if (workout == null) return;

    final wes = await (widget.db.select(widget.db.workoutExercises)
          ..where((we) => we.workoutId.equals(workout.id))
          ..orderBy([(we) => OrderingTerm.asc(we.orderIdx)]))
        .get();

    final exercises = <_DetailExercise>[];
    for (final we in wes) {
      final exercise = await (widget.db.select(widget.db.exercises)
            ..where((e) => e.id.equals(we.exerciseId)))
          .getSingle();
      final sets = await (widget.db.select(widget.db.workoutSets)
            ..where((s) => s.workoutExerciseId.equals(we.id))
            ..orderBy([(s) => OrderingTerm.asc(s.setNo)]))
          .get();
      exercises.add(_DetailExercise(we: we, exercise: exercise, sets: sets));
    }

    setState(() {
      _workout = workout;
      _exercises = exercises;
      _notesController.text = workout.notes ?? '';
    });
  }

  Gym? _gym;

  Future<Gym?> _getGym() async {
    if (_gym != null) return _gym;
    if (_workout?.gymId == null) return null;
    _gym = await (widget.db.select(widget.db.gyms)
          ..where((g) => g.id.equals(_workout!.gymId!)))
        .getSingleOrNull();
    return _gym;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await (widget.db.update(widget.db.workouts)
          ..where((w) => w.id.equals(widget.workoutId)))
        .write(WorkoutsCompanion(
      notes: Value(_notesController.text.isEmpty ? null : _notesController.text),
    ));
    setState(() {
      _saving = false;
      _editing = false;
    });
  }

  Future<void> _delete() async {
    await (widget.db.delete(widget.db.workoutSets)
          ..where((s) =>
              s.workoutExerciseId.isIn(_exercises.map((e) => e.we.id))))
        .go();
    await (widget.db.delete(widget.db.workoutExercises)
          ..where((we) => we.workoutId.equals(widget.workoutId)))
        .go();
    await (widget.db.delete(widget.db.workouts)
          ..where((w) => w.id.equals(widget.workoutId)))
        .go();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_workout == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Training bearbeiten' : 'Training ansehen'),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<Gym?>(
            future: _getGym(),
            builder: (context, snap) {
              final totalSets = _exercises.fold(0, (sum, e) => sum + e.sets.length);
              final totalVolume = _exercises.fold(0.0, (sum, e) {
                return sum + e.sets.fold(0.0, (s, set) => s + set.weightKg * set.reps);
              });
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryContainer,
                      AppTheme.surface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(snap.data?.name ?? 'Training',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            )),
                    const SizedBox(height: 8),
                    Text(
                      '${formatDateTime(_workout!.startedAt)}${_workout!.endedAt != null ? ' — ${formatDateTime(_workout!.endedAt!)}' : ''}',
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (_workout!.endedAt != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.gold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              formatDuration(
                                  _workout!.endedAt!.difference(_workout!.startedAt)),
                              style: const TextStyle(
                                  color: AppTheme.gold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ),
                        const SizedBox(width: 12),
                        _buildMiniStat(Icons.replay, '$totalSets Sätze'),
                        const SizedBox(width: 12),
                        _buildMiniStat(Icons.fitness_center, '${_exercises.length} Übungen'),
                        const SizedBox(width: 12),
                        _buildMiniStat(Icons.scale, '${formatVolume(totalVolume)} kg'),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (_editing) ...[
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notizen',
                hintText: 'Notizen (optional)',
              ),
            ),
            const SizedBox(height: 16),
          ] else if (_workout!.notes != null && _workout!.notes!.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_workout!.notes!),
              ),
            ),
            const SizedBox(height: 16),
          ],
          for (final de in _exercises)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(de.exercise.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        SizedBox(
                            width: 30,
                            child: Text('#',
                                style: TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold))),
                        Expanded(
                            child: Text('Wdh.',
                                style: TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center)),
                        Expanded(
                            child: Text('kg',
                                style: TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center)),
                        SizedBox(
                            width: 50,
                            child: Text('RPE',
                                style: TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center)),
                      ],
                    ),
                    for (final set in de.sets)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                                width: 30,
                                child: Text('${set.setNo}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary))),
                            Expanded(
                                child: Text('${set.reps}',
                                    textAlign: TextAlign.center)),
                            Expanded(
                                child: Text(formatWeight(set.weightKg),
                                    textAlign: TextAlign.center)),
                            SizedBox(
                                width: 50,
                                child: Text('${set.rpe ?? "-"}',
                                    textAlign: TextAlign.center)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _editing
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceContainerHigh,
              ),
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Speichern'),
              ),
            )
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceContainerHigh,
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error),
                    onPressed: () => _showDeleteDialog(),
                    child: const Text('Löschen'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => setState(() => _editing = true),
                    child: const Text('Bearbeiten'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMiniStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.muted),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
      ],
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Training löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              _delete();
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }
}

class _DetailExercise {
  final WorkoutExercise we;
  final Exercise exercise;
  final List<WorkoutSet> sets;

  _DetailExercise({required this.we, required this.exercise, required this.sets});
}
