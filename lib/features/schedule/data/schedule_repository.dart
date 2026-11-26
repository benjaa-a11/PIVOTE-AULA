import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../domain/class_session.dart';

abstract class ScheduleRepository {
  Stream<List<ClassSession>> watchClassSessions({bool includeDeleted = false});
  Stream<List<ClassSession>> watchSessionsForSubject(String subjectId);
  Future<void> upsertSession(ClassSession session);
  Future<void> softDeleteSession(String id);
  Future<void> restoreSession(String id);
}

class DriftScheduleRepository implements ScheduleRepository {
  final AppDatabase _db;
  DriftScheduleRepository(this._db);

  @override
  Stream<List<ClassSession>> watchClassSessions({bool includeDeleted = false}) =>
      _db.watchClassSessions(includeDeleted: includeDeleted);

  @override
  Stream<List<ClassSession>> watchSessionsForSubject(String subjectId) =>
      _db.watchClassSessionsForSubject(subjectId);

  @override
  Future<void> upsertSession(ClassSession session) =>
      _db.upsertClassSession(session);

  @override
  Future<void> softDeleteSession(String id) =>
      _db.softDeleteClassSession(id);

  @override
  Future<void> restoreSession(String id) =>
      _db.restoreClassSession(id);
}

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftScheduleRepository(db);
});

final classSessionsStreamProvider = StreamProvider<List<ClassSession>>((ref) {
  final repo = ref.watch(scheduleRepositoryProvider);
  return repo.watchClassSessions();
});

final subjectSessionsStreamProvider =
    StreamProvider.family<List<ClassSession>, String>((ref, subjectId) {
  final repo = ref.watch(scheduleRepositoryProvider);
  return repo.watchSessionsForSubject(subjectId);
});
