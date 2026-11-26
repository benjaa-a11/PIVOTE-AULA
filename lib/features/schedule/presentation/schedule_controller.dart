import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/schedule_repository.dart';
import '../domain/class_session.dart';

class ScheduleController extends StateNotifier<AsyncValue<void>> {
  final ScheduleRepository _repo;
  ScheduleController(this._repo) : super(const AsyncValue.data(null));

  Future<void> createSession({
    required String subjectId,
    required int weekday,
    required int startMinutes,
    required int endMinutes,
    String? classroom,
    ClassModality modality = ClassModality.inPerson,
    String? professor,
  }) async {
    state = const AsyncValue.loading();
    try {
      final now = DateTime.now();
      final session = ClassSession(
        id: const Uuid().v4(),
        subjectId: subjectId,
        weekday: weekday,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        classroom: classroom?.trim().isEmpty == true ? null : classroom?.trim(),
        modality: modality,
        professor: professor?.trim().isEmpty == true ? null : professor?.trim(),
        createdAt: now,
        updatedAt: now,
      );
      await _repo.upsertSession(session);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateSession(ClassSession session) async {
    state = const AsyncValue.loading();
    try {
      await _repo.upsertSession(session.copyWith(updatedAt: DateTime.now()));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteSession(String id) async {
    try {
      await _repo.softDeleteSession(id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> restoreSession(String id) async {
    try {
      await _repo.restoreSession(id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final scheduleControllerProvider =
    StateNotifierProvider<ScheduleController, AsyncValue<void>>((ref) {
  final repo = ref.watch(scheduleRepositoryProvider);
  return ScheduleController(repo);
});
