import 'dart:convert';
import '../database/app_database.dart';

class ExportService {
  final AppDatabase db;

  ExportService(this.db);

  Future<String> exportAsJson() async {
    final data = <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
    };

    // Gyms
    final gyms = await db.select(db.gyms).get();
    data['gyms'] = gyms.map((g) => {
      'id': g.id,
      'name': g.name,
      'city': g.city,
      'isSystem': g.isSystem,
      'createdAt': g.createdAt.toIso8601String(),
    }).toList();

    // Exercises
    final exercises = await db.select(db.exercises).get();
    data['exercises'] = exercises.map((e) => {
      'id': e.id,
      'name': e.name,
      'category': e.category,
      'kind': e.kind,
      'iconKey': e.iconKey,
      'isSystem': e.isSystem,
      'createdAt': e.createdAt.toIso8601String(),
    }).toList();

    // Exercise Aliases
    final aliases = await db.select(db.exerciseAliases).get();
    data['exerciseAliases'] = aliases.map((a) => {
      'id': a.id,
      'exerciseId': a.exerciseId,
      'alias': a.alias,
      'createdAt': a.createdAt.toIso8601String(),
    }).toList();

    // Workouts
    final workouts = await db.select(db.workouts).get();
    data['workouts'] = workouts.map((w) => {
      'id': w.id,
      'gymId': w.gymId,
      'startedAt': w.startedAt.toIso8601String(),
      'endedAt': w.endedAt?.toIso8601String(),
      'notes': w.notes,
      'createdAt': w.createdAt.toIso8601String(),
    }).toList();

    // Workout Exercises
    final wes = await db.select(db.workoutExercises).get();
    data['workoutExercises'] = wes.map((we) => {
      'id': we.id,
      'workoutId': we.workoutId,
      'exerciseId': we.exerciseId,
      'orderIdx': we.orderIdx,
      'notes': we.notes,
    }).toList();

    // Workout Sets
    final sets = await db.select(db.workoutSets).get();
    data['workoutSets'] = sets.map((s) => {
      'id': s.id,
      'workoutExerciseId': s.workoutExerciseId,
      'setNo': s.setNo,
      'reps': s.reps,
      'weightKg': s.weightKg,
      'isWarmup': s.isWarmup,
      'rpe': s.rpe,
      'isFailure': s.isFailure,
      'note': s.note,
      'createdAt': s.createdAt.toIso8601String(),
    }).toList();

    // Workout Templates
    final templates = await db.select(db.workoutTemplates).get();
    data['workoutTemplates'] = templates.map((t) => {
      'id': t.id,
      'gymId': t.gymId,
      'name': t.name,
      'createdAt': t.createdAt.toIso8601String(),
      'updatedAt': t.updatedAt.toIso8601String(),
    }).toList();

    // Workout Template Exercises
    final tExercises = await db.select(db.workoutTemplateExercises).get();
    data['workoutTemplateExercises'] = tExercises.map((te) => {
      'id': te.id,
      'templateId': te.templateId,
      'exerciseId': te.exerciseId,
      'orderIdx': te.orderIdx,
    }).toList();

    return const JsonEncoder.withIndent('  ').convert(data);
  }
}
