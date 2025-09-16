import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/db/app_database.dart';
import '../../data/db/db_provider.dart';

class WorkoutDetailPage extends ConsumerWidget {
  final int workoutId;
  const WorkoutDetailPage({super.key, required this.workoutId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Workout #$workoutId')),
      body: FutureBuilder(
        future: () async {
          final sets = await WorkoutSetsDao(db).byWorkout(workoutId);

          final withPe = sets.where((s) => s.planExerciseId != null).toList();
          final orphan = sets.where((s) => s.planExerciseId == null).toList();

          Map<int, Exercise> exById = {};
          Map<int, List<WorkoutSet>> grouped = {};

          if (withPe.isNotEmpty) {
            final peIds = withPe.map((s) => s.planExerciseId!).toSet().toList();
            final planExercises = await PlanExercisesDao(db).byIds(peIds);
            final exIds = planExercises.map((pe) => pe.exerciseId).toSet().toList();
            final exercises = await ExercisesDao(db).byIds(exIds);

            final peById = {for (final pe in planExercises) pe.id: pe};
            exById = {for (final e in exercises) e.id: e};

            for (final s in withPe) {
              final exId = peById[s.planExerciseId!]!.exerciseId;
              grouped.putIfAbsent(exId, () => []).add(s);
            }
            // sortiere Sätze
            for (final list in grouped.values) {
              list.sort((a, b) => a.setIndex.compareTo(b.setIndex));
            }
          }

          return {'grouped': grouped, 'exById': exById, 'orphan': orphan};
        }(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = snap.data! as Map;
          final grouped = data['grouped'] as Map<int, List<WorkoutSet>>;
          final exById = data['exById'] as Map<int, Exercise>;
          final orphan = data['orphan'] as List<WorkoutSet>;

          final children = <Widget>[];

          // Bekannte Übungen
          for (final entry in grouped.entries) {
            final exName = exById[entry.key]?.name ?? 'Übung #${entry.key}';
            final sets = entry.value;
            children.add(
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exName, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...sets.map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Satz ${s.setIndex + 1}'),
                            Text('Ziel: ${s.targetWeight.toStringAsFixed(1)} kg'),
                            Text('Ist: ${(s.actualWeight ?? 0).toStringAsFixed(1)} kg / ${s.actualReps ?? 0} Wdh'),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            );
          }

          // Waisen-Sätze (Plan/Übung gelöscht)
          if (orphan.isNotEmpty) {
            orphan.sort((a, b) => a.setIndex.compareTo(b.setIndex));
            children.add(
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Archivierte Sätze', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...orphan.map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Satz ${s.setIndex + 1}'),
                            Text('Ziel: ${s.targetWeight.toStringAsFixed(1)} kg'),
                            Text('Ist: ${(s.actualWeight ?? 0).toStringAsFixed(1)} kg / ${s.actualReps ?? 0} Wdh'),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            );
          }

          return ListView(padding: const EdgeInsets.all(12), children: children);
        },
      ),

    );
  }
}
