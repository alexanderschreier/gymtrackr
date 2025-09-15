import 'progression.dart';


class ProgressionFacade {
  ProgressionDecision nextFor({
    required int sets,
    required int repMin,
    required int repMax,
    required double step,
    required List<SetResult> last,
    double? lastPlannedWeight,
  }) {
    final cfg = PlanExerciseConfig(
      sets: sets,
      repRange: RepRange(repMin, repMax),
      weightStep: step,
    );
    return computeNextPlan(
      config: cfg,
      lastResults: last,
      lastPlannedWeight: lastPlannedWeight,
    );
  }
}