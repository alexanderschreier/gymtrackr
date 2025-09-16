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
      body: StreamBuilder<List<PlanExercise>>(
        stream: peDao.watchByPlan(planId),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final planExercises = snap.data!;
          return FutureBuilder<List<Exercise>>(
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
                            // 1) Übung wählen (alphabetisch)
                            final sorted = [...exercises]
                              ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                            final chosen = await showDialog<Exercise>(
                              context: context,
                              builder: (_) => SimpleDialog(
                                title: const Text('Übung wählen'),
                                children: sorted
                                    .map((e) => SimpleDialogOption(
                                  onPressed: () => Navigator.pop(context, e),
                                  child: Text(e.name),
                                ))
                                    .toList(),
                              ),
                            );
                            if (chosen == null) return;

                            // 2) Konfiguration erfassen
                            final setsCtrl = TextEditingController(text: '3');
                            final repMinCtrl = TextEditingController(text: '5');
                            final repMaxCtrl = TextEditingController(text: '8');
                            final stepCtrl = TextEditingController(text: '2.5');
                            final initCtrl = TextEditingController(text: '20');
                            final notesCtrl = TextEditingController();

                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text('Einstellungen – ${chosen.name}'),
                                content: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: setsCtrl,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(labelText: 'Sätze'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: stepCtrl,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: const InputDecoration(labelText: 'Gewichtsschritt (kg)'),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: repMinCtrl,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(labelText: 'Rep min'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: repMaxCtrl,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(labelText: 'Rep max'),
                                            ),
                                          ),
                                        ],
                                      ),
                                      TextField(
                                        controller: initCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(labelText: 'Startgewicht (kg)'),
                                      ),
                                      TextField(
                                        controller: notesCtrl,
                                        decoration: const InputDecoration(labelText: 'Notizen (optional)'),
                                        maxLines: 3,
                                      ),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
                                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hinzufügen')),
                                ],
                              ),
                            );
                            if (ok != true) return;

                            final sets = int.tryParse(setsCtrl.text) ?? 3;
                            final repMin = int.tryParse(repMinCtrl.text) ?? 5;
                            final repMax = int.tryParse(repMaxCtrl.text) ?? 8;
                            final step = double.tryParse(stepCtrl.text) ?? 2.5;
                            final init = double.tryParse(initCtrl.text) ?? 20;
                            final notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();

                            await peDao.add(PlanExercisesCompanion.insert(
                              planId: planId,
                              exerciseId: chosen.id,
                              order: const Value(1),
                              sets: Value(sets),
                              repMin: Value(repMin),
                              repMax: Value(repMax),
                              weightStep: Value(step),
                              initialWeight: Value(init),
                              notes: Value(notes),
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
                          subtitle: Text(
                            [
                              'Start: ${(pe.initialWeight ?? 0).toStringAsFixed(1)} kg',
                              'Reihenfolge: ${pe.order}',
                              if ((pe.notes ?? '').isNotEmpty) 'Notizen: ${pe.notes}',
                            ].join(' • '),
                          ),
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
