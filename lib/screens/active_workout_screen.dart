import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' hide Column, Index;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../database/app_database.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/exercise_picker_dialog.dart';
import '../widgets/finish_dialog.dart';

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
  int _restSeconds = 0;
  Timer? _restTimer;
  final ValueNotifier<int> _restDisplaySeconds = ValueNotifier(0);
  final ValueNotifier<bool> _restDisplayRunning = ValueNotifier(false);
  final Map<int, _SetControllers> _controllers = {};
  final Map<int, _SetFocusNodes> _focusNodes = {};
  final Map<int, TextEditingController> _noteControllers = {};
  final Map<int, Timer> _saveTimers = {};
  List<int> _restPresets = [30, 60, 90, 120];
  final ScrollController _scrollController = ScrollController();

  Timer? _stopwatchTimer;
  final ValueNotifier<int> _elapsedSeconds = ValueNotifier(0);
  final List<WorkoutSet> _pendingDeletes = [];
  Timer? _deleteTimer;

  static final _setBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: const BorderSide(color: AppTheme.muted, width: 1),
  );
  static final _setBorderFocused = _setBorder.copyWith(
    borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
  );
  static final _altRowColor = AppTheme.surfaceVariant.withValues(alpha: 0.3);

  @override
  void initState() {
    super.initState();
    _loadRestPresets();
    if (widget.workout != null) {
      _workout = widget.workout!;
      if (_workout.endedAt != null) {
        _elapsedSeconds.value = _workout.endedAt!.difference(_workout.startedAt).inSeconds;
      } else {
        _startStopwatch();
      }
      _loadExercises();
    } else {
      _createWorkout();
    }
  }

  Future<void> _loadRestPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final presets = prefs.getStringList('rest_presets');
    if (presets != null && presets.length == 4) {
      setState(() {
        _restPresets = presets.map(int.parse).toList();
      });
    }
  }

  @override
  void dispose() {
    _stopwatchTimer?.cancel();
    _restTimer?.cancel();
    _deleteTimer?.cancel();
    _scrollController.dispose();
    _elapsedSeconds.dispose();
    _restDisplaySeconds.dispose();
    _restDisplayRunning.dispose();
    for (final c in _controllers.values) { c.dispose(); }
    for (final f in _focusNodes.values) { f.dispose(); }
    for (final c in _noteControllers.values) { c.dispose(); }
    super.dispose();
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    _restSeconds = seconds;
    _restDisplaySeconds.value = seconds;
    _restDisplayRunning.value = true;
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSeconds <= 0) {
        _restTimer?.cancel();
        _restDisplayRunning.value = false;
        _vibrate();
      } else {
        _restSeconds--;
        _restDisplaySeconds.value = _restSeconds;
      }
    });
  }

  void _cancelRestTimer() {
    _restTimer?.cancel();
    _restDisplayRunning.value = false;
    _restDisplaySeconds.value = 0;
  }

  Future<void> _vibrate() async {
    final prefs = await SharedPreferences.getInstance();
    final dur = prefs.getInt('vib_duration') ?? 500;
    final count = prefs.getInt('vib_count') ?? 4;
    final gap = prefs.getInt('vib_gap') ?? 600;
    for (int i = 0; i < count; i++) {
      Vibration.vibrate(duration: dur);
      if (i < count - 1) {
        await Future.delayed(Duration(milliseconds: gap));
      }
    }
  }

  String _formatRestTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  _SetControllers _getControllers(WorkoutSet set) {
    return _controllers.putIfAbsent(set.id, () => _SetControllers(
      reps: TextEditingController(text: '${set.reps}'),
      weight: TextEditingController(text: formatWeight(set.weightKg)),
      rpe: TextEditingController(text: set.rpe?.toString() ?? ''),
    ));
  }

  _SetFocusNodes _getFocusNodes(WorkoutSet set) {
    final c = _getControllers(set);
    return _focusNodes.putIfAbsent(set.id, () {
      final fn = _SetFocusNodes();
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
    });
  }

  void _startStopwatch() {
    final diff = DateTime.now().difference(_workout.startedAt).inSeconds;
    _elapsedSeconds.value = diff > 0 ? diff : 0;
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _elapsedSeconds.value++;
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });
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
      _noteControllers[we.id] = TextEditingController(text: we.notes ?? '');
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
      _noteControllers[we.id] = TextEditingController();
    });
    FocusScope.of(context).unfocus();
    _scrollToBottom();
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
    if (ae == _exercises.last) {
      _scrollToBottom();
    }
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
    _saveTimers[set.id]?.cancel();
    _saveTimers[set.id] = Timer(const Duration(milliseconds: 500), () async {
      await (widget.db.update(widget.db.workoutSets)
            ..where((s) => s.id.equals(set.id)))
          .write(WorkoutSetsCompanion(
        reps: reps != null ? Value(reps) : const Value.absent(),
        weightKg: weightKg != null ? Value(weightKg) : const Value.absent(),
        rpe: rpe != null ? Value(rpe) : const Value.absent(),
      ));
    });
  }

  Future<void> _deleteSet(WorkoutSet set, _ActiveExercise ae) async {
    _controllers.remove(set.id)?.dispose();
    _focusNodes.remove(set.id)?.dispose();
    setState(() => ae.sets.remove(set));
    _pendingDeletes.add(set);

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Satz ${set.setNo} gelöscht'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () {
            _pendingDeletes.remove(set);
            _deleteTimer?.cancel();
            setState(() => ae.sets.add(set));
            ae.sets.sort((a, b) => a.setNo.compareTo(b.setNo));
          },
        ),
      ),
    );

    _deleteTimer?.cancel();
    _deleteTimer = Timer(const Duration(seconds: 8), () async {
      for (final s in List.of(_pendingDeletes)) {
        await (widget.db.delete(widget.db.workoutSets)
              ..where((ws) => ws.id.equals(s.id)))
            .go();
      }
      _pendingDeletes.clear();
    });
  }

  Future<void> _finishWorkout(String? notes) async {
    setState(() => _saving = true);
    _deleteTimer?.cancel();
    for (final s in _pendingDeletes) {
      await (widget.db.delete(widget.db.workoutSets)
            ..where((ws) => ws.id.equals(s.id)))
          .go();
    }
    _pendingDeletes.clear();

    final updates = WorkoutsCompanion(
      notes: notes != null ? Value(notes) : const Value.absent(),
    );

    if (_workout.endedAt == null) {
      DateTime endedAt = DateTime.now();
      DateTime? lastSetTime;
      for (final ae in _exercises) {
        for (final set in ae.sets) {
          if (lastSetTime == null || set.createdAt.isAfter(lastSetTime)) {
            lastSetTime = set.createdAt;
          }
        }
      }
      if (lastSetTime != null) {
        endedAt = lastSetTime.add(const Duration(minutes: 1));
      }
      await (widget.db.update(widget.db.workouts)
            ..where((w) => w.id.equals(_workout.id)))
          .write(WorkoutsCompanion(
        endedAt: Value(endedAt),
        notes: notes != null ? Value(notes) : const Value.absent(),
      ));
    } else {
      await (widget.db.update(widget.db.workouts)
            ..where((w) => w.id.equals(_workout.id)))
          .write(updates);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _cancelWorkout() async {
    _deleteTimer?.cancel();
    _pendingDeletes.clear();
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
            if (_workout.endedAt != null)
              IconButton(
                icon: const Icon(Icons.schedule),
                onPressed: _showEditTimeDialog,
                tooltip: 'Zeiten bearbeiten',
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: ValueListenableBuilder<int>(
                  valueListenable: _elapsedSeconds,
                  builder: (context, val, _) => Text(
                    _formatElapsed(val),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
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
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add,
                                  size: 36, color: AppTheme.primary),
                            ),
                            const SizedBox(height: 16),
                            const Text('Übung hinzufügen',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('Tippe hier um zu starten',
                                style: TextStyle(
                                    color: AppTheme.muted, fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  : RepaintBoundary(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        scrollCacheExtent: ScrollCacheExtent.pixels(10000),
                        itemCount: _exercises.length,
                        itemBuilder: (context, i) =>
                            _buildExerciseCard(_exercises[i]),
                      ),
                    ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(_ActiveExercise ae) {
    final idx = _exercises.indexOf(ae) + 1;
    return RepaintBoundary(
      child: Card(
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
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '$idx',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
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
            _buildNoteField(ae),
          ],
        ),
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
    final isEven = set.setNo % 2 == 0;
    return SizedBox(
      height: 44,
      child: Container(
        color: isEven ? _altRowColor : null,
        padding: const EdgeInsets.symmetric(horizontal: 4),
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

  Widget _buildNoteField(_ActiveExercise ae) {
    final controller =
        _noteControllers.putIfAbsent(ae.workoutExercise.id, () => TextEditingController());
    if (controller.text.isEmpty && (ae.workoutExercise.notes ?? '').isNotEmpty) {
      controller.text = ae.workoutExercise.notes!;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Notiz...',
          hintStyle: TextStyle(color: AppTheme.muted.withValues(alpha: 0.5)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: InputBorder.none,
          suffixIcon: controller.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    controller.clear();
                    _saveExerciseNote(ae, '');
                  },
                  child: const Icon(Icons.close, size: 16, color: AppTheme.muted),
                )
              : null,
        ),
        onChanged: (v) => _saveExerciseNote(ae, v),
      ),
    );
  }

  void _saveExerciseNote(_ActiveExercise ae, String note) {
    (widget.db.update(widget.db.workoutExercises)
          ..where((we) => we.id.equals(ae.workoutExercise.id)))
        .write(WorkoutExercisesCompanion(notes: Value(note.isEmpty ? null : note)));
  }

  Widget _buildBottomBar() {
    final totalSets = _exercises.fold(0, (sum, e) => sum + e.sets.length);
    final totalVolume = _exercises.fold(0.0, (sum, e) {
      return sum + e.sets.fold(0.0, (s, set) => s + set.weightKg * set.reps);
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black26)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_exercises.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$totalSets Sätze',
                      style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                  const SizedBox(width: 16),
                  Text('${formatVolume(totalVolume)} kg',
                      style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                  const SizedBox(width: 16),
                  Text('${_exercises.length} Übungen',
                      style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                ],
              ),
            ),
          _buildTimerRow(),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _showExercisePicker,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Übung'),
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
                              setCount: _exercises.fold(0, (sum, e) => sum + e.sets.length),
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
        ],
      ),
    );
  }

  Widget _buildTimerRow() {
    return ValueListenableBuilder<bool>(
      valueListenable: _restDisplayRunning,
      builder: (context, running, _) {
        if (running) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: _restDisplaySeconds,
                    builder: (context, secs, _) => Text(
                      _formatRestTime(secs),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _cancelRestTimer,
                    child: const Icon(Icons.close, size: 20, color: AppTheme.secondary),
                  ),
                ],
              ),
            ),
          );
        }
        if (_exercises.any((e) => e.sets.isNotEmpty)) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _restPresets.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _buildRestChip(_restPresets[i]),
                ],
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildRestChip(int seconds) {
    return ActionChip(
      label: Text('${seconds}s', style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      onPressed: () => _startRestTimer(seconds),
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
            child: const Text('Speichern & Pausieren'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStartTime() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _workout.startedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_workout.startedAt),
    );
    if (time == null) return;
    final newStart = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
    await (widget.db.update(widget.db.workouts)
          ..where((w) => w.id.equals(_workout.id)))
        .write(WorkoutsCompanion(startedAt: Value(newStart)));
    setState(() => _workout = _workout.copyWith(startedAt: newStart));
  }

  Future<void> _pickEndTime() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _workout.endedAt ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_workout.endedAt ?? DateTime.now()),
    );
    if (time == null) return;
    final newEnd = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
    await (widget.db.update(widget.db.workouts)
          ..where((w) => w.id.equals(_workout.id)))
        .write(WorkoutsCompanion(endedAt: Value(newEnd)));
    setState(() => _workout = _workout.copyWith(endedAt: Value(newEnd)));
  }

  void _showEditTimeDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow, color: AppTheme.primary),
                title: Text('Start: ${formatDateTime(_workout.startedAt)}'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickStartTime();
                },
              ),
              if (_workout.endedAt != null)
                ListTile(
                  leading: const Icon(Icons.stop, color: AppTheme.error),
                  title: Text('Ende: ${formatDateTime(_workout.endedAt!)}'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickEndTime();
                  },
                ),
            ],
          ),
        ),
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
