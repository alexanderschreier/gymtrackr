import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/db/db_provider.dart';
import 'exercise_form_page.dart';

class ExercisesPage extends ConsumerWidget {
  const ExercisesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Übungen'),
      ),
      body: StreamBuilder<List<Exercise>>(
        stream: ExercisesDao(db).watchAll(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = [...snap.data!]
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          if (items.isEmpty) {
            return const Center(child: Text('Noch keine Übungen. Lege die erste an.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final e = items[i];
              return ListTile(
                title: Text(e.name),
                subtitle: Text(e.group ?? '—'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Löschen',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Übung löschen?'),
                        content: Text('„${e.name}“ wirklich löschen?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Abbrechen'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Löschen'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;

                    try {
                      await ExercisesDao(db).deleteById(e.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('„${e.name}“ gelöscht')),
                        );
                      }
                    } catch (err) {
                      final msg = err.toString().contains('FOREIGN KEY')
                          ? 'Kann nicht gelöscht werden: Die Übung wird in Plänen verwendet.'
                          : 'Löschen fehlgeschlagen: $err';
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg)),
                        );
                      }
                    }
                  },
                ),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ExerciseFormPage(edit: e),
                  ));
                  // kein manuelles Rebuild nötig: StreamBuilder aktualisiert sich selbst
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('btn-add-exercise'),
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const ExerciseFormPage(),
          ));
          // kein manuelles Rebuild nötig
        },
        icon: const Icon(Icons.add),
        label: const Text('Hinzufügen'),
      ),
    );
  }
}
