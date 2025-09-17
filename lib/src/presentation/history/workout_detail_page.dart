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
          final all = await WorkoutSetsDao(db).byWorkout(workoutId);

          final sets = all.where((s) => s.isDone == true).toList();

          final withPe = sets.where((s) => s.planExerciseId != null).toList();
          final orphan = sets.where((s) => s.planExerciseId == null).toList();

          Map<int, Exercise> exById = {};
          Map<int, PlanExercise> peById = {};
          final Map<int, List<WorkoutSet>> grouped = {};

          if (withPe.isNotEmpty) {
            final peIds = withPe.map((s) => s.planExerciseId!).toSet().toList();
            final pes = await PlanExercisesDao(db).byIds(peIds);
            peById = {for (final pe in pes) pe.id: pe};

            final exIds = pes.map((pe) => pe.exerciseId).toSet().toList();
            final exs = await ExercisesDao(db).byIds(exIds);
            exById = {for (final e in exs) e.id: e};

            for (final s in withPe) {
              final exId = peById[s.planExerciseId!]!.exerciseId;
              grouped.putIfAbsent(exId, () => []).add(s);
            }
            for (final list in grouped.values) {
              list.sort((a, b) => a.setIndex.compareTo(b.setIndex));
            }
          }

          orphan.sort((a, b) => a.setIndex.compareTo(b.setIndex));

          return {
            'grouped': grouped,
            'exById': exById,
            'orphan': orphan,
          };
        }(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data! as Map;
          final grouped = data['grouped'] as Map<int, List<WorkoutSet>>;
          final exById = data['exById'] as Map<int, Exercise>;
          final orphan = data['orphan'] as List<WorkoutSet>;

          final children = <Widget>[];

          // Bekannte Übungen (mit PlanExercise)
          for (final entry in grouped.entries) {
            final exId = entry.key;
            final exName = exById[exId]?.name ?? 'Übung #$exId';
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
                      ...sets.map((s) {
                        final w = s.actualWeight ?? s.targetWeight;
                        final r = s.actualReps;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Satz ${s.setIndex + 1}'),
                              // Nur IST anzeigen, kein Ziel – keine 0-Defaults
                              Text('Gewicht: ${w.toStringAsFixed(1)} kg'),
                              Text('Wdh: ${r?.toString() ?? '–'}'),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            );
          }

          // Waisen-Sätze (Plan/Übung gelöscht)
          if (orphan.isNotEmpty) {
            children.add(
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Archivierte Sätze', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...orphan.map((s) {
                        final w = s.actualWeight ?? s.targetWeight;
                        final r = s.actualReps;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Satz ${s.setIndex + 1}'),
                              Text('Gewicht: ${w.toStringAsFixed(1)} kg'),
                              Text('Wdh: ${r?.toString() ?? '–'}'),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            );
          }

          if (children.isEmpty) {
            return const Center(child: Text('Keine Daten.'));
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: children,
          );
        },
      ),
    );
  }
}
