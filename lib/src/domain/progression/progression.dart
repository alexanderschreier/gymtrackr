/// Simple Rep-Range Progression (z. B. 5–8 Wdh.) mit linearem Gewichtsschritt.
/// Rein fachliche Logik, ohne Flutter/DB-Abhängigkeiten.


class RepRange {
  final int min;
  final int max;
  const RepRange(this.min, this.max) : assert(min > 0), assert(max >= min);
}


class PlanExerciseConfig {
  final int sets; // geplante Satzanzahl
  final RepRange repRange; // Ziel-Rep-Range (z. B. 5–8)
  final double weightStep; // z. B. 2.5 kg
  const PlanExerciseConfig({
    required this.sets,
    required this.repRange,
    required this.weightStep,
  }) : assert(sets > 0), assert(weightStep >= 0);
}


class SetResult {
  final int reps; // erreichte Wdh.
  final double weight; // verwendetes Gewicht
  const SetResult({required this.reps, required this.weight});
}


class NextSetPlan {
  final double weight;
  final int targetRepsMin;
  final int targetRepsMax;
  const NextSetPlan({
    required this.weight,
    required this.targetRepsMin,
    required this.targetRepsMax,
  });
}


class ProgressionDecision {
  final double nextWeight;
  final List<NextSetPlan> sets;
  final String rationale; // kurze Begründung für Debug/Overlay
  const ProgressionDecision({
    required this.nextWeight,
    required this.sets,
    required this.rationale,
  });
}


/// Ermittelt das Ausgangsgewicht aus den letzten Ergebnissen.
/// Strategie: nimm das **häufigste** verwendete Gewicht, sonst max.
double _baselineWeight(List<SetResult> last) {
  if (last.isEmpty) return 0;
  final Map<double, int> freq = {};
  for (final s in last) {
    freq[s.weight] = (freq[s.weight] ?? 0) + 1;
  }
  // most frequent; tie -> higher weight
  double bestW = last.first.weight;
  int bestC = -1;
  for (final e in freq.entries) {
    if (e.value > bestC || (e.value == bestC && e.key > bestW)) {
      bestC = e.value;
      bestW = e.key;
    }
  }
  return bestW;
}


/// Kernlogik:
/// - Wenn **alle** Sätze >= repRange.max: Gewicht + step
/// - Wenn **mind. die Hälfte** der Sätze < repRange.min: Gewicht − step (Deload)
/// - Sonst: Gewicht halten
ProgressionDecision computeNextPlan({
required PlanExerciseConfig config,
required List<SetResult> lastResults,
double? lastPlannedWeight,
}) {
final base = lastResults.isNotEmpty
? _baselineWeight(lastResults)
    : (lastPlannedWeight ?? 0.0);


final total = lastResults.length;
final allHitMax = total > 0 && lastResults.every((s) => s.reps >= config.repRange.max);
final belowMin = lastResults.where((s) => s.reps < config.repRange.min).length;
final halfOrMoreBelow = total > 0 && belowMin >= (config.sets / 2).ceil();


double next = base;
String why;
if (allHitMax && base > 0) {
next = base + config.weightStep;
why = 'alle Sätze ≥ max → +${config.weightStep}';
} else if (halfOrMoreBelow && base > 0) {
next = (base - config.weightStep);
if (next < 0) next = 0;
why = '≥ Hälfte unter min → −${config.weightStep}';
} else {
why = 'halten';
}


final plans = List<NextSetPlan>.generate(
config.sets,
(_) => NextSetPlan(
weight: next,
targetRepsMin: config.repRange.min,
targetRepsMax: config.repRange.max,
),
);


return ProgressionDecision(nextWeight: next, sets: plans, rationale: why);
}

/// Ermittelt Zielgewichte *pro Satz* anhand der letzten Session.
/// Regel:
/// - Wenn reps >= repMax -> +step
/// - Sonst: Gewicht halten
/// - Falls kein Vorwert vorhanden: initial
List<double> computeNextTargetsPerSet({
  required int sets,
  required double step,
  required int repMin, // aktuell ungenutzt, aber für spätere Deload-Logik reserviert
  required int repMax,
  required double initial,
  required Map<int, SetResult> lastByIndex, // key = setIndex (0..n-1)
}) {
  final next = <double>[];
  for (var i = 0; i < sets; i++) {
    final r = lastByIndex[i];
    if (r == null) {
      next.add(initial);
      continue;
    }
    final reps = r.reps;
    final w = r.weight;
    if (reps >= repMax) {
      next.add(w + step);
    } else {
      next.add(w);
    }
  }
  return next;
}
