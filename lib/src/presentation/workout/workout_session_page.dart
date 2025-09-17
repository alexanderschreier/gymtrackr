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
      // WICHTIG: Stream für Live-Updates (Gewicht, Reps, isDone)
      body: StreamBuilder<List<WorkoutSet>>(
        stream: WorkoutSetsDao(db).watchByWorkout(workoutId),
        builder: (context, setSnap) {
          if (!setSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final setsAll = setSnap.data!;
          if (setsAll.isEmpty) {
            return const Center(child: Text('Keine Sätze vorbefüllt.'));
          }

          final withPe = setsAll.where((s) => s.planExerciseId != null).toList();
          final Map<int, List<WorkoutSet>> grouped = {};
          for (final s in withPe) {
            grouped.putIfAbsent(s.planExerciseId!, () => []).add(s);
          }
          for (final list in grouped.values) {
            list.sort((a, b) => a.setIndex.compareTo(b.setIndex));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: grouped.entries.map((entry) {
              final peId = entry.key;
              final sets = entry.value;

              return FutureBuilder<Map<String, dynamic>>(
                future: () async {
                  // Daten für Kopfzeile (Übungsname)
                  final pe = (await PlanExercisesDao(db).byIds([peId])).firstOrNull;
                  final ex = pe == null ? null : (await ExercisesDao(db).byIds([pe.exerciseId])).firstOrNull;

                  // Vorherige (letzte fertige) Session dieser Plan-Übung
                  final prev = await WorkoutSetsDao(db).lastForPlanExercise(peId);
                  final Map<int, WorkoutSet> prevByIndex = {
                    for (final s in prev) s.setIndex: s
                  };

                  return {
                    'pe': pe,
                    'ex': ex,
                    'prevByIndex': prevByIndex,
                  };
                }(),
                builder: (context, snap2) {
                  if (!snap2.hasData) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: LinearProgressIndicator(),
                      ),
                    );
                  }
                  final pe = snap2.data!['pe'] as PlanExercise?;
                  final ex = snap2.data!['ex'] as Exercise?;
                  final prevByIndex = snap2.data!['prevByIndex'] as Map<int, WorkoutSet>;
                  final exName = ex?.name ?? 'Übung #${pe?.exerciseId ?? '?'}';

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(exName, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),

                          // Notizen live (nur wenn PlanExercise vorhanden) — einklappbar
                          StreamBuilder<PlanExercise?>(
                            stream: PlanExercisesDao(db).watchById(peId),
                            builder: (context, peSnap) {
                              final peLive = peSnap.data;
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
                                      initial: notesText,
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

                          // Sätze (mit Checkbox & Vergleich)
                          ...sets.map((s) {
                            final weightCtrl = TextEditingController(
                              text: (s.actualWeight ?? s.targetWeight).toString(),
                            );
                            final repsCtrl = TextEditingController(
                              text: s.actualReps?.toString() ?? '',
                            );

                            // Vorherige Werte für diesen Satzindex
                            final prev = prevByIndex[s.setIndex];
                            final prevW = prev == null ? null : (prev.actualWeight ?? prev.targetWeight);
                            final prevR = prev?.actualReps;

                            Color _trendColor(double nowW, int nowR, double? lastW, int? lastR) {
                              if (lastW == null || lastR == null) return Colors.grey;
                              // Gewicht berücksichtigt:
                              if (nowW > lastW && nowR >= lastR) return Colors.green;
                              if (nowW > lastW && nowR < lastR) return Colors.orange; // neutral bei Upweight + fewer reps
                              if (nowW == lastW && nowR > lastR) return Colors.green;
                              if (nowW == lastW && nowR == lastR) return Colors.grey;
                              if (nowW < lastW && nowR >= lastR) return Colors.orange; // neutral
                              return Colors.red;
                            }

                            Future<void> _trySetDone(bool newVal) async {
                              if (newVal == false) {
                                await WorkoutSetsDao(db).setDone(s.id, false);
                                return;
                              }
                              // Aktivieren NUR wenn Gewicht & Reps gesetzt:
                              final parsedW = double.tryParse(weightCtrl.text.replaceAll(',', '.')) ?? s.actualWeight ?? s.targetWeight;
                              final parsedR = int.tryParse(repsCtrl.text);
                              if (parsedW == null || parsedR == null) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Bitte zuerst Gewicht und Wdh eintragen.')),
                                  );
                                }
                                return;
                              }
                              // persistiere aktuelle Werte (falls noch nicht)
                              await WorkoutSetsDao(db).updateResult(s.id, actualWeight: parsedW, actualReps: parsedR);
                              await WorkoutSetsDao(db).setDone(s.id, true);
                            }

                            final nowW = (s.actualWeight ?? s.targetWeight);
                            final nowR = s.actualReps;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(width: 56, child: Text('Satz ${s.setIndex + 1}')),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: weightCtrl,
                                          enabled: !(s.isDone),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          textInputAction: TextInputAction.done,
                                          decoration: const InputDecoration(labelText: 'Gewicht (kg)'),
                                          onChanged: (v) async {
                                            if (s.isDone) return;
                                            final w = double.tryParse(v.replaceAll(',', '.'));
                                            if (w != null) {
                                              await WorkoutSetsDao(db).updateResult(s.id, actualWeight: w);
                                            }
                                          },
                                          onSubmitted: (v) async {
                                            if (s.isDone) return;
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
                                          enabled: !(s.isDone),
                                          keyboardType: TextInputType.number,
                                          textInputAction: TextInputAction.done,
                                          decoration: const InputDecoration(labelText: 'Wdh'),
                                          onChanged: (v) async {
                                            if (s.isDone) return;
                                            final r = int.tryParse(v);
                                            if (r != null) {
                                              final parsedWeight = double.tryParse(weightCtrl.text.replaceAll(',', '.'));
                                              await WorkoutSetsDao(db).updateResult(
                                                s.id,
                                                actualReps: r,
                                                actualWeight: parsedWeight ?? s.actualWeight ?? s.targetWeight,
                                              );
                                            }
                                          },
                                          onSubmitted: (v) async {
                                            if (s.isDone) return;
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
                                      const SizedBox(width: 8),
                                      Checkbox(
                                        value: s.isDone,
                                        onChanged: (val) => _trySetDone(val ?? false),
                                      ),
                                    ],
                                  ),

                                  // Ziel-Anzeige und – falls erledigt – Performance-Vergleich
                                  Row(
                                    children: [
                                      Text('Ziel: ${s.targetWeight.toStringAsFixed(1)}'),
                                      const Spacer(),
                                      if (s.isDone && nowW != null && nowR != null)
                                        Row(
                                          children: [
                                            const Text('Letztes Mal: '),
                                            Text(
                                              (prevW != null ? '${prevW.toStringAsFixed(1)} kg' : '–') +
                                                  (prevR != null ? ' × $prevR' : ''),
                                              style: TextStyle(
                                                color: _trendColor(nowW, nowR, prevW, prevR),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
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
