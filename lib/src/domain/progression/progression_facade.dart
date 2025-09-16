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

  List<double> nextTargetsPerSet({
    required int sets,
    required double step,
    required int repMin,
    required int repMax,
    required double initial,
    required Map<int, SetResult> lastByIndex,
  }) {
    return computeNextTargetsPerSet(
      sets: sets,
      step: step,
      repMin: repMin,
      repMax: repMax,
      initial: initial,
      lastByIndex: lastByIndex,
    );
  }
}