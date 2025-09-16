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
      body: FutureBuilder<List<Exercise>>(
        future: ExercisesDao(db).all(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
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
                    await ExercisesDao(db).deleteById(e.id);
                    (context as Element).markNeedsBuild();
                  },
                ),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ExerciseFormPage(edit: e),
                  ));
                  (context as Element).markNeedsBuild();
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
          if (context.mounted) (context as Element).markNeedsBuild();
        },
        icon: const Icon(Icons.add),
        label: const Text('Hinzufügen'),
      ),
    );
  }
}
