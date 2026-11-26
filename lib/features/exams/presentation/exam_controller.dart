import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/notification_service.dart';
import '../../profile/data/profile_repository.dart';
import '../../subjects/data/subject_repository.dart';
import '../data/exam_repository.dart';
import '../domain/exam.dart';

class ExamController extends StateNotifier<AsyncValue<void>> {
  final ExamRepository _repo;
  final Ref _ref;

  ExamController(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<void> _syncNotification(Exam exam) async {
    try {
      final profile = await _ref.read(profileRepositoryProvider).getProfile();
      if (profile != null && !profile.remindersEnabled) {
        await NotificationService.instance.cancelExamReminders(exam.id);
        return;
      }
      if (exam.remindersEnabled && !exam.isDeleted) {
        await NotificationService.instance.requestPermission();
        final subject =
            await _ref.read(subjectRepositoryProvider).getSubjectById(exam.subjectId);
        await NotificationService.instance.scheduleExamReminders(
          exam,
          subject?.name ?? 'Materia',
        );
      } else {
        await NotificationService.instance.cancelExamReminders(exam.id);
      }
    } catch (_) {
      // Never block local database persistence if platform notification APIs fail
    }
  }

  Future<void> createExam({
    required String subjectId,
    required ExamType type,
    required String title,
    required DateTime dateTime,
    int durationMinutes = 120,
    String? classroom,
    String? retakeOfExamId,
    ExamStatus status = ExamStatus.pending,
    bool remindersEnabled = true,
  }) async {
    state = const AsyncValue.loading();
    try {
      final now = DateTime.now();
      final exam = Exam(
        id: const Uuid().v4(),
        subjectId: subjectId,
        type: type,
        title: title.trim(),
        dateTime: dateTime,
        durationMinutes: durationMinutes,
        classroom:
            classroom?.trim().isEmpty == true ? null : classroom?.trim(),
        retakeOfExamId: retakeOfExamId,
        status: status,
        remindersEnabled: remindersEnabled,
        createdAt: now,
        updatedAt: now,
      );
      await _repo.upsertExam(exam);
      await _syncNotification(exam);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateExam(Exam exam) async {
    state = const AsyncValue.loading();
    try {
      final updated = exam.copyWith(updatedAt: DateTime.now());
      await _repo.upsertExam(updated);
      await _syncNotification(updated);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteExam(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.softDeleteExam(id);
      try {
        await NotificationService.instance.cancelExamReminders(id);
      } catch (_) {}
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> restoreExam(String id) async {
    try {
      await _repo.restoreExam(id);
      final restored = await _repo.getExamById(id);
      if (restored != null) {
        await _syncNotification(restored);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final examControllerProvider =
    StateNotifierProvider<ExamController, AsyncValue<void>>((ref) {
  final repo = ref.watch(examRepositoryProvider);
  return ExamController(repo, ref);
});
