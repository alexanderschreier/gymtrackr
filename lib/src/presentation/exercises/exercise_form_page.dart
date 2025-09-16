import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../data/db/app_database.dart';
import '../../data/db/db_provider.dart';

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

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _name.text = e.name;
      _group.text = e.group ?? '';
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
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('btn-save-exercise'),
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                final name = _name.text.trim();
                final group = _group.text.trim().isEmpty ? null : _group.text.trim();

                if (isEdit) {
                  await ExercisesDao(db).updateById(
                    widget.edit!.id,
                    ExercisesCompanion(
                      name: Value(name),
                      group: Value(group),
                    ),
                  );
                } else {
                  await ExercisesDao(db).create(
                    ExercisesCompanion.insert(
                      name: name,
                      group: Value(group),
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
