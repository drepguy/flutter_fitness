import 'package:drift/drift.dart';

class Gyms extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get city => text().nullable()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get category => text().withDefault(const Constant('Sonstiges'))();
  TextColumn get kind => text().withDefault(const Constant('free_weight'))();
  TextColumn get iconKey => text().withDefault(const Constant('dumbbell'))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

class ExerciseAliases extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer().references(Exercises, #id, onDelete: KeyAction.cascade)();
  TextColumn get alias => text().withLength(min: 1, max: 120)();
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [{alias, exerciseId}];
}

class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get gymId => integer().references(Gyms, #id, onDelete: KeyAction.setNull).nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [];
}

class WorkoutExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId => integer().references(Workouts, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get orderIdx => integer()();
  TextColumn get notes => text().nullable()();
}

class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutExerciseId => integer().references(WorkoutExercises, #id, onDelete: KeyAction.cascade)();
  IntColumn get setNo => integer()();
  IntColumn get reps => integer()();
  RealColumn get weightKg => real()();
  BoolColumn get isWarmup => boolean().withDefault(const Constant(false))();
  IntColumn get rpe => integer().nullable()();
  BoolColumn get isFailure => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class WorkoutTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get gymId => integer().references(Gyms, #id)();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [{gymId, name}];
}

class WorkoutTemplateExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get templateId => integer().references(WorkoutTemplates, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get orderIdx => integer()();
}
