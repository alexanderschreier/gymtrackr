import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/db/app_database.dart';
import '../../data/db/db_provider.dart';
import 'plan_editor_page.dart';

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
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PlanEditorPage(planId: p.id),
                  ));
                  (context as Element).markNeedsBuild();
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    await PlansDao(db).deleteById(p.id);
                    (context as Element).markNeedsBuild();
                  },
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
