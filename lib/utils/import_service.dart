import 'package:drift/drift.dart';
import '../database/app_database.dart';

class ImportService {
  final AppDatabase db;

  ImportService(this.db);

  Future<void> importNoteData(String rawData) async {
    final exerciseCache = <String, int>{};
    final aliasCache = <String, int>{};

    // Preload exercises
    final exercises = await db.select(db.exercises).get();
    for (final e in exercises) {
      exerciseCache[e.name.toLowerCase()] = e.id;
    }

    // Preload aliases
    final aliasRows = await (db.select(db.exerciseAliases).join([
      innerJoin(db.exercises,
          db.exercises.id.equalsExp(db.exerciseAliases.exerciseId)),
    ])).get();
    for (final row in aliasRows) {
      final alias = row.readTable(db.exerciseAliases);
      aliasCache[alias.alias.toLowerCase()] = alias.exerciseId;
    }

    // Preload gyms
    final gymCache = <String, int>{};
    final gyms = await db.select(db.gyms).get();
    for (final g in gyms) {
      gymCache[g.name.toLowerCase()] = g.id;
    }

    final now = DateTime.now();
    final sections = _parseSections(rawData, gymCache);

    for (final section in sections) {
      final gymId = gymCache[section.gymName.toLowerCase()];
      if (gymId == null) continue;

      int orderIdx = 0;

      for (final workout in section.workouts) {
        final startedAt = DateTime(workout.year, workout.month, workout.day);
        final endedAt = startedAt.add(const Duration(hours: 1, minutes: 30));

        final workoutId = await db.into(db.workouts).insert(
              WorkoutsCompanion.insert(
                gymId: Value(gymId),
                startedAt: startedAt,
                endedAt: Value(endedAt),
                createdAt: now,
              ),
            );

        orderIdx = 0;
        for (final exLine in workout.exercises) {
          final cleanName = _cleanExerciseName(exLine.name);
          final exerciseId =
              _findExerciseId(exerciseCache, aliasCache, cleanName);

          if (exerciseId == null) continue;

          final weId = await db.into(db.workoutExercises).insert(
                WorkoutExercisesCompanion.insert(
                  workoutId: workoutId,
                  exerciseId: exerciseId,
                  orderIdx: orderIdx++,
                ),
              );

          int setNo = 1;
          for (final set in exLine.sets) {
            if (set.skipped) {
              await db.into(db.workoutSets).insert(
                    WorkoutSetsCompanion.insert(
                      workoutExerciseId: weId,
                      setNo: setNo++,
                      reps: 0,
                      weightKg: 0,
                      isWarmup: const Value(false),
                      isFailure: const Value(true),
                      note: const Value('Skipped'),
                      createdAt: now,
                    ),
                  );
            } else {
              await db.into(db.workoutSets).insert(
                    WorkoutSetsCompanion.insert(
                      workoutExerciseId: weId,
                      setNo: setNo++,
                      reps: set.reps,
                      weightKg: set.weight,
                      isWarmup: const Value(false),
                      isFailure: const Value(false),
                      createdAt: now,
                    ),
                  );
            }
          }
        }
      }
    }
  }

  int? _findExerciseId(
      Map<String, int> exMap, Map<String, int> aliasMap, String name) {
    if (exMap.containsKey(name)) return exMap[name];
    for (final e in exMap.entries) {
      if (e.key.toLowerCase() == name.toLowerCase()) return e.value;
    }
    if (aliasMap.containsKey(name)) return aliasMap[name];
    for (final a in aliasMap.entries) {
      if (a.key.toLowerCase() == name.toLowerCase()) return a.value;
    }
    for (final e in exMap.entries) {
      if (name.toLowerCase().contains(e.key.toLowerCase()) ||
          e.key.toLowerCase().contains(name.toLowerCase())) {
        return e.value;
      }
    }
    final nameWords = name.toLowerCase().split(RegExp(r'\s+'));
    for (final e in exMap.entries) {
      final exWords = e.key.toLowerCase().split(RegExp(r'\s+'));
      final matching = nameWords.where((w) => exWords.contains(w)).length;
      if (matching >= 2) return e.value;
    }
    return null;
  }

