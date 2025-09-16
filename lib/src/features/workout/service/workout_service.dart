import 'package:drift/drift.dart' show Value;
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../data/db/db_provider.dart';
import '../../../domain/progression/progression_facade.dart';
import '../../../domain/progression/progression.dart'; // SetResult

/// Riverpod-Provider
final workoutServiceProvider = Provider<WorkoutService>((ref) {
  final db = ref.read(appDatabaseProvider);
  return WorkoutService(db);
});

/// Business-Logik rund um Workouts (Start, Prefill, Updates, Finish)
class WorkoutService {
  WorkoutService(this._db);

  final AppDatabase _db;
  final _progression = ProgressionFacade();

  /// Startet ein Workout. Bei `planId != null` werden Sätze per Progression vorbefüllt.
  Future<int> startWorkout({int? planId}) async {
    final wId = await WorkoutsDao(_db).startWorkout(planId);

    if (planId != null) {
      final items = await PlanExercisesDao(_db).byPlan(planId); // bereits nach order sortiert
      for (final pe in items) {
        // letzte Session *für diese Plan-Übung* holen
        final lastSets = await WorkoutSetsDao(_db).lastForPlanExercise(pe.id);

        // Map pro Satzindex (Ist-Werte bevorzugt, sonst Ziel)
        final Map<int, SetResult> lastByIndex = {
          for (final s in lastSets)
            s.setIndex: SetResult(
              reps: s.actualReps ?? 0,
              weight: s.actualWeight ?? s.targetWeight,
            ),
        };

        final targets = _progression.nextTargetsPerSet(
          sets: pe.sets,
          step: pe.weightStep,
          repMin: pe.repMin,
          repMax: pe.repMax,
          initial: pe.initialWeight ?? 0,
          lastByIndex: lastByIndex,
        );

        for (var i = 0; i < pe.sets; i++) {
          await WorkoutSetsDao(_db).add(WorkoutSetsCompanion.insert(
            workoutId: wId,
            // nullable FK → als Value<int?>
            planExerciseId: Value(pe.id),
            setIndex: i,
            targetWeight: Value(targets[i]),
          ));
        }
      }
    }

    return wId;
  }

  /// Ergebnis eines Satzes speichern (optional Gew./Wdh).
  Future<void> updateResult({
    required int setId,
    double? weight,
    int? reps,
  }) async {
    await WorkoutSetsDao(_db).updateResult(
      setId,
      actualWeight: weight,
      actualReps: reps,
    );
  }

  /// Workout abschließen (setzt finishedAt auf jetzt)
  Future<void> finish(int workoutId) {
    return WorkoutsDao(_db).finish(workoutId, DateTime.now());
  }
}
