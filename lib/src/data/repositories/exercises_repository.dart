import 'package:drift/drift.dart';
import '../db/app_database.dart';


class ExercisesRepository {
  final ExercisesDao _dao;
  ExercisesRepository(this._dao);


  Future<int> create({
    required String name,
    String? group,
    double step = 2.5,
    int repMin = 5,
    int repMax = 8,
    String? notes,
  }) {
    return _dao.create(ExercisesCompanion.insert(
      name: name,
      group: Value(group),
      defaultWeightStep: Value(step),
      defaultRepMin: Value(repMin),
      defaultRepMax: Value(repMax),
      notes: Value(notes),
    ));
  }


  Future<List<Exercise>> all() => _dao.all();
  Stream<List<Exercise>> watchAll() => _dao.watchAll();
  Future<bool> updateById(int id, {String? name, String? notes}) => _dao.updateById(id, ExercisesCompanion(
    name: name == null ? const Value.absent() : Value(name),
    notes: notes == null ? const Value.absent() : Value(notes),
  ));
  Future<int> deleteById(int id) => _dao.deleteById(id);
}