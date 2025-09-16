import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../domain/progression/progression_facade.dart';
import '../../../data/db/app_database.dart';
import '../../../data/db/db_provider.dart';
import '../../../domain/progression/progression.dart';


final workoutServiceProvider = Provider<WorkoutService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return WorkoutService(db);
});


class WorkoutService {
  final AppDatabase _db;
  final _progression = ProgressionFacade();
  WorkoutService(this._db);


  /// Startet ein Workout. Wenn [planId] gesetzt ist, werden Sätze per Progression vorbefüllt.
  Future<int> startWorkout({int? planId}) async {
    final workoutId = await _db.workoutsDao.startWorkout(planId);


    if (planId != null) {
// Plan-Übungen holen
      final planItems = await _db.planExercisesDao.byPlan(planId);


      for (final pe in planItems) {
// Letzte Ergebnisse für diese PlanExercise als Basis sammeln
        final lastSets = await _db.customSelect(
          'SELECT * FROM workout_sets WHERE plan_exercise_id = ? ORDER BY id DESC LIMIT ?',
          variables: [Variable.withInt(pe.id), Variable.withInt(5)],
          readsFrom: {_db.workoutSets},
        ).get();


        final last = lastSets.map((row) {
          final w = row.data['actual_weight'] as double? ?? (row.data['target_weight'] as num).toDouble();
          final r = row.data['actual_reps'] as int? ?? 0;
          return SetResult(reps: r, weight: w);
        }).toList();


        final decision = _progression.nextFor(
          sets: pe.sets,
          repMin: pe.repMin,
          repMax: pe.repMax,
          step: pe.weightStep,
          last: last,
          lastPlannedWeight: pe.initialWeight ?? 0,
        );


// Sätze anlegen
        for (var i = 0; i < decision.sets.length; i++) {
          final plan = decision.sets[i];
          await _db.workoutSetsDao.add(WorkoutSetsCompanion.insert(
            workoutId: workoutId,             // bleibt int
            planExerciseId: Value(pe.id),     // <— neu: Value<int?> statt int
            setIndex: i,                      // bleibt int
            targetWeight: Value(plan.weight),
          ));
        }
      }
    }


    return workoutId;
  }
}