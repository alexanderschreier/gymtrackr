import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// -----------------
// Tables
// -----------------
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get group => text().nullable()();
  RealColumn get defaultWeightStep => real().withDefault(const Constant(2.5))();
  IntColumn get defaultRepMin => integer().withDefault(const Constant(5))();
  IntColumn get defaultRepMax => integer().withDefault(const Constant(8))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Plans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class PlanExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId =>
      integer().references(Plans, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.restrict)();
  IntColumn get order => integer().withDefault(const Constant(0))();
  IntColumn get sets => integer().withDefault(const Constant(3))();
  IntColumn get repMin => integer().withDefault(const Constant(5))();
  IntColumn get repMax => integer().withDefault(const Constant(8))();
  RealColumn get weightStep => real().withDefault(const Constant(2.5))();
  RealColumn get initialWeight => real().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  List<String> get customConstraints => [
    'UNIQUE(plan_id, exercise_id, "order")',
  ];
}

class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId =>
      integer().references(Plans, #id, onDelete: KeyAction.setNull).nullable()();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  TextColumn get note => text().nullable()();
}

class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId =>
      integer().references(Workouts, #id, onDelete: KeyAction.cascade)();
  IntColumn get planExerciseId => integer()
      .nullable()
      .references(PlanExercises, #id, onDelete: KeyAction.setNull)();
  IntColumn get setIndex => integer()();
  RealColumn get targetWeight => real().withDefault(const Constant(0))();
  RealColumn get actualWeight => real().nullable()();
  IntColumn get actualReps => integer().nullable()();

  @override
  List<String> get customConstraints =>
      ['UNIQUE(workout_id, plan_exercise_id, set_index)'];
}

class Settings extends Table {
  IntColumn get id => integer().autoIncrement()();
  BoolColumn get unitKg => boolean().withDefault(const Constant(true))();
  IntColumn get themeMode => integer().withDefault(const Constant(0))(); // 0=system
  RealColumn get defaultWeightStep => real().withDefault(const Constant(2.5))();
}

// -----------------
// Database + DAOs
// -----------------
@DriftDatabase(
  tables: [
    Exercises,
    Plans,
    PlanExercises,
    Workouts,
    WorkoutSets,
    Settings,
  ],
  daos: [
    ExercisesDao,
    PlansDao,
    PlanExercisesDao,
    WorkoutsDao,
    WorkoutSetsDao,
    SettingsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // In-Memory für Tests
  AppDatabase.test() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
    onCreate: (m) async {
      await m.createAll();
      await _seedData(this);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(planExercises, planExercises.notes);
      }
      if (from < 3) {
        // Recreate workout_sets with the new nullable FK (SET NULL) and copy data.
        await m.alterTable(TableMigration(workoutSets));
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dir.path, 'gymtrackr.sqlite'));
    return NativeDatabase(dbFile);
  });
}

Future<void> _seedData(AppDatabase db) async {
  await db.into(db.settings).insert(const SettingsCompanion());
  await db.into(db.exercises).insert(ExercisesCompanion.insert(
    name: 'Bankdrücken (Langhantel)',
    group: const Value('Brust'),
    defaultWeightStep: const Value(2.5),
    defaultRepMin: const Value(5),
    defaultRepMax: const Value(8),
    notes: const Value('Flachbank, Schulterblätter fixieren'),
  ));
  await db.into(db.exercises).insert(ExercisesCompanion.insert(
    name: 'Kniebeuge (Langhantel)',
    group: const Value('Beine'),
    defaultWeightStep: const Value(2.5),
    defaultRepMin: const Value(5),
    defaultRepMax: const Value(8),
    notes: const Value('Tief, Core stabil'),
  ));
}

// -----------------
// DAOs
// -----------------
@DriftAccessor(tables: [Exercises])
class ExercisesDao extends DatabaseAccessor<AppDatabase>
    with _$ExercisesDaoMixin {
  ExercisesDao(AppDatabase db) : super(db);

  Future<List<Exercise>> byIds(List<int> ids) =>
      (select(exercises)..where((t) => t.id.isIn(ids))).get();

  Future<int> create(ExercisesCompanion data) => into(exercises).insert(data);
  Future<List<Exercise>> all() => select(exercises).get();
  Stream<List<Exercise>> watchAll() => select(exercises).watch();

  Future<bool> updateById(int id, ExercisesCompanion data) async {
    final count =
    await (update(exercises)..where((t) => t.id.equals(id))).write(data);
    return count > 0;
  }

  Future<int> deleteById(int id) =>
      (delete(exercises)..where((t) => t.id.equals(id))).go();
}

