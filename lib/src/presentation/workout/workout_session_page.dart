import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/db/app_database.dart';
import '../../data/db/db_provider.dart';

class WorkoutSessionPage extends ConsumerWidget {
  final int workoutId;
  const WorkoutSessionPage({super.key, required this.workoutId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Workout #$workoutId'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Workout abschließen',
            onPressed: () async {
              // Bestätigen
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Workout beenden?'),
                  content: const Text('Möchtest du dieses Workout wirklich abschließen?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Beenden')),
                  ],
                ),
              );
              if (ok != true) return;

              await db.workoutsDao.finish(workoutId, DateTime.now());
              if (!context.mounted) return;
              context.go('/plans'); // zurück zu Pläne
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: () async {
          final sets = await WorkoutSetsDao(db).byWorkout(workoutId);
          if (sets.isEmpty) return {'grouped': <int, List<WorkoutSet>>{}, 'exById': <int, Exercise>{}};

          final peIds = sets.map((s) => s.planExerciseId).whereType<int>().toSet().toList();
          final pes = await PlanExercisesDao(db).byIds(peIds);
          final exIds = pes.map((pe) => pe.exerciseId).toSet().toList();
          final exs = await ExercisesDao(db).byIds(exIds);

          final peById = {for (final pe in pes) pe.id: pe};
          final exById = {for (final e in exs) e.id: e};

          final Map<int, List<WorkoutSet>> grouped = {};
          for (final s in sets) {
            final exId = peById[s.planExerciseId]!.exerciseId;
            grouped.putIfAbsent(exId, () => []).add(s);
          }
          // sortiere Sätze
          for (final list in grouped.values) {
            list.sort((a, b) => a.setIndex.compareTo(b.setIndex));
          }
          return {'grouped': grouped, 'exById': exById};
        }(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = snap.data! as Map;
          final grouped = data['grouped'] as Map<int, List<WorkoutSet>>;
          final exById = data['exById'] as Map<int, Exercise>;

          if (grouped.isEmpty) return const Center(child: Text('Keine Sätze vorbefüllt.'));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: grouped.entries.map((entry) {
              final exName = exById[entry.key]?.name ?? 'Übung #${entry.key}';
              final sets = entry.value;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exName, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...sets.map((s) {
                        final weightCtrl = TextEditingController(text: (s.actualWeight ?? s.targetWeight).toString());
                        final repsCtrl = TextEditingController(text: (s.actualReps ?? '').toString());
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              SizedBox(width: 64, child: Text('Satz ${s.setIndex + 1}')),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: weightCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Gewicht (kg)'),
                                  onSubmitted: (v) async {
                                    final w = double.tryParse(v);
                                    await WorkoutSetsDao(db).updateResult(s.id, actualWeight: w);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: repsCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Wdh'),
                                  onSubmitted: (v) async {
                                    final r = int.tryParse(v);
                                    await WorkoutSetsDao(db).updateResult(s.id, actualReps: r);
                                  },
                                ),
                              ),
                              const Spacer(),
                              Text('Ziel: ${s.targetWeight.toStringAsFixed(1)}'),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
