import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/db/db_provider.dart';
import '../../features/workout/service/workout_service.dart';



class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final svc = ref.watch(workoutServiceProvider);


    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Heute',
            key: const Key('title-today'), // <-- Key ergänzt
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final id = await svc.startWorkout();
                  if (context.mounted) context.go('/workout/$id');
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Schnellstart (ohne Plan)'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final plans = await db.plansDao.all();
                  if (!context.mounted) return;
                  final planId = await showDialog<int>(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: const Text('Plan wählen'),
                      children: plans
                          .map((p) => SimpleDialogOption(
                        onPressed: () => Navigator.of(ctx).pop(p.id),
                        child: Text(p.name),
                      ))
                          .toList(),
                    ),
                  );
                  if (planId != null) {
                    final id = await svc.startWorkout(planId: planId);
                    if (context.mounted) context.go('/workout/$id');
                  }
                },
                icon: const Icon(Icons.view_list),
                label: const Text('Plan starten'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}