import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull; // wichtig: vermeidet Namenskonflikt
import 'package:gymtrackr/src/data/db/app_database.dart';

void main() {
  group('DB V1 CRUD & FK', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.test(); // In-Memory => onCreate + Seeds
    });

    tearDown(() async {
      await db.close();
    });

    test('TC-S2.1: Exercises CRUD', () async {
      final exId =
      await db.exercisesDao.create(ExercisesCompanion.insert(name: 'Kreuzheben'));
      expect(exId, greaterThan(0));

      final all = await db.exercisesDao.all();
      expect(all.map((e) => e.name), contains('Kreuzheben'));

      final updated = await db.exercisesDao.updateById(
        exId,
        ExercisesCompanion(notes: const Value('Technik!')),
      );
      expect(updated, true);

      final delCount = await db.exercisesDao.deleteById(exId);
      expect(delCount, 1);
    });

    test('TC-S2.1b: Plans & PlanExercises CRUD + order', () async {
      final planId =
      await db.plansDao.create(PlansCompanion.insert(name: 'GK A'));
      final exId =
      await db.exercisesDao.create(ExercisesCompanion.insert(name: 'Bankdrücken'));

      final peId = await db.planExercisesDao.add(
        PlanExercisesCompanion.insert(
          planId: planId,            // Pflichtfelder -> KEIN Value()
          exerciseId: exId,          // Pflichtfelder -> KEIN Value()
          order: const Value(1),
          sets: const Value(3),
          repMin: const Value(5),
          repMax: const Value(8),
          weightStep: const Value(2.5),
        ),
      );
      expect(peId, greaterThan(0));

      final items = await db.planExercisesDao.byPlan(planId);
      expect(items.length, 1);
      expect(items.first.order, 1);

      final removed = await db.planExercisesDao.removeById(peId);
      expect(removed, 1);
    });

    test('TC-S2.2: FK cascade – deleting workout removes sets', () async {
      final planId =
      await db.plansDao.create(PlansCompanion.insert(name: 'GK B'));
      final exId =
      await db.exercisesDao.create(ExercisesCompanion.insert(name: 'Kniebeuge'));

      final peId = await db.planExercisesDao.add(
        PlanExercisesCompanion.insert(
          planId: planId,           // Pflichtfelder -> KEIN Value()
          exerciseId: exId,         // Pflichtfelder -> KEIN Value()
          order: const Value(1),
        ),
      );

      final wId = await db.workoutsDao.startWorkout(planId);

      await db.workoutSetsDao.add(
        WorkoutSetsCompanion.insert(
          workoutId: wId,           // Pflichtfelder -> KEIN Value()
          planExerciseId: peId,     // Pflichtfelder -> KEIN Value()
          setIndex: 0,              // Pflichtfelder -> KEIN Value()
          targetWeight: const Value(60),
        ),
      );

      final del = await db.workoutsDao.deleteById(wId);
      expect(del, 1);

      final sets = await db.workoutSetsDao.byWorkout(wId);
      expect(sets, isEmpty);
    });

    test('TC-S2.3: Seeds vorhanden (settings + demo exercises)', () async {
      final fresh = AppDatabase.test();
      final settings = await SettingsDao(fresh).load();
      expect(settings, isNotNull);

      final ex = await ExercisesDao(fresh).all();
      expect(ex.length, greaterThanOrEqualTo(2));
      await fresh.close();
    });
  });
}
