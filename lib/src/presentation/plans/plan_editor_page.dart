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
    final peDao = PlanExercisesDao(db);
    final exDao = ExercisesDao(db);

    return Scaffold(
      appBar: AppBar(title: const Text('Plan bearbeiten')),
      body: StreamBuilder<List<PlanExercise>>(                            // Stream: sofortiges Update
        stream: peDao.watchByPlan(planId),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final planExercises = snap.data!;
          return FutureBuilder<List<Exercise>>(                           // Übungen laden (Name anzeigen)
            future: exDao.all(),
            builder: (context, exSnap) {
              if (!exSnap.hasData) return const Center(child: CircularProgressIndicator());
              final exercises = exSnap.data!;
              final exById = {for (final e in exercises) e.id: e};

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('btn-add-plan-exercise'),
                          onPressed: () async {
                            // Auswahl der Übung (alphabetisch)
                            final sorted = [...exercises]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                            final chosen = await showDialog<Exercise>(
                              context: context,
                              builder: (_) => SimpleDialog(
                                title: const Text('Übung hinzufügen'),
                                children: sorted
                                    .map((e) => SimpleDialogOption(
                                  onPressed: () => Navigator.pop(context, e),
                                  child: Text(e.name),
                                ))
                                    .toList(),
                              ),
                            );
                            if (chosen == null) return;

                            // Startgewicht abfragen (Default 20 kg)
                            final ctrl = TextEditingController(text: '20');
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text('Startgewicht für ${chosen.name}'),
                                content: TextField(
                                  controller: ctrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'kg'),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
                                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hinzufügen')),
                                ],
                              ),
                            );
                            if (ok != true) return;
                            final initW = double.tryParse(ctrl.text) ?? 20;

                            await peDao.add(PlanExercisesCompanion.insert(
                              planId: planId,
                              exerciseId: chosen.id,
                              order: const Value(1),
                              sets: const Value(3),
                              repMin: const Value(5),
                              repMax: const Value(8),
                              weightStep: const Value(2.5),
                              initialWeight: Value(initW),                  // ← wichtig: kein 0-Ziel
                            ));
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
                    ...planExercises.map((pe) {
                      final ex = exById[pe.exerciseId];
                      final title = ex?.name ?? 'Übung #${pe.exerciseId}';
                      return Card(
                        child: ListTile(
                          title: Text('$title • ${pe.sets} Sätze • ${pe.repMin}-${pe.repMax} Wdh • Step ${pe.weightStep}'),
                          subtitle: Text('Start: ${(pe.initialWeight ?? 0).toStringAsFixed(1)} kg • Reihenfolge: ${pe.order}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              await peDao.removeById(pe.id);
                            },
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
