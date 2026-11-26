import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../domain/academic_task.dart';

abstract class TaskRepository {
  Stream<List<AcademicTask>> watchTasks({bool includeDeleted = false});
  Stream<List<AcademicTask>> watchTasksForSubject(String subjectId);
  Future<void> upsertTask(AcademicTask task);
  Future<void> softDeleteTask(String id);
  Future<void> restoreTask(String id);
}

class DriftTaskRepository implements TaskRepository {
  final AppDatabase _db;
  DriftTaskRepository(this._db);

  @override
  Stream<List<AcademicTask>> watchTasks({bool includeDeleted = false}) =>
      _db.watchAcademicTasks(includeDeleted: includeDeleted);

  @override
  Stream<List<AcademicTask>> watchTasksForSubject(String subjectId) =>
      _db.watchTasksForSubject(subjectId);

  @override
  Future<void> upsertTask(AcademicTask task) => _db.upsertAcademicTask(task);

  @override
  Future<void> softDeleteTask(String id) => _db.softDeleteAcademicTask(id);

  @override
  Future<void> restoreTask(String id) => _db.restoreAcademicTask(id);
}

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftTaskRepository(db);
});

final academicTasksStreamProvider = StreamProvider<List<AcademicTask>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.watchTasks();
});

final subjectTasksStreamProvider =
    StreamProvider.family<List<AcademicTask>, String>((ref, subjectId) {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.watchTasksForSubject(subjectId);
});
