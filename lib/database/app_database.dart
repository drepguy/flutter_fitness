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
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedData();
        },
        onUpgrade: (m, from, to) async {
          for (final table in allTables) {
            await m.deleteTable(table.actualTableName);
          }
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

    final exercisesData = [
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
      _ExerciseSeed('Brustpresse', 'Brust', 'machine', 'bench', ['Brust']),
      _ExerciseSeed('Brustfly', 'Brust', 'machine', 'bench', ['Chest fly']),
      _ExerciseSeed('Schulterpresse', 'Schulter', 'machine', 'dumbbell', []),
      _ExerciseSeed('Seitheben', 'Schulter', 'cable', 'dumbbell', []),
      _ExerciseSeed('Trizeps Skull Crush', 'Arme', 'free_weight', 'dumbbell', ['Skullcrusher']),
      _ExerciseSeed('Trizeps Kabelzug', 'Arme', 'cable', 'cable', []),
      _ExerciseSeed('Latzug', 'Rücken', 'machine', 'pull_up', []),
      _ExerciseSeed('Rudern', 'Rücken', 'machine', 'cable', []),
      _ExerciseSeed('Rudern Brustgestützt', 'Rücken', 'machine', 'cable', []),
      _ExerciseSeed('Face Pulls', 'Schulter', 'cable', 'cable', []),
      _ExerciseSeed('Bizeps Hammer Curls', 'Arme', 'free_weight', 'dumbbell', []),
      _ExerciseSeed('Bizeps Kabelzug', 'Arme', 'cable', 'cable', []),
      _ExerciseSeed('Hyperextension', 'Core', 'machine', 'bench', []),
      _ExerciseSeed('Bauch', 'Core', 'machine', 'dumbbell', []),
      _ExerciseSeed('Bauchmaschine', 'Core', 'machine', 'dumbbell', []),
      _ExerciseSeed('Unterarm-Innencurls', 'Unterarme', 'free_weight', 'dumbbell', []),
      _ExerciseSeed('Unterarm-Außencurls', 'Unterarme', 'free_weight', 'dumbbell', []),
    ];

    for (final ex in exercisesData) {
      final id = await into(exercises).insert(ExercisesCompanion.insert(
        name: ex.name,
        category: Value(ex.category),
        kind: Value(ex.kind),
        iconKey: Value(ex.iconKey),
        createdAt: now,
      ));
      for (final alias in ex.aliases) {
        await into(exerciseAliases).insert(ExerciseAliasesCompanion.insert(
          exerciseId: id,
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
