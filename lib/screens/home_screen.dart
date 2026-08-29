import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column, Index;
import '../database/app_database.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/import_service.dart';
import 'active_workout_screen.dart';
import 'gym_management_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppDatabase db;

  const HomeScreen({super.key, required this.db});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Gym> _gyms = [];
  List<Workout> _recentWorkouts = [];
  Map<int, List<WorkoutTemplate>> _templatesByGym = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _showImportDialog() async {
    final textController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notizen importieren'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: TextField(
            controller: textController,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              hintText: 'Trainingsdaten hier einfügen...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Importieren'),
          ),
        ],
      ),
    );

    if (confirmed == true && textController.text.isNotEmpty) {
      try {
        final service = ImportService(widget.db);
        await service.importNoteData(textController.text);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Import erfolgreich!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      }
    }
  }

  Future<void> _loadData() async {
    final gyms = await widget.db.select(widget.db.gyms).get();
    final workouts = await (widget.db.select(widget.db.workouts)
          ..orderBy([(w) => OrderingTerm.desc(w.startedAt)])
          ..limit(20))
        .get();

    final templatesByGym = <int, List<WorkoutTemplate>>{};
    for (final gym in gyms) {
      final templates = await (widget.db.select(widget.db.workoutTemplates)
            ..where((t) => t.gymId.equals(gym.id)))
          .get();
      templatesByGym[gym.id] = templates;
    }

    setState(() {
      _gyms = gyms;
      _recentWorkouts = workouts;
      _templatesByGym = templatesByGym;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UL Fitness'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => _showImportDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GymManagementScreen(db: widget.db),
                ),
              );
              _loadData();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Willkommen!',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 4),
            Text('Bleib stark. Trainier konsequent.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.muted,
                    )),
            const SizedBox(height: 24),
            Text('Training starten',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 8),
            for (final gym in _gyms) _buildGymCard(gym),
            const SizedBox(height: 24),
            if (_templatesByGym.isNotEmpty) ...[
              Text('Vorlagen',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
              const SizedBox(height: 8),
              for (final gym in _gyms) ...[
                if ((_templatesByGym[gym.id] ?? []).isNotEmpty) ...[
                  Text(gym.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.muted,
                          )),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in _templatesByGym[gym.id]!)
                        ActionChip(
                          label: Text(t.name),
                          onPressed: () => _startWorkoutFromTemplate(gym, t),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: const Text('Neue Vorlage'),
                        onPressed: () => _createTemplateFromLastWorkout(gym),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ],
            const SizedBox(height: 24),
            Text('Letzte Trainings',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 8),
            if (_recentWorkouts.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text('Noch keine Trainings',
                        style: TextStyle(color: AppTheme.muted)),
                  ),
                ),
              )
            else
              for (final w in _recentWorkouts) _buildWorkoutCard(w),
          ],
        ),
      ),
    );
  }

  Widget _buildGymCard(Gym gym) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ActiveWorkoutScreen(db: widget.db, gym: gym),
            ),
          );
          _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.play_arrow, color: AppTheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gym.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    if (gym.city != null)
                      Text(gym.city!,
                          style: const TextStyle(
                              color: AppTheme.muted, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutCard(Workout workout) {
    final isActive = workout.endedAt == null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onLongPress: () => _showDeleteWorkoutDialog(workout),
        onTap: () async {
          final gym = await (widget.db.select(widget.db.gyms)
                ..where((g) => g.id.equals(workout.gymId!)))
              .getSingle();
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ActiveWorkoutScreen(
                db: widget.db,
                gym: gym,
                workout: workout,
              ),
            ),
          );
          _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: FutureBuilder<Gym?>(
                      future: workout.gymId != null
                          ? (widget.db.select(widget.db.gyms)
                                ..where((g) => g.id.equals(workout.gymId!)))
                              .getSingleOrNull()
                          : Future.value(null),
                      builder: (context, snap) {
                        return Text(
                          snap.data?.name ?? 'Kein Studio',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.secondary.withValues(alpha: 0.2)
                          : AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isActive ? 'Aktiv' : 'Fertig',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isActive ? AppTheme.secondary : AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(formatDateTime(workout.startedAt),
                  style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
              if (workout.notes != null && workout.notes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(workout.notes!,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startWorkoutFromTemplate(Gym gym, WorkoutTemplate template) async {
    final now = DateTime.now();
    final workoutId = await widget.db.into(widget.db.workouts).insert(
          WorkoutsCompanion.insert(
            gymId: Value(gym.id),
            startedAt: now,
            createdAt: now,
          ),
        );

    final templateExercises = await (widget.db
          .select(widget.db.workoutTemplateExercises)
        ..where((t) => t.templateId.equals(template.id))
        ..orderBy([(t) => OrderingTerm.asc(t.orderIdx)]))
        .get();

    for (final te in templateExercises) {
      await widget.db.into(widget.db.workoutExercises).insert(
            WorkoutExercisesCompanion.insert(
              workoutId: workoutId,
              exerciseId: te.exerciseId,
              orderIdx: te.orderIdx,
            ),
          );
    }

    if (mounted) {
      final workout = await (widget.db.select(widget.db.workouts)
            ..where((w) => w.id.equals(workoutId)))
          .getSingle();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveWorkoutScreen(
            db: widget.db,
            gym: gym,
            workout: workout,
          ),
        ),
      );
    }
  }

  Future<void> _createTemplateFromLastWorkout(Gym gym) async {
    final lastWorkout = await (widget.db.select(widget.db.workouts)
          ..where((w) => w.gymId.equals(gym.id) & w.endedAt.isNotNull())
          ..orderBy([(w) => OrderingTerm.desc(w.startedAt)])
          ..limit(1))
        .getSingleOrNull();

    if (lastWorkout == null) return;

    final now = DateTime.now();
    final name =
        'Vorlage ${formatDate(now).substring(0, 5)} ${formatTime(now)}';

    final templateId = await widget.db.into(widget.db.workoutTemplates).insert(
          WorkoutTemplatesCompanion.insert(
            gymId: gym.id,
            name: name,
            createdAt: now,
            updatedAt: now,
          ),
        );

    final workoutExercises = await (widget.db
          .select(widget.db.workoutExercises)
        ..where((we) => we.workoutId.equals(lastWorkout.id))
        ..orderBy([(we) => OrderingTerm.asc(we.orderIdx)]))
        .get();

    for (final we in workoutExercises) {
      await widget.db
          .into(widget.db.workoutTemplateExercises)
          .insert(WorkoutTemplateExercisesCompanion.insert(
            templateId: templateId,
            exerciseId: we.exerciseId,
            orderIdx: we.orderIdx,
          ));
    }

    _loadData();
  }

  Future<void> _showDeleteWorkoutDialog(Workout workout) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Training löschen?'),
        content: const Text('Diese Aktion kann nicht rückgängig gemacht werden.'),
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
      await (widget.db.delete(widget.db.workouts)
            ..where((w) => w.id.equals(workout.id)))
          .go();
      _loadData();
    }
  }
}
