import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/db/app_database.dart';
import '../../data/db/db_provider.dart';
import 'package:go_router/go_router.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historie')),
      body: FutureBuilder(
        future: Future.wait([
          WorkoutsDao(db).completedDesc(),
          PlansDao(db).all(),
        ]),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final workouts = snap.data![0] as List<Workout>;
          final plans = snap.data![1] as List<Plan>;
          final planMap = {for (final p in plans) p.id: p.name};

          if (workouts.isEmpty) {
            return const Center(child: Text('Noch keine Workouts abgeschlossen.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: workouts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final w = workouts[i];
              final planName = w.planId == null ? 'Ohne Plan' : (planMap[w.planId] ?? 'Plan #${w.planId}');
              final date = w.finishedAt ?? w.startedAt;
              return ListTile(
                title: Text(planName),
                subtitle: Text(date.toString()),
                onTap: () => context.push('/history/${w.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