@DriftAccessor(tables: [Plans, Workouts, PlanExercises])
class PlansDao extends DatabaseAccessor<AppDatabase> with _$PlansDaoMixin {
  PlansDao(AppDatabase db) : super(db);

  Future<int> create(PlansCompanion data) => into(plans).insert(data);
  Future<List<Plan>> all() => select(plans).get();
  Stream<List<Plan>> watchAll() => select(plans).watch();

  Future<bool> updateById(int id, PlansCompanion data) async {
    final count =
    await (update(plans)..where((t) => t.id.equals(id))).write(data);
    return count > 0;
  }

  /// FK-safe löschen: Workouts.planId -> NULL, PlanExercises löschen, dann Plan löschen
  Future<void> safeDelete(int id) async {
    await transaction(() async {
      // planId in Workouts auf NULL setzen
      await (attachedDatabase.update(attachedDatabase.workouts)
        ..where((w) => w.planId.equals(id)))
          .write(const WorkoutsCompanion(planId: Value(null)));

      // alle PlanExercises zu diesem Plan löschen
      await (attachedDatabase.delete(attachedDatabase.planExercises)
        ..where((t) => t.planId.equals(id)))
          .go();

      // Plan selbst löschen
      await (attachedDatabase.delete(attachedDatabase.plans)
        ..where((t) => t.id.equals(id)))
          .go();
    });
  }

  Future<int> deleteById(int id) =>
      (delete(plans)..where((t) => t.id.equals(id))).go();
}


