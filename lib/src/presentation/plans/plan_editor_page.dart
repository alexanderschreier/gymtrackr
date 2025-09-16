import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/db/app_database.dart';
import '../../data/db/db_provider.dart';

class PlanEditorPage extends ConsumerWidget {
  final int planId;
  const PlanEditorPage({super.key, required this.planId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Plan bearbeiten')),
      body: FutureBuilder(
        future: Future.wait([
          PlansDao(db).all(),
          PlanExercisesDao(db).byPlan(planId),
          ExercisesDao(db).all(),
        ]),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final planExercises = snap.data![1] as List<PlanExercise>;
          final exercises = snap.data![2] as List<Exercise>;
          exercises.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('btn-add-plan-exercise'),
                      onPressed: () async {
                        if (exercises.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Keine Übungen vorhanden. Lege erst Übungen an.')),
                          );
                          return;
                        }
                        final chosen = await showDialog<Exercise>(
                          context: context,
                          builder: (_) => SimpleDialog(
                            title: const Text('Übung hinzufügen'),
                            children: exercises
                                .map((e) => SimpleDialogOption(
                              onPressed: () => Navigator.pop(context, e),
                              child: Text(e.name),
                            ))
                                .toList(),
                          ),
                        );
                        if (chosen != null) {
                          await PlanExercisesDao(db).add(PlanExercisesCompanion.insert(
                            planId: planId,
                            exerciseId: chosen.id,
                            order: const Value(1),
                            sets: const Value(3),
                            repMin: const Value(5),
                            repMax: const Value(8),
                            weightStep: const Value(2.5),
                          ));
                          (context as Element).markNeedsBuild();
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Übung hinzufügen'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (planExercises.isEmpty)
                const Text('Noch keine Übungen im Plan.')
              else
                ...planExercises.map((pe) => Card(
                  child: ListTile(
                    title: Text('ID ${pe.exerciseId} – Satz ${pe.sets} • ${pe.repMin}-${pe.repMax} • Step ${pe.weightStep}'),
                    subtitle: Text('Reihenfolge: ${pe.order}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        await PlanExercisesDao(db).removeById(pe.id);
                        (context as Element).markNeedsBuild();
                      },
                    ),
                  ),
                )),
            ],
          );
        },
      ),
    );
  }
}
