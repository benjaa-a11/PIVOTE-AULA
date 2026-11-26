import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../domain/attendance_record.dart';

abstract class AttendanceRepository {
  Stream<List<AttendanceRecord>> watchAllAttendance();
  Stream<List<AttendanceRecord>> watchSubjectAttendance(String subjectId);
  Future<void> upsertAttendance(AttendanceRecord record);
  Future<void> softDeleteAttendance(String id);
}

class DriftAttendanceRepository implements AttendanceRepository {
  final AppDatabase _db;
  DriftAttendanceRepository(this._db);

  @override
  Stream<List<AttendanceRecord>> watchAllAttendance() =>
      _db.watchAttendanceRecords();

  @override
  Stream<List<AttendanceRecord>> watchSubjectAttendance(String subjectId) =>
      _db.watchAttendanceForSubject(subjectId);

  @override
  Future<void> upsertAttendance(AttendanceRecord record) =>
      _db.upsertAttendanceRecord(record);

  @override
  Future<void> softDeleteAttendance(String id) =>
      _db.softDeleteAttendanceRecord(id);
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftAttendanceRepository(db);
});

final allAttendanceStreamProvider =
    StreamProvider<List<AttendanceRecord>>((ref) {
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.watchAllAttendance();
});

final subjectAttendanceStreamProvider =
    StreamProvider.family<List<AttendanceRecord>, String>((ref, subjectId) {
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.watchSubjectAttendance(subjectId);
});
