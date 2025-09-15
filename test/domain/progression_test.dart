import 'package:flutter_test/flutter_test.dart';
import 'package:gymtrackr/src/domain/progression/progression.dart';


void main() {
  group('Progression V1', () {
    test('Alle Sätze treffen repMax → Gewicht + step', () {
      final cfg = PlanExerciseConfig(sets: 3, repRange: const RepRange(5, 8), weightStep: 2.5);
      final last = [
        const SetResult(reps: 8, weight: 60),
        const SetResult(reps: 8, weight: 60),
        const SetResult(reps: 8, weight: 60),
      ];
      final res = computeNextPlan(config: cfg, lastResults: last);
      expect(res.nextWeight, 62.5);
      expect(res.sets.length, 3);
      expect(res.sets.first.targetRepsMin, 5);
      expect(res.sets.first.targetRepsMax, 8);
    });


    test('Gemischte Reps → Gewicht halten', () {
      final cfg = PlanExerciseConfig(sets: 3, repRange: const RepRange(5, 8), weightStep: 2.5);
      final last = [
        const SetResult(reps: 7, weight: 60),
        const SetResult(reps: 6, weight: 60),
        const SetResult(reps: 5, weight: 60),
      ];
      final res = computeNextPlan(config: cfg, lastResults: last);
      expect(res.nextWeight, 60);
    });


    test('≥ Hälfte unter repMin → Deload', () {
      final cfg = PlanExerciseConfig(sets: 3, repRange: const RepRange(5, 8), weightStep: 2.5);
      final last = [
        const SetResult(reps: 4, weight: 60),
        const SetResult(reps: 4, weight: 60),
        const SetResult(reps: 6, weight: 60),
      ];
      final res = computeNextPlan(config: cfg, lastResults: last);
      expect(res.nextWeight, 57.5);
    });


    test('Kein letzter Satz → lastPlannedWeight als Basis', () {
      final cfg = PlanExerciseConfig(sets: 3, repRange: const RepRange(5, 8), weightStep: 2.5);
      final res = computeNextPlan(config: cfg, lastResults: const [], lastPlannedWeight: 40);
      expect(res.nextWeight, 40);
      expect(res.sets.length, 3);
    });
  });
}