@DriftAccessor(tables: [PlanExercises, Exercises, WorkoutSets])
class PlanExercisesDao extends DatabaseAccessor<AppDatabase>
    with _$PlanExercisesDaoMixin {
  PlanExercisesDao(AppDatabase db) : super(db);

  Future<List<PlanExercise>> byIds(List<int> ids) =>
      (select(planExercises)..where((t) => t.id.isIn(ids))).get();

  Future<int> add(PlanExercisesCompanion data) =>
      into(planExercises).insert(data);

  Future<List<PlanExercise>> byPlan(int planId) =>
      (select(planExercises)
        ..where((t) => t.planId.equals(planId))
        ..orderBy([(t) => OrderingTerm.asc(t.order)]))
          .get();

  Stream<List<PlanExercise>> watchByPlan(int planId) =>
      (select(planExercises)
        ..where((t) => t.planId.equals(planId))
        ..orderBy([(t) => OrderingTerm.asc(t.order)]))
          .watch();

  Future<int> removeById(int id) =>
      (delete(planExercises)..where((t) => t.id.equals(id))).go();

  /// FK-sicher löschen: Zuerst Referenzen in workout_sets auf NULL, dann Eintrag löschen.
  Future<void> safeRemoveById(int id) async {
    await transaction(() async {
      await (attachedDatabase.update(attachedDatabase.workoutSets)
        ..where((ws) => ws.planExerciseId.equals(id)))
          .write(const WorkoutSetsCompanion(planExerciseId: Value(null)));

      await (attachedDatabase.delete(attachedDatabase.planExercises)
        ..where((t) => t.id.equals(id)))
          .go();
    });
  }

  /// Einzelne Plan-Übung live beobachten (für Notizen-UI)
  Stream<PlanExercise?> watchById(int id) =>
      (select(planExercises)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<bool> updateNotes(int id, String? notes) async {
    final count =
    await (update(planExercises)..where((t) => t.id.equals(id))).write(
      PlanExercisesCompanion(notes: Value(notes)),
    );
    return count > 0;
  }
}


@DriftAccessor(tables: [Workouts])
class WorkoutsDao extends DatabaseAccessor<AppDatabase>
    with _$WorkoutsDaoMixin {
  WorkoutsDao(AppDatabase db) : super(db);

  Future<List<Workout>> completedDesc() =>
      (select(workouts)
        ..where((w) => w.finishedAt.isNotNull())
        ..orderBy([(w) => OrderingTerm.desc(w.finishedAt)]))
          .get();

  Future<int> startWorkout(int? planId) =>
      into(workouts).insert(WorkoutsCompanion.insert(planId: Value(planId)));

  Future<int> deleteById(int id) =>
      (delete(workouts)..where((t) => t.id.equals(id))).go();

  Future<void> finish(int id, DateTime finishedAt) async {
    await transaction(() async {
      await (update(workouts)..where((t) => t.id.equals(id)))
          .write(WorkoutsCompanion(finishedAt: Value(finishedAt)));

      // Alle Sätze ohne actual_weight bekommen target_weight als tatsächliches Gewicht
      await attachedDatabase.customStatement(
        'UPDATE workout_sets SET actual_weight = target_weight '
            'WHERE workout_id = ? AND actual_weight IS NULL',
        [id],
      );
    });
  }
}

@DriftAccessor(tables: [WorkoutSets, Workouts])
class WorkoutSetsDao extends DatabaseAccessor<AppDatabase>
    with _$WorkoutSetsDaoMixin {
  WorkoutSetsDao(AppDatabase db) : super(db);

  /// Einen Satz anlegen
  Future<int> add(WorkoutSetsCompanion data) => into(workoutSets).insert(data);

  /// Alle Sätze eines Workouts (sortiert nach setIndex)
  Future<List<WorkoutSet>> byWorkout(int workoutId) =>
      (select(workoutSets)
        ..where((t) => t.workoutId.equals(workoutId))
        ..orderBy([(t) => OrderingTerm.asc(t.setIndex)]))
          .get();

  /// Live-Stream für Sätze eines Workouts (optional, praktisch für UI)
  Stream<List<WorkoutSet>> watchByWorkout(int workoutId) =>
      (select(workoutSets)
        ..where((t) => t.workoutId.equals(workoutId))
        ..orderBy([(t) => OrderingTerm.asc(t.setIndex)]))
          .watch();

  /// Alle Sätze eines Workouts löschen
  Future<int> removeByWorkout(int workoutId) =>
      (delete(workoutSets)..where((t) => t.workoutId.equals(workoutId))).go();

  /// Ergebnisfelder (Ist-Gewicht / Ist-Wdh) aktualisieren
  Future<bool> updateResult(
      int id, {
        double? actualWeight,
        int? actualReps,
      }) async {
    final count =
    await (update(workoutSets)..where((t) => t.id.equals(id))).write(
      WorkoutSetsCompanion(
        actualWeight:
        actualWeight == null ? const Value.absent() : Value(actualWeight),
        actualReps:
        actualReps == null ? const Value.absent() : Value(actualReps),
      ),
    );
    return count > 0;
  }

  /// Sätze der *letzten ABGESCHLOSSENEN* Session für diese Plan-Übung (sortiert)
  Future<List<WorkoutSet>> lastForPlanExercise(int planExerciseId) async {
    final ws = attachedDatabase.workoutSets;
    final w = attachedDatabase.workouts;

    // 1) letzte finished workout_id für dieses plan_exercise_id suchen
    final row = await attachedDatabase.customSelect(
      '''
      SELECT ws.workout_id
      FROM workout_sets ws
      JOIN workouts w ON w.id = ws.workout_id
      WHERE ws.plan_exercise_id = ?
        AND w.finished_at IS NOT NULL
      ORDER BY w.finished_at DESC, ws.id DESC
      LIMIT 1
      ''',
      variables: [Variable<int>(planExerciseId)],
      readsFrom: {ws, w},
    ).getSingleOrNull();

    if (row == null) return [];

    final lastWorkoutId = row.data['workout_id'] as int;

    // 2) alle Sätze dieser (letzten, abgeschlossenen) Session holen
    return (select(workoutSets)
      ..where((t) =>
      t.planExerciseId.equals(planExerciseId) &
      t.workoutId.equals(lastWorkoutId))
      ..orderBy([(t) => OrderingTerm.asc(t.setIndex)]))
        .get();
  }
}


@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(AppDatabase db) : super(db);

  Future<Setting?> load() async {
    final rows = await select(settings).get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<bool> updateTheme(int mode) async {
    final count = await (update(settings)..where((t) => t.id.equals(1))).write(
      SettingsCompanion(themeMode: Value(mode)),
    );
    return count > 0;
  }
}
