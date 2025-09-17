import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../data/db/app_database.dart';
import '../../data/db/db_provider.dart';

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
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Workout beenden?'),
                  content: const Text('Möchtest du dieses Workout wirklich abschließen?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Abbrechen'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Beenden'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;

              await db.workoutsDao.finish(workoutId, DateTime.now());
              if (!context.mounted) return;
              context.go('/?tab=plans');
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: () async {
          final sets = await WorkoutSetsDao(db).byWorkout(workoutId);
          if (sets.isEmpty) {
            return {
              'grouped': <int, List<WorkoutSet>>{},
              'exById': <int, Exercise>{},
              'peById': <int, PlanExercise>{},
              'orphan': <WorkoutSet>[],
            };
          }

          final withPe = sets.where((s) => s.planExerciseId != null).toList();
          final orphan = sets.where((s) => s.planExerciseId == null).toList();

          final Map<int, List<WorkoutSet>> grouped = {};
          Map<int, Exercise> exById = {};
          Map<int, PlanExercise> peById = {};

          if (withPe.isNotEmpty) {
            final peIds = withPe.map((s) => s.planExerciseId!).toSet().toList();
            final pes = await PlanExercisesDao(db).byIds(peIds);
            peById = {for (final pe in pes) pe.id: pe};

            final exIds = pes.map((pe) => pe.exerciseId).toSet().toList();
            final exs = await ExercisesDao(db).byIds(exIds);
            exById = {for (final e in exs) e.id: e};

            for (final s in withPe) {
              final exId = peById[s.planExerciseId!]!.exerciseId;
              grouped.putIfAbsent(exId, () => []).add(s);
            }
            for (final list in grouped.values) {
              list.sort((a, b) => a.setIndex.compareTo(b.setIndex));
            }
          }

          return {
            'grouped': grouped,
            'exById': exById,
            'peById': peById,
            'orphan': orphan,
          };
        }(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data! as Map;
          final grouped = data['grouped'] as Map<int, List<WorkoutSet>>;
          final exById = data['exById'] as Map<int, Exercise>;
          final peById = data['peById'] as Map<int, PlanExercise>;

          if (grouped.isEmpty) {
            return const Center(child: Text('Keine Sätze vorbefüllt.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: grouped.entries.map((entry) {
              final exId = entry.key;
              final exName = exById[exId]?.name ?? 'Übung #$exId';
              final sets = entry.value;

              // PlanExercise-ID der ersten Zeile dieser Übung (für Notizen)
              final peId = (sets.isNotEmpty ? sets.first.planExerciseId : null);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exName, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),

                      // Notizen live (nur wenn PlanExercise vorhanden) — einklappbar
                      if (peId != null) ...[
                        StreamBuilder<PlanExercise?>(
                          stream: PlanExercisesDao(db).watchById(peId),
                          builder: (context, peSnap) {
                            final peLive = peSnap.data; // kann null werden, falls gelöscht
                            final notesText = (peLive?.notes ?? '').trim();

                            return ExpansionTile(
                              title: const Text('Notizen'),
                              subtitle: notesText.isNotEmpty
                                  ? Text(
                                notesText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              )
                                  : const Text('Keine Notizen'),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: _NotesEditor(
                                    initial: notesText, // ← immer aktueller DB-Wert
                                    onSave: (txt) async {
                                      final ok = await PlanExercisesDao(db).updateNotes(
                                        peId,
                                        txt.trim().isEmpty ? null : txt.trim(),
                                      );
                                      if (ok && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Notizen gespeichert')),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Sätze
                      ...sets.map((s) {
                        final weightCtrl = TextEditingController(
                          text: (s.actualWeight ?? s.targetWeight).toString(),
                        );
                        final repsCtrl = TextEditingController(
                          text: s.actualReps?.toString() ?? '',
                        );

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              SizedBox(width: 64, child: Text('Satz ${s.setIndex + 1}')),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: weightCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textInputAction: TextInputAction.done,
                                  decoration: const InputDecoration(labelText: 'Gewicht (kg)'),
                                  onChanged: (v) async {
                                    final w = double.tryParse(v.replaceAll(',', '.'));
                                    if (w != null) {
                                      await WorkoutSetsDao(db).updateResult(s.id, actualWeight: w);
                                    }
                                  },
                                  onSubmitted: (v) async {
                                    final w = double.tryParse(v.replaceAll(',', '.'));
                                    await WorkoutSetsDao(db).updateResult(s.id, actualWeight: w);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: repsCtrl,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  decoration: const InputDecoration(labelText: 'Wdh'),
                                  onChanged: (v) async {
                                    final r = int.tryParse(v);
                                    if (r != null) {
                                      final parsedWeight = double.tryParse(weightCtrl.text.replaceAll(',', '.'));
                                      await WorkoutSetsDao(db).updateResult(
                                        s.id,
                                        actualReps: r,
                                        // falls bisher kein actualWeight gesetzt: nimm Tippfeld -> sonst target
                                        actualWeight: parsedWeight ?? s.actualWeight ?? s.targetWeight,
                                      );
                                    }
                                  },
                                  onSubmitted: (v) async {
                                    final r = int.tryParse(v);
                                    final parsedWeight = double.tryParse(weightCtrl.text.replaceAll(',', '.'));
                                    await WorkoutSetsDao(db).updateResult(
                                      s.id,
                                      actualReps: r,
                                      actualWeight: parsedWeight ?? s.actualWeight ?? s.targetWeight,
                                    );
                                  },
                                ),
                              ),

                              const Spacer(),
                              Text('Ziel: ${s.targetWeight.toStringAsFixed(1)}'),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _NotesEditor extends StatefulWidget {
  final String initial;
  final Future<void> Function(String text) onSave;
  const _NotesEditor({required this.initial, required this.onSave});

  @override
  State<_NotesEditor> createState() => _NotesEditorState();
}

class _NotesEditorState extends State<_NotesEditor> {
  late final TextEditingController _c;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
  }

  @override
  void didUpdateWidget(covariant _NotesEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial != widget.initial) {
      _c.text = widget.initial; // Sync mit Stream-Update
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _c,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Notizen',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving
                ? null
                : () async {
              setState(() => _saving = true);
              try {
                await widget.onSave(_c.text);
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            },
            icon: const Icon(Icons.save),
            label: Text(_saving ? 'Speichern…' : 'Speichern'),
          ),
        ),
      ],
    );
  }
}
