import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';

class ImportService {
  final AppDatabase db;

  ImportService(this.db);

  Future<int> importJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    if (data['version'] != 1) {
      throw Exception('Unbekanntes Export-Format (Version: ${data['version']})');
    }

    int imported = 0;

    // Gyms: match by name
    final gymIdMap = <int, int>{};
    final existingGyms = await db.select(db.gyms).get();
    final gymNameMap = <String, int>{};
    for (final g in existingGyms) {
      gymNameMap[g.name.toLowerCase()] = g.id;
    }
    for (final g in (data['gyms'] as List? ?? [])) {
      final name = g['name'] as String;
      final existingId = gymNameMap[name.toLowerCase()];
      if (existingId != null) {
        gymIdMap[g['id'] as int] = existingId;
      } else {
        final newId = await db.into(db.gyms).insert(GymsCompanion.insert(
          name: name,
          city: Value(g['city'] as String?),
          isSystem: Value(g['isSystem'] as bool? ?? false),
          createdAt: DateTime.parse(g['createdAt'] as String),
        ));
        gymIdMap[g['id'] as int] = newId;
        gymNameMap[name.toLowerCase()] = newId;
        imported++;
      }
    }

    // Exercises: match by name
    final exerciseIdMap = <int, int>{};
    final existingExercises = await db.select(db.exercises).get();
    final exNameMap = <String, int>{};
    for (final e in existingExercises) {
      exNameMap[e.name.toLowerCase()] = e.id;
    }
    for (final e in (data['exercises'] as List? ?? [])) {
      final name = e['name'] as String;
      final existingId = exNameMap[name.toLowerCase()];
      if (existingId != null) {
        exerciseIdMap[e['id'] as int] = existingId;
        await (db.update(db.exercises)..where((t) => t.id.equals(existingId)))
            .write(ExercisesCompanion(
          iconKey: Value(e['iconKey'] as String? ?? 'dumbbell'),
          category: Value(e['category'] as String? ?? 'Sonstiges'),
          kind: Value(e['kind'] as String? ?? 'free_weight'),
        ));
      } else {
        final newId = await db.into(db.exercises).insert(ExercisesCompanion.insert(
          name: name,
          category: Value(e['category'] as String? ?? 'Sonstiges'),
          kind: Value(e['kind'] as String? ?? 'free_weight'),
          iconKey: Value(e['iconKey'] as String? ?? 'dumbbell'),
          isSystem: Value(e['isSystem'] as bool? ?? false),
          createdAt: DateTime.parse(e['createdAt'] as String),
        ));
        exerciseIdMap[e['id'] as int] = newId;
        exNameMap[name.toLowerCase()] = newId;
        imported++;
      }
    }

    // Exercise Aliases: match by exerciseId+alias
    final aliasIdMap = <int, int>{};
    final existingAliases = await db.select(db.exerciseAliases).get();
    final aliasKeyMap = <String, int>{};
    for (final a in existingAliases) {
      aliasKeyMap['${a.exerciseId}_${a.alias.toLowerCase()}'] = a.id;
    }
    for (final a in (data['exerciseAliases'] as List? ?? [])) {
      final exId = exerciseIdMap[a['exerciseId'] as int];
      if (exId == null) continue;
      final alias = a['alias'] as String;
    final key = '${exId}_${alias.toLowerCase()}';
      if (aliasKeyMap.containsKey(key)) continue;
      final newId = await db.into(db.exerciseAliases).insert(ExerciseAliasesCompanion.insert(
        exerciseId: exId,
        alias: alias,
        createdAt: DateTime.parse(a['createdAt'] as String),
      ));
      aliasIdMap[a['id'] as int] = newId;
      aliasKeyMap[key] = newId;
      imported++;
    }

    // Workouts: match by startedAt + gymId
    final workoutIdMap = <int, int>{};
    final existingWorkouts = await db.select(db.workouts).get();
    final workoutKeyMap = <String, int>{};
    for (final w in existingWorkouts) {
      final key = '${w.startedAt.toIso8601String()}_${w.gymId}';
      workoutKeyMap[key] = w.id;
    }
    for (final w in (data['workouts'] as List? ?? [])) {
      final startedAt = DateTime.parse(w['startedAt'] as String);
      final gymId = w['gymId'] != null ? gymIdMap[w['gymId'] as int] : null;
      final key = '${startedAt.toIso8601String()}_${gymId}';
      final existingId = workoutKeyMap[key];
      if (existingId != null) {
        workoutIdMap[w['id'] as int] = existingId;
      } else {
        final newId = await db.into(db.workouts).insert(WorkoutsCompanion.insert(
          gymId: Value(gymId),
          startedAt: startedAt,
          endedAt: w['endedAt'] != null ? Value(DateTime.parse(w['endedAt'] as String)) : const Value.absent(),
          notes: w['notes'] != null ? Value(w['notes'] as String) : const Value.absent(),
          createdAt: DateTime.parse(w['createdAt'] as String),
        ));
        workoutIdMap[w['id'] as int] = newId;
        workoutKeyMap[key] = newId;
        imported++;
      }
    }

