import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/db/db_provider.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  bool _selectionMode = false;
  final Set<int> _selected = <int>{};

  void _enterSelection(int id) {
    setState(() {
      _selectionMode = true;
      _toggleSelected(id);
    });
  }

  void _toggleSelected(int id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    if (_selected.isEmpty) _selectionMode = false;
    setState(() {});
  }

  void _clearSelection() {
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);

    return WillPopScope(
      onWillPop: () async {
        if (_selectionMode) {
          _clearSelection();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: _selectionMode
              ? Text('${_selected.length} ausgewählt')
              : const Text('Historie'),
          leading: _selectionMode
              ? IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Auswahl aufheben',
            onPressed: _clearSelection,
          )
              : null,
          actions: _selectionMode
              ? [
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Alle markieren',
              onPressed: () async {
                // Stream liefert unten die aktuelle Liste; wir füllen in setState,
                // sobald die ListView schon Daten hat.
                // Hier nutzen wir einen kleinen Trick: Wir warten den nächsten Frame ab
                // und greifen dann auf das zuletzt gerenderte Snapshot-Ergebnis zu,
                // indem wir _selectAllFromCache verwenden (siehe unten).
                // Einfacher: wir triggern unten via GlobalKey.
                // Für Klarheit implementieren wir es pragmatisch: wir lassen
                // die ListView selbst die Auswahl setzen (s. Builder).
                // -> Hier toggeln wir nur ein Flag, die Auswahl passiert im Builder.
                // Da das komplizierter wird, machen wir es simpel:
                // Wir fragen die DB direkt nach allen IDs.
                final all = await db.workoutsDao.completedDesc();
                setState(() {
                  if (_selected.length == all.length) {
                    _selected.clear();
                    _selectionMode = false;
                  } else {
                    _selected
                      ..clear()
                      ..addAll(all.map((w) => w.id));
                    _selectionMode = true;
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Löschen',
              onPressed: _selected.isEmpty
                  ? null
                  : () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Einträge löschen?'),
                    content: Text(
                      _selected.length == 1
                          ? 'Diesen Eintrag wirklich löschen?'
                          : '${_selected.length} Einträge wirklich löschen?',
                    ),
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
                if (ok != true) return;
                final count = await db.workoutsDao.deleteByIds(_selected.toList());
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$count Eintrag(e) gelöscht')),
                );
                _clearSelection();
              },
            ),
          ]
              : null,
        ),
        body: StreamBuilder<List<Workout>>(
          stream: db.workoutsDao.watchCompletedDesc(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snap.data!;
            if (items.isEmpty) {
              return const Center(child: Text('Noch keine abgeschlossenen Workouts.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final w = items[i];
                final isSelected = _selected.contains(w.id);
                final title = 'Workout #${w.id}';
                final sub = w.finishedAt?.toLocal().toString() ?? '';

                return ListTile(
                  selected: isSelected,
                  selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  leading: _selectionMode
                      ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelected(w.id),
                  )
                      : const Icon(Icons.history),
                  title: Text(title),
                  subtitle: Text(sub),
                  onTap: () {
                    if (_selectionMode) {
                      _toggleSelected(w.id);
                    } else {
                      context.push('/history/${w.id}');
                    }
                  },
                  onLongPress: () => _enterSelection(w.id),
                  trailing: !_selectionMode
                      ? IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Löschen',
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Workout löschen?'),
                          content: const Text(
                            'Dieses Workout wird aus der Historie entfernt.',
                          ),
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
                      if (ok == true) {
                        await db.workoutsDao.deleteByIds([w.id]);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Workout gelöscht')),
                        );
                      }
                    },
                  )
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
