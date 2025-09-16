import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/db/app_database.dart';
import '../../data/db/db_provider.dart';
import 'plan_editor_page.dart';
import 'package:go_router/go_router.dart';
import '../workout/workout_session_page.dart';
import '../..//features/workout/service/workout_service.dart';
import 'package:drift/drift.dart' show Value;

enum _PlanAction { rename, delete }


class PlansPage extends ConsumerWidget {
  const PlansPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pläne')),
      body: FutureBuilder<List<Plan>>(
        future: PlansDao(db).all(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('Noch keine Pläne. Lege den ersten an.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = items[i];
              return ListTile(
                title: Text(p.name),
                onTap: () async {
                  // optional: direkt Editor öffnen
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PlanEditorPage(planId: p.id),
                  ));
                  (context as Element).markNeedsBuild();
                },
                // NEU: Play + Settings statt Mülleimer
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Workout starten',
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () async {
                        final svc = ref.read(workoutServiceProvider);
                        final id = await svc.startWorkout(planId: p.id);
                        if (context.mounted) context.go('/workout/$id');
                      },
                    ),
                    IconButton(
                      tooltip: 'Einstellungen',
                      icon: const Icon(Icons.settings),
                      onPressed: () async {
                        final action = await showDialog<_PlanAction>(
                          context: context,
                          builder: (_) => SimpleDialog(
                            title: Text('Plan: ${p.name}'),
                            children: [
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(context, _PlanAction.rename),
                                child: const Text('Umbenennen'),
                              ),
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(context, _PlanAction.delete),
                                child: const Text('Löschen'),
                              ),
                            ],
                          ),
                        );
                        if (action == _PlanAction.rename) {
                          final ctrl = TextEditingController(text: p.name);
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Plan umbenennen'),
                              content: TextField(
                                controller: ctrl,
                                decoration: const InputDecoration(labelText: 'Name'),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
                                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Speichern')),
                              ],
                            ),
                          );
                          if (ok == true && ctrl.text.trim().isNotEmpty) {
                            await PlansDao(ref.read(appDatabaseProvider)).updateById(
                              p.id,
                              PlansCompanion(name: Value(ctrl.text.trim())),
                            );
                            (context as Element).markNeedsBuild();
                          }
                        } else if (action == _PlanAction.delete) {
                          final sure = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Plan löschen?'),
                              content: Text('Dieser Vorgang kann nicht rückgängig gemacht werden.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
                                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
                              ],
                            ),
                          );
                          if (sure == true) {
                            await PlansDao(ref.read(appDatabaseProvider)).deleteById(p.id);
                            (context as Element).markNeedsBuild();
                          }
                        }
                      },
                    ),
                  ],
                ),
              );

            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final controller = TextEditingController();
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Neuen Plan anlegen'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Anlegen')),
              ],
            ),
          );
          if (ok == true && controller.text.trim().isNotEmpty) {
            await PlansDao(ref.read(appDatabaseProvider)).create(
              PlansCompanion.insert(name: controller.text.trim()),
            );
            (context as Element).markNeedsBuild();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Plan'),
      ),
    );
  }
}
