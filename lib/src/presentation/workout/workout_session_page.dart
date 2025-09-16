import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/db/app_database.dart';
import '../../data/db/db_provider.dart';
import 'package:go_router/go_router.dart';


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
                await db.workoutsDao.finish(workoutId, DateTime.now());
                if (!context.mounted) return;
                context.go('/');
              },
            ),
          ],
        ),
        body: FutureBuilder<List<WorkoutSet>>(
            future: db.workoutSetsDao.byWorkout(workoutId),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final sets = snap.data!;
              if (sets.isEmpty) {
                return const Center(child: Text('Keine Sätze vorbefüllt.'));
              }
              return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: sets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final s = sets[i];
                    final weightCtrl = TextEditingController(
                        text: (s.actualWeight ?? s.targetWeight).toString());
                    final repsCtrl = TextEditingController(
                        text: (s.actualReps ?? '').toString());
                    return Card(
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                            Text('Satz ${s.setIndex + 1}', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text('Zielgewicht: ${s.targetWeight.toStringAsFixed(1)}'),
                            const SizedBox(height: 8),
                            Row(
                                children: [
                            Expanded(
                            child: TextField(
                            controller: weightCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Gewicht (kg)'),
                                onSubmitted: (v) async {
                                  final w = double.tryParse(v);
                                  await db.workoutSetsDao.updateResult(s.id, actualWeight: w);
                                },
                            ),
                            ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: repsCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Wdh.'),
                                      onSubmitted: (v) async {
                                        final r = int.tryParse(v);
                                        await db.workoutSetsDao.updateResult(s.id, actualReps: r);
                                      },
                                    ),
                                  ),
                                ],
                            ),
                                ],
                            ),
                        ),
                    );
                  },
              );
            },
        ),
    );
  }
}