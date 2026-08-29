import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import '../models/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Gyms,
  Exercises,
  ExerciseAliases,
  Workouts,
  WorkoutExercises,
  WorkoutSets,
  WorkoutTemplates,
  WorkoutTemplateExercises,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedData();
        },
      );

  Future<void> _seedData() async {
    final now = DateTime.now();

    await batch((b) {
      b.insertAll(gyms, [
        GymsCompanion.insert(
          name: 'Thomas Sport Center',
          createdAt: now,
        ),
        GymsCompanion.insert(
          name: 'All Inclusive Fitness',
          createdAt: now,
        ),
      ]);
    });

    final gym1 = await (select(gyms)..where((g) => g.name.equals('Thomas Sport Center'))).getSingle();
    final gym2 = await (select(gyms)..where((g) => g.name.equals('All Inclusive Fitness'))).getSingle();

    final exercisesData = [
      // Beine
      _ExerciseSeed('Hackenschmidt', 'Beine', 'free_weight', 'leg_press', ['Hackschmitt', 'Hack Squat']),
      _ExerciseSeed('Hip Thrust Machine', 'Beine', 'machine', 'leg_press', []),
      _ExerciseSeed('Beinpresse horizontal', 'Beine', 'machine', 'leg_press', ['Beinpresse']),
      _ExerciseSeed('Wadenpresse horizontal', 'Beine', 'machine', 'leg_press', []),
      _ExerciseSeed('Beinpresse 45°', 'Beine', 'machine', 'leg_press', []),
      _ExerciseSeed('Wadenpresse 45°', 'Beine', 'machine', 'leg_press', []),
      _ExerciseSeed('Wadenheber sitzend', 'Beine', 'machine', 'leg_press', []),
      _ExerciseSeed('Beinstrecker', 'Beine', 'machine', 'leg_press', []),
      _ExerciseSeed('Beinbeuger', 'Beine', 'machine', 'leg_press', []),
      _ExerciseSeed('Beinbeuger liegend', 'Beine', 'machine', 'leg_press', []),
      _ExerciseSeed('Wadenmaschine', 'Beine', 'machine', 'leg_press', []),
      // Push - Brust
      _ExerciseSeed('Brustpresse', 'Brust', 'machine', 'bench', ['Brust']),
      _ExerciseSeed('Brustfly', 'Brust', 'machine', 'bench', ['Chest fly']),
      // Push - Schulter
      _ExerciseSeed('Schulterpresse', 'Schulter', 'machine', 'dumbbell', []),
      _ExerciseSeed('Seitheben', 'Schulter', 'cable', 'dumbbell', []),
      // Push - Arme
      _ExerciseSeed('Trizeps Skull Crush', 'Arme', 'free_weight', 'dumbbell', ['Skullcrusher']),
      _ExerciseSeed('Trizeps Kabelzug', 'Arme', 'cable', 'cable', []),
      // Pull - Rücken
      _ExerciseSeed('Latzug', 'Rücken', 'machine', 'pull_up', []),
      _ExerciseSeed('Rudern', 'Rücken', 'machine', 'cable', []),
      _ExerciseSeed('Rudern Brustgestützt', 'Rücken', 'machine', 'cable', []),
      // Pull - Schulter
      _ExerciseSeed('Face Pulls', 'Schulter', 'cable', 'cable', []),
      // Pull - Arme
      _ExerciseSeed('Bizeps Hammer Curls', 'Arme', 'free_weight', 'dumbbell', []),
      _ExerciseSeed('Bizeps Kabelzug', 'Arme', 'cable', 'cable', []),
      // Core
      _ExerciseSeed('Hyperextension', 'Core', 'machine', 'bench', []),
      _ExerciseSeed('Bauch', 'Core', 'machine', 'dumbbell', []),
      _ExerciseSeed('Bauchmaschine', 'Core', 'machine', 'dumbbell', []),
      // Unterarme
      _ExerciseSeed('Unterarm-Innencurls', 'Unterarme', 'free_weight', 'dumbbell', []),
      _ExerciseSeed('Unterarm-Außencurls', 'Unterarme', 'free_weight', 'dumbbell', []),
    ];

    for (final ex in exercisesData) {
      final id1 = await into(exercises).insert(ExercisesCompanion.insert(
        gymId: Value(gym1.id),
        name: ex.name,
        category: Value(ex.category),
        kind: Value(ex.kind),
        iconKey: Value(ex.iconKey),
        createdAt: now,
      ));
      for (final alias in ex.aliases) {
        await into(exerciseAliases).insert(ExerciseAliasesCompanion.insert(
          exerciseId: id1,
          alias: alias,
          createdAt: now,
        ));
      }

      final id2 = await into(exercises).insert(ExercisesCompanion.insert(
        gymId: Value(gym2.id),
        name: ex.name,
        category: Value(ex.category),
        kind: Value(ex.kind),
        iconKey: Value(ex.iconKey),
        createdAt: now,
      ));
      for (final alias in ex.aliases) {
        await into(exerciseAliases).insert(ExerciseAliasesCompanion.insert(
          exerciseId: id2,
          alias: alias,
          createdAt: now,
        ));
      }
    }
  }
}

class _ExerciseSeed {
  final String name;
  final String category;
  final String kind;
  final String iconKey;
  final List<String> aliases;

  _ExerciseSeed(this.name, this.category, this.kind, this.iconKey, this.aliases);
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'ul_fitness.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