    // Workout Exercises: match by workoutId + exerciseId + orderIdx
    final weIdMap = <int, int>{};
    final existingWes = await db.select(db.workoutExercises).get();
    final weKeyMap = <String, int>{};
    for (final we in existingWes) {
      final key = '${we.workoutId}_${we.exerciseId}_${we.orderIdx}';
      weKeyMap[key] = we.id;
    }
    for (final we in (data['workoutExercises'] as List? ?? [])) {
      final workoutId = workoutIdMap[we['workoutId'] as int];
      final exerciseId = exerciseIdMap[we['exerciseId'] as int];
      if (workoutId == null || exerciseId == null) continue;
      final orderIdx = we['orderIdx'] as int;
      final key = '${workoutId}_${exerciseId}_${orderIdx}';
      final existingId = weKeyMap[key];
      if (existingId != null) {
        weIdMap[we['id'] as int] = existingId;
      } else {
        final newId = await db.into(db.workoutExercises).insert(WorkoutExercisesCompanion.insert(
          workoutId: workoutId,
          exerciseId: exerciseId,
          orderIdx: orderIdx,
          notes: we['notes'] != null ? Value(we['notes'] as String) : const Value.absent(),
        ));
        weIdMap[we['id'] as int] = newId;
        weKeyMap[key] = newId;
        imported++;
      }
    }

    // Workout Sets: match by workoutExerciseId + setNo
    final setIdMap = <int, int>{};
    final existingSets = await db.select(db.workoutSets).get();
    final setKeyMap = <String, int>{};
    for (final s in existingSets) {
      final key = '${s.workoutExerciseId}_${s.setNo}';
      setKeyMap[key] = s.id;
    }
    for (final s in (data['workoutSets'] as List? ?? [])) {
      final weId = weIdMap[s['workoutExerciseId'] as int];
      if (weId == null) continue;
      final setNo = s['setNo'] as int;
      final key = '${weId}_${setNo}';
      final existingId = setKeyMap[key];
      if (existingId != null) {
        setIdMap[s['id'] as int] = existingId;
      } else {
        final newId = await db.into(db.workoutSets).insert(WorkoutSetsCompanion.insert(
          workoutExerciseId: weId,
          setNo: setNo,
          reps: s['reps'] as int,
          weightKg: (s['weightKg'] as num).toDouble(),
          isWarmup: Value(s['isWarmup'] as bool? ?? false),
          rpe: s['rpe'] != null ? Value(s['rpe'] as int) : const Value.absent(),
          isFailure: Value(s['isFailure'] as bool? ?? false),
          note: s['note'] != null ? Value(s['note'] as String) : const Value.absent(),
          createdAt: DateTime.parse(s['createdAt'] as String),
        ));
        setIdMap[s['id'] as int] = newId;
        setKeyMap[key] = newId;
        imported++;
      }
    }

    // Workout Templates: match by gymId + name
    final templateIdMap = <int, int>{};
    final existingTemplates = await db.select(db.workoutTemplates).get();
    final templateKeyMap = <String, int>{};
    for (final t in existingTemplates) {
      final key = '${t.gymId}_${t.name.toLowerCase()}';
      templateKeyMap[key] = t.id;
    }
    for (final t in (data['workoutTemplates'] as List? ?? [])) {
      final gymId = gymIdMap[t['gymId'] as int];
      if (gymId == null) continue;
      final name = t['name'] as String;
      final key = '${gymId}_${name.toLowerCase()}';
      final existingId = templateKeyMap[key];
      if (existingId != null) {
        templateIdMap[t['id'] as int] = existingId;
      } else {
        final newId = await db.into(db.workoutTemplates).insert(WorkoutTemplatesCompanion.insert(
          gymId: gymId,
          name: name,
          createdAt: DateTime.parse(t['createdAt'] as String),
          updatedAt: DateTime.parse(t['updatedAt'] as String),
        ));
        templateIdMap[t['id'] as int] = newId;
        templateKeyMap[key] = newId;
        imported++;
      }
    }

    // Workout Template Exercises: match by templateId + exerciseId + orderIdx
    final teKeyMap = <String, bool>{};
    final existingTes = await db.select(db.workoutTemplateExercises).get();
    for (final te in existingTes) {
      teKeyMap['${te.templateId}_${te.exerciseId}_${te.orderIdx}'] = true;
    }
    for (final te in (data['workoutTemplateExercises'] as List? ?? [])) {
      final templateId = templateIdMap[te['templateId'] as int];
      final exerciseId = exerciseIdMap[te['exerciseId'] as int];
      if (templateId == null || exerciseId == null) continue;
      final orderIdx = te['orderIdx'] as int;
      final key = '${templateId}_${exerciseId}_${orderIdx}';
      if (teKeyMap.containsKey(key)) continue;
      await db.into(db.workoutTemplateExercises).insert(WorkoutTemplateExercisesCompanion.insert(
        templateId: templateId,
        exerciseId: exerciseId,
        orderIdx: orderIdx,
      ));
      teKeyMap[key] = true;
      imported++;
    }

    return imported;
  }
}
