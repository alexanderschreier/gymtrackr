import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';



// -----------------
// Tables
// -----------------
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get group => text().nullable()();
  RealColumn get defaultWeightStep => real().withDefault(const Constant(2.5))();
  IntColumn get defaultRepMin => integer().withDefault(const Constant(5))();
  IntColumn get defaultRepMax => integer().withDefault(const Constant(8))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}


class Plans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}


class PlanExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().references(Plans, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id, onDelete: KeyAction.restrict)();
  IntColumn get order => integer().withDefault(const Constant(0))();
  IntColumn get sets => integer().withDefault(const Constant(3))();
  IntColumn get repMin => integer().withDefault(const Constant(5))();
  IntColumn get repMax => integer().withDefault(const Constant(8))();
  RealColumn get weightStep => real().withDefault(const Constant(2.5))();
  RealColumn get initialWeight => real().nullable()();
  @override
  List<String> get customConstraints => [
    'UNIQUE(plan_id, exercise_id, "order")',
  ];
}


class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().references(Plans, #id, onDelete: KeyAction.setNull).nullable()();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  TextColumn get note => text().nullable()();
}


class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId => integer().references(Workouts, #id, onDelete: KeyAction.cascade)();
  IntColumn get planExerciseId => integer().references(PlanExercises, #id, onDelete: KeyAction.restrict)();
  IntColumn get setIndex => integer()();
  RealColumn get targetWeight => real().withDefault(const Constant(0))();
  RealColumn get actualWeight => real().nullable()();
  IntColumn get actualReps => integer().nullable()();


}