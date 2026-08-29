import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' hide Column, Index;
import '../database/app_database.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/exercise_picker_dialog.dart';
import '../widgets/finish_dialog.dart';
import '../widgets/rest_timer_overlay.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final AppDatabase db;
  final Gym gym;
  final Workout? workout;

  const ActiveWorkoutScreen({
    super.key,
    required this.db,
    required this.gym,
    this.workout,
  });

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  late Workout _workout;
  List<_ActiveExercise> _exercises = [];
  bool _saving = false;
  bool _showRestTimer = false;
  final Map<int, _SetControllers> _controllers = {};
  final Map<int, _SetFocusNodes> _focusNodes = {};

  Timer? _stopwatchTimer;
  int _elapsedSeconds = 0;

  static final _setBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: const BorderSide(color: AppTheme.muted, width: 1),
  );
  static final _setBorderFocused = _setBorder.copyWith(
    borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
  );

  @override
  void initState() {
    super.initState();
    if (widget.workout != null) {
      _workout = widget.workout!;
      _startStopwatch();
      _loadExercises();
    } else {
      _createWorkout();
    }
  }

  @override
  void dispose() {
    _stopwatchTimer?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  _SetControllers _getControllers(WorkoutSet set) {
    return _controllers.putIfAbsent(set.id, () => _SetControllers(
      reps: TextEditingController(text: '${set.reps}'),
      weight: TextEditingController(text: formatWeight(set.weightKg)),
      rpe: TextEditingController(text: set.rpe?.toString() ?? ''),
    ));
  }

  _SetFocusNodes _getFocusNodes(WorkoutSet set) {
    final fn = _focusNodes.putIfAbsent(set.id, () => _SetFocusNodes());
    final c = _getControllers(set);
    fn.reps.addListener(() {
      if (fn.reps.hasFocus) {
        c.reps.selection = TextSelection(
            baseOffset: 0, extentOffset: c.reps.text.length);
      }
    });
    fn.weight.addListener(() {
      if (fn.weight.hasFocus) {
        c.weight.selection = TextSelection(
            baseOffset: 0, extentOffset: c.weight.text.length);
      }
    });
    fn.rpe.addListener(() {
      if (fn.rpe.hasFocus) {
        c.rpe.selection = TextSelection(
            baseOffset: 0, extentOffset: c.rpe.text.length);
      }
    });
    return fn;
  }

  void _startStopwatch() {
    final diff = DateTime.now().difference(_workout.startedAt).inSeconds;
    setState(() => _elapsedSeconds = diff > 0 ? diff : 0);
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  String _formatElapsed(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _createWorkout() async {
    final now = DateTime.now();
    final id = await widget.db.into(widget.db.workouts).insert(
          WorkoutsCompanion.insert(
            gymId: Value(widget.gym.id),
            startedAt: now,
            createdAt: now,
          ),
        );
    final workout = await (widget.db.select(widget.db.workouts)
          ..where((w) => w.id.equals(id)))
        .getSingle();
    setState(() => _workout = workout);
    _startStopwatch();
  }

  Future<void> _loadExercises() async {
    final wes = await (widget.db.select(widget.db.workoutExercises)
          ..where((we) => we.workoutId.equals(_workout.id))
          ..orderBy([(we) => OrderingTerm.asc(we.orderIdx)]))
        .get();

    final activeExercises = <_ActiveExercise>[];
    for (final we in wes) {
      final exercise =
          await (widget.db.select(widget.db.exercises)
                ..where((e) => e.id.equals(we.exerciseId)))
              .getSingle();
      final sets = await (widget.db.select(widget.db.workoutSets)
            ..where((s) => s.workoutExerciseId.equals(we.id))
            ..orderBy([(s) => OrderingTerm.asc(s.setNo)]))
          .get();
      activeExercises.add(_ActiveExercise(
        workoutExercise: we,
        exercise: exercise,
        sets: sets,
      ));
    }
    setState(() => _exercises = activeExercises);
  }

  Future<void> _addExercise(Exercise exercise) async {
    final orderIdx = _exercises.length;
    final weId = await widget.db.into(widget.db.workoutExercises).insert(
          WorkoutExercisesCompanion.insert(
            workoutId: _workout.id,
            exerciseId: exercise.id,
            orderIdx: orderIdx,
          ),
        );
    final we = await (widget.db.select(widget.db.workoutExercises)
          ..where((w) => w.id.equals(weId)))
        .getSingle();
    setState(() {
      _exercises.add(_ActiveExercise(
        workoutExercise: we,
        exercise: exercise,
        sets: [],
      ));
    });
  }

  Future<Exercise?> _predictNextExercise() async {
    if (_exercises.isEmpty) {
      final lastWorkout = await (widget.db.select(widget.db.workouts)
            ..where((w) =>
                w.gymId.equals(widget.gym.id) &
                w.endedAt.isNotNull() &
                w.id.isNotValue(_workout.id))
          ..orderBy([(w) => OrderingTerm.desc(w.startedAt)])
          ..limit(1))
          .getSingleOrNull();
      if (lastWorkout == null) return null;

      final lastWes = await (widget.db.select(widget.db.workoutExercises)
            ..where((we) => we.workoutId.equals(lastWorkout.id))
            ..orderBy([(we) => OrderingTerm.asc(we.orderIdx)]))
          .get();
      if (lastWes.isEmpty) return null;

      return (widget.db.select(widget.db.exercises)
            ..where((e) => e.id.equals(lastWes.first.exerciseId)))
          .getSingleOrNull();
    }

    final lastWorkout = await (widget.db.select(widget.db.workouts)
          ..where((w) =>
              w.gymId.equals(widget.gym.id) &
              w.endedAt.isNotNull() &
              w.id.isNotValue(_workout.id))
        ..orderBy([(w) => OrderingTerm.desc(w.startedAt)])
        ..limit(1))
        .getSingleOrNull();
    if (lastWorkout == null) return null;

    final lastWes = await (widget.db.select(widget.db.workoutExercises)
          ..where((we) => we.workoutId.equals(lastWorkout.id))
          ..orderBy([(we) => OrderingTerm.asc(we.orderIdx)]))
        .get();

    final currentExerciseIds = _exercises.map((e) => e.exercise.id).toSet();

    for (final we in lastWes) {
      if (!currentExerciseIds.contains(we.exerciseId)) {
        return (widget.db.select(widget.db.exercises)
              ..where((e) => e.id.equals(we.exerciseId)))
            .getSingleOrNull();
      }
    }

    return null;
  }

  Future<void> _showExercisePicker() async {
    final suggested = await _predictNextExercise();
    final exercise = await showDialog<Exercise>(
      context: context,
      builder: (_) => ExercisePickerDialog(
        db: widget.db,
        suggestedExercise: suggested,
      ),
    );
    if (exercise != null) _addExercise(exercise);
  }

  Future<void> _removeExercise(_ActiveExercise ae) async {
    for (final set in ae.sets) {
      _controllers.remove(set.id)?.dispose();
      _focusNodes.remove(set.id)?.dispose();
    }
    await (widget.db.delete(widget.db.workoutExercises)
          ..where((w) => w.id.equals(ae.workoutExercise.id)))
        .go();
    setState(() => _exercises.remove(ae));
  }

  Future<void> _addSet(_ActiveExercise ae) async {
    final ghostData = await _getGhostData(ae);
    final setNo = ae.sets.length + 1;

    final setId = await widget.db.into(widget.db.workoutSets).insert(
          WorkoutSetsCompanion.insert(
            workoutExerciseId: ae.workoutExercise.id,
            setNo: setNo,
            reps: ghostData?.reps ?? 0,
            weightKg: ghostData?.weightKg ?? 0.0,
            createdAt: DateTime.now(),
          ),
        );
    final set = await (widget.db.select(widget.db.workoutSets)
          ..where((s) => s.id.equals(setId)))
        .getSingle();
    setState(() => ae.sets.add(set));
  }

  Future<WorkoutSet?> _getGhostData(_ActiveExercise ae) async {
    final lastWorkout = await (widget.db.select(widget.db.workouts)
          ..where((w) =>
              w.gymId.equals(widget.gym.id) &
              w.endedAt.isNotNull() &
              w.id.isNotValue(_workout.id))
          ..orderBy([(w) => OrderingTerm.desc(w.startedAt)])
          ..limit(1))
        .getSingleOrNull();

    if (lastWorkout == null) return null;

    final lastWe = await (widget.db.select(widget.db.workoutExercises)
          ..where((we) =>
              we.workoutId.equals(lastWorkout.id) &
              we.exerciseId.equals(ae.exercise.id))
          ..limit(1))
        .getSingleOrNull();

    if (lastWe == null) return null;

    final lastSets = await (widget.db.select(widget.db.workoutSets)
          ..where((s) => s.workoutExerciseId.equals(lastWe.id))
          ..orderBy([(s) => OrderingTerm.asc(s.setNo)]))
        .get();

    if (lastSets.isEmpty) return null;

    final idx = ae.sets.length;
    if (idx < lastSets.length) {
      return lastSets[idx];
    }
    return lastSets.last;
  }

  Future<void> _updateSet(WorkoutSet set, {int? reps, double? weightKg, int? rpe}) async {
    await (widget.db.update(widget.db.workoutSets)
          ..where((s) => s.id.equals(set.id)))
        .write(WorkoutSetsCompanion(
      reps: reps != null ? Value(reps) : const Value.absent(),
      weightKg: weightKg != null ? Value(weightKg) : const Value.absent(),
      rpe: rpe != null ? Value(rpe) : const Value.absent(),
    ));
  }

  Future<void> _deleteSet(WorkoutSet set, _ActiveExercise ae) async {
    _controllers.remove(set.id)?.dispose();
    _focusNodes.remove(set.id)?.dispose();
    await (widget.db.delete(widget.db.workoutSets)
          ..where((s) => s.id.equals(set.id)))
        .go();
    setState(() => ae.sets.remove(set));
  }

  Future<void> _finishWorkout(String? notes) async {
    setState(() => _saving = true);
    await (widget.db.update(widget.db.workouts)
          ..where((w) => w.id.equals(_workout.id)))
        .write(WorkoutsCompanion(
      endedAt: Value(DateTime.now()),
      notes: notes != null ? Value(notes) : const Value.absent(),
    ));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _cancelWorkout() async {
    await (widget.db.delete(widget.db.workoutSets)
          ..where((s) =>
              s.workoutExerciseId.isIn(_exercises.map((e) => e.workoutExercise.id))))
        .go();
    await (widget.db.delete(widget.db.workoutExercises)
          ..where((we) => we.workoutId.equals(_workout.id)))
        .go();
    await (widget.db.delete(widget.db.workouts)
          ..where((w) => w.id.equals(_workout.id)))
        .go();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _workout.endedAt != null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showPauseDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.gym.name),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  _formatElapsed(_elapsedSeconds),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _exercises.isEmpty
                  ? GestureDetector(
                      onTap: _showExercisePicker,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_circle_outline,
                                size: 64, color: AppTheme.muted),
                            const SizedBox(height: 12),
                            Text('Übung hinzufügen um zu starten',
                                style: TextStyle(color: AppTheme.muted)),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _exercises.length,
                      itemBuilder: (context, i) =>
                          _buildExerciseCard(_exercises[i]),
                    ),
            ),
            if (_showRestTimer)
              RestTimerOverlay(
                onClose: () => setState(() => _showRestTimer = false),
              ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(_ActiveExercise ae) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fitness_center,
                      color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ae.exercise.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(ae.exercise.category,
                          style: const TextStyle(
                              color: AppTheme.muted, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                  onPressed: () => _removeExercise(ae),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSetTable(ae),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _addSet(ae),
                child: const Text('Satz'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetTable(_ActiveExercise ae) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: const [
              SizedBox(
                  width: 40,
                  child: Text('Satz',
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
              SizedBox(width: 32),
            ],
          ),
          for (final set in ae.sets) _buildSetRow(set, ae),
        ],
      ),
    );
  }

  Widget _buildSetRow(WorkoutSet set, _ActiveExercise ae) {
    final c = _getControllers(set);
    final f = _getFocusNodes(set);
    final timeStr =
        '${set.createdAt.hour.toString().padLeft(2, '0')}:${set.createdAt.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${set.setNo}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        fontSize: 13),
                  ),
                  Text(
                    timeStr,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 9),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TextField(
                controller: c.reps,
                focusNode: f.reps,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
                onTap: () => c.reps.selection = TextSelection(
                    baseOffset: 0, extentOffset: c.reps.text.length),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(f.weight),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  isCollapsed: true,
                  border: _setBorder,
                  enabledBorder: _setBorder,
                  focusedBorder: _setBorderFocused,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final reps = int.tryParse(v) ?? 0;
                  _updateSet(set, reps: reps);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: c.weight,
                focusNode: f.weight,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
                onTap: () => c.weight.selection = TextSelection(
                    baseOffset: 0, extentOffset: c.weight.text.length),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(f.rpe),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  isCollapsed: true,
                  border: _setBorder,
                  enabledBorder: _setBorder,
                  focusedBorder: _setBorderFocused,
                ),
                onChanged: (v) {
                  final w = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                  _updateSet(set, weightKg: w);
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 50,
              child: TextField(
                controller: c.rpe,
                focusNode: f.rpe,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
                onTap: () => c.rpe.selection = TextSelection(
                    baseOffset: 0, extentOffset: c.rpe.text.length),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: '-',
                  contentPadding: EdgeInsets.zero,
                  isCollapsed: true,
                  border: _setBorder,
                  enabledBorder: _setBorder,
                  focusedBorder: _setBorderFocused,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final rpe = int.tryParse(v);
                  _updateSet(set, rpe: rpe);
                },
              ),
            ),
            SizedBox(
              width: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, size: 18, color: AppTheme.error),
                onPressed: () => _deleteSet(set, ae),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black26)],
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _showExercisePicker,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Übung'),
          ),
          const SizedBox(width: 8),
          if (_exercises.any((e) => e.sets.isNotEmpty))
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _showRestTimer = !_showRestTimer);
              },
              icon: const Icon(Icons.pause, size: 18),
              label: const Text('Rest'),
            ),
          const Spacer(),
          if (_exercises.isEmpty)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () => _showCancelDialog(),
              child: const Text('Abbrechen'),
            )
          else
            ElevatedButton(
              onPressed: _saving
                  ? null
                  : () async {
                      final result = await showDialog<Map<String, dynamic>>(
                        context: context,
                        builder: (_) => FinishDialog(
                          exerciseCount: _exercises.length,
                          setCount: _exercises.fold(
                              0, (sum, e) => sum + e.sets.length),
                        ),
                      );
                      if (result != null) {
                        _finishWorkout(result['notes'] as String?);
                      }
                    },
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Fertig'),
            ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Training abbrechen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Weiter'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              _cancelWorkout();
            },
            child: const Text('Ja, abbrechen'),
          ),
        ],
      ),
    );
  }

  void _showPauseDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Training pausieren?'),
        content: const Text('Das Training wird gespeichert und kann später fortgesetzt werden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Speichern & Beenden'),
          ),
        ],
      ),
    );
  }
}

class _ActiveExercise {
  final WorkoutExercise workoutExercise;
  final Exercise exercise;
  final List<WorkoutSet> sets;

  _ActiveExercise({
    required this.workoutExercise,
    required this.exercise,
    required this.sets,
  });
}

class _SetControllers {
  final TextEditingController reps;
  final TextEditingController weight;
  final TextEditingController rpe;

  _SetControllers({
    required this.reps,
    required this.weight,
    required this.rpe,
  });

  void dispose() {
    reps.dispose();
    weight.dispose();
    rpe.dispose();
  }
}

class _SetFocusNodes {
  final FocusNode reps;
  final FocusNode weight;
  final FocusNode rpe;

  _SetFocusNodes()
      : reps = FocusNode(),
        weight = FocusNode(),
        rpe = FocusNode();

  void dispose() {
    reps.dispose();
    weight.dispose();
    rpe.dispose();
  }
}
