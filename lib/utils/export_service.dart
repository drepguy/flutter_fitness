import 'package:drift/drift.dart';
import '../database/app_database.dart';

class ExportService {
  final AppDatabase db;

  ExportService(this.db);

  Future<String> exportAsText() async {
    final gyms = await db.select(db.gyms).get();
    final buffer = StringBuffer();

    for (final gym in gyms) {
      final workouts = await (db.select(db.workouts)
            ..where((w) => w.gymId.equals(gym.id) & w.endedAt.isNotNull())
          ..orderBy([(w) => OrderingTerm.asc(w.startedAt)]))
          .get();

      if (workouts.isEmpty) continue;

      buffer.writeln('${gym.name}:');

      for (final workout in workouts) {
        final date = workout.startedAt;
        final dateStr =
            '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
        buffer.writeln(dateStr);

        final wes = await (db.select(db.workoutExercises)
              ..where((we) => we.workoutId.equals(workout.id))
            ..orderBy([(we) => OrderingTerm.asc(we.orderIdx)]))
            .get();

        for (final we in wes) {
          final exercise = await (db.select(db.exercises)
                ..where((e) => e.id.equals(we.exerciseId)))
              .getSingleOrNull();
          if (exercise == null) continue;

          final sets = await (db.select(db.workoutSets)
                ..where((s) => s.workoutExerciseId.equals(we.id))
              ..orderBy([(s) => OrderingTerm.asc(s.setNo)]))
              .get();

          if (sets.isEmpty) continue;

          final setStrings = <String>[];
          for (final s in sets) {
            if (s.isFailure && s.reps == 0) continue;
            final weight = s.weightKg == 0 ? 'stange' : '${s.weightKg}kg';
            setStrings.add('${s.reps}x$weight');
          }

          if (setStrings.isNotEmpty) {
            buffer.writeln('${exercise.name}: ${setStrings.join(', ')}');
          }
        }

        buffer.writeln();
      }
    }

    return buffer.toString();
  }
}
