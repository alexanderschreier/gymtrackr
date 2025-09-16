import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/db/app_database.dart';
import '../../data/db/db_provider.dart';
import 'package:drift/drift.dart' show Value;

class ExerciseFormPage extends ConsumerStatefulWidget {
  final Exercise? edit;
  const ExerciseFormPage({super.key, this.edit});

  @override
  ConsumerState<ExerciseFormPage> createState() => _ExerciseFormPageState();
}

class _ExerciseFormPageState extends ConsumerState<ExerciseFormPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _group = TextEditingController();
  final _step = TextEditingController(text: '2.5');
  final _repMin = TextEditingController(text: '5');
  final _repMax = TextEditingController(text: '8');
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _name.text = e.name;
      _group.text = e.group ?? '';
      _step.text = e.defaultWeightStep.toString();
      _repMin.text = e.defaultRepMin.toString();
      _repMax.text = e.defaultRepMax.toString();
      _notes.text = e.notes ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    final isEdit = widget.edit != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Übung bearbeiten' : 'Übung anlegen')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('tf-ex-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name*'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
            ),
            TextFormField(
              controller: _group,
              decoration: const InputDecoration(labelText: 'Gruppe (optional)'),
            ),
            TextFormField(
              controller: _step,
              decoration: const InputDecoration(labelText: 'Gewichtsschritt (kg)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => (double.tryParse(v ?? '') == null) ? 'Zahl nötig' : null,
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _repMin,
                    decoration: const InputDecoration(labelText: 'Rep min'),
                    keyboardType: TextInputType.number,
                    validator: (v) => (int.tryParse(v ?? '') == null) ? 'Zahl nötig' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _repMax,
                    decoration: const InputDecoration(labelText: 'Rep max'),
                    keyboardType: TextInputType.number,
                    validator: (v) => (int.tryParse(v ?? '') == null) ? 'Zahl nötig' : null,
                  ),
                ),
              ],
            ),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notizen'),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('btn-save-exercise'),
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                final name = _name.text.trim();
                final group = _group.text.trim().isEmpty ? null : _group.text.trim();
                final step = double.parse(_step.text);
                final repMin = int.parse(_repMin.text);
                final repMax = int.parse(_repMax.text);
                final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();

                if (isEdit) {
                  await ExercisesDao(db).updateById(
                    widget.edit!.id,
                    ExercisesCompanion(
                      name: Value(name),
                      group: Value(group),
                      defaultWeightStep: Value(step),
                      defaultRepMin: Value(repMin),
                      defaultRepMax: Value(repMax),
                      notes: Value(notes),
                    ),
                  );
                } else {
                  await ExercisesDao(db).create(
                    ExercisesCompanion.insert(
                      name: name,
                      group: Value(group),
                      defaultWeightStep: Value(step),
                      defaultRepMin: Value(repMin),
                      defaultRepMax: Value(repMax),
                      notes: Value(notes),
                    ),
                  );
                }
                if (!mounted) return;
                Navigator.of(context).pop(true);
              },
              icon: const Icon(Icons.save),
              label: Text(isEdit ? 'Speichern' : 'Anlegen'),
            )
          ],
        ),
      ),
    );
  }
}
