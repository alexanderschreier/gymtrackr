import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../db/app_database.dart';
import 'exercises_repository.dart';
import '../db/db_provider.dart';


final exercisesRepositoryProvider = Provider<ExercisesRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ExercisesRepository(ExercisesDao(db));
});