  String _cleanExerciseName(String name) {
    var clean = name.trim();
    clean = clean.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    clean = clean.replaceAll(RegExp(r'\bam\s+'), ' ');
    clean = clean.replaceAll(RegExp(r'\ban\s+.*$'), '');
    clean = clean.replaceAll(RegExp(r'\bMaschine\b'), '').trim();
    clean = clean.replaceAll(RegExp(r'\bBrustgestützt\b'), '').trim();
    clean = clean.replaceAll(RegExp(r'\bals\s+Ersatz\b.*$'), '').trim();
    clean = clean.replaceAll(RegExp(r'\boverhead\s+'), ' ');
    clean = clean.replaceAll(RegExp(r'\binnen\s+'), '-');
    clean = clean.replaceAll(RegExp(r'\baußen\s+'), '-');
    clean = clean.replaceAll(RegExp(r'\bund\s+finger\b'), '').trim();
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean;
  }

  List<_Section> _parseSections(String raw, Map<String, int> gymCache) {
    final sections = <_Section>[];
    _Section? current;

    for (var line in raw.split('\n')) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Detect section headers: lines ending with ":"
      if (line.endsWith(':') && line.length > 1) {
        final headerName = line.substring(0, line.length - 1).trim();
        final lowerName = headerName.toLowerCase();

        // Find matching gym in DB (exact or fuzzy)
        String? matchedDbName;
        if (gymCache.containsKey(lowerName)) {
          matchedDbName = lowerName;
        } else {
          for (final gName in gymCache.keys) {
            if (lowerName.contains(gName) || gName.contains(lowerName)) {
              matchedDbName = gName;
              break;
            }
          }
        }

        current = _Section(gymName: matchedDbName ?? headerName);
        sections.add(current);
        continue;
      }

      if (current == null) continue;

      final dateMatch =
          RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})').firstMatch(line);
      if (dateMatch != null) {
        current.workouts.add(_WorkoutData(
          day: int.parse(dateMatch.group(1)!),
          month: int.parse(dateMatch.group(2)!),
          year: int.parse(dateMatch.group(3)!),
        ));
        continue;
      }

      if (line.contains(':') && current.workouts.isNotEmpty) {
        final colonIdx = line.indexOf(':');
        final exerciseName = line.substring(0, colonIdx).trim();
        final setsStr = line.substring(colonIdx + 1).trim();
        final sets = _parseSets(setsStr);
        if (sets.isNotEmpty) {
          current.workouts.last.exercises
              .add(_ExerciseLine(name: exerciseName, sets: sets));
        }
      }
    }

    return sections;
  }

  List<_SetLine> _parseSets(String str) {
    final sets = <_SetLine>[];
    for (var part in str.split(',')) {
      part = part.trim();
      if (part.isEmpty) continue;
      if (part.contains('muss') || part.contains('weggelassen')) {
        sets.add(_SetLine(skipped: true, weight: 0, reps: 0));
        continue;
      }
      if (part.contains('warmup') ||
          (part.contains(' und ') && !part.contains('x'))) {
        continue;
      }
      if (part.contains('abbruch')) {
        sets.add(_SetLine(skipped: true, weight: 0, reps: 0));
        continue;
      }

      part = part.replaceAll(RegExp(r'\s+'), '');

      final match =
          RegExp(r'(\d+)\s*x\s*([\d,.\w]*?)$').firstMatch(part);
      if (match != null) {
        final reps = int.tryParse(match.group(1)!);
        var weightStr = match.group(2)!.trim();
        weightStr =
            weightStr.replaceAll('kg', '').replaceAll('lg', '').trim();

        if (weightStr == 'stange' ||
            weightStr == 'body' ||
            weightStr == 'bodyweight' ||
            weightStr.isEmpty) {
          sets.add(
              _SetLine(skipped: false, weight: 0, reps: reps ?? 0));
          continue;
        }

        weightStr = weightStr.replaceAll(',', '.');
        final weight = double.tryParse(weightStr);
        if (weight != null && reps != null) {
          sets.add(
              _SetLine(skipped: false, weight: weight, reps: reps));
        }
      }
    }
    return sets;
  }
}

class _Section {
  final String gymName;
  final List<_WorkoutData> workouts = [];
  _Section({required this.gymName});
}

class _WorkoutData {
  final int day;
  final int month;
  final int year;
  final List<_ExerciseLine> exercises = [];
  _WorkoutData(
      {required this.day, required this.month, required this.year});
}

class _ExerciseLine {
  final String name;
  final List<_SetLine> sets;
  _ExerciseLine({required this.name, required this.sets});
}

class _SetLine {
  final bool skipped;
  final double weight;
  final int reps;
  _SetLine(
      {required this.skipped, required this.weight, required this.reps});
}
