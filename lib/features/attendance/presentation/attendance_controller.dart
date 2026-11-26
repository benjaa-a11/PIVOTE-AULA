import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/attendance_repository.dart';
import '../domain/attendance_record.dart';

class AttendanceController extends StateNotifier<AsyncValue<void>> {
  final AttendanceRepository _repo;
  AttendanceController(this._repo) : super(const AsyncValue.data(null));

  Future<void> logAttendance({
    required String subjectId,
    required DateTime date,
    required AttendanceStatus status,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final now = DateTime.now();
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final record = AttendanceRecord(
        id: const Uuid().v4(),
        subjectId: subjectId,
        date: normalizedDate,
        status: status,
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
        createdAt: now,
        updatedAt: now,
      );
      await _repo.upsertAttendance(record);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteAttendance(String id) async {
    try {
      await _repo.softDeleteAttendance(id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final attendanceControllerProvider =
    StateNotifierProvider<AttendanceController, AsyncValue<void>>((ref) {
  final repo = ref.watch(attendanceRepositoryProvider);
  return AttendanceController(repo);
});
