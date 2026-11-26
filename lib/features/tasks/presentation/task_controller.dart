import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/task_repository.dart';
import '../domain/academic_task.dart';

class TaskController extends StateNotifier<AsyncValue<void>> {
  final TaskRepository _repo;
  TaskController(this._repo) : super(const AsyncValue.data(null));

  Future<void> createTask({
    String? subjectId,
    required String title,
    String? description,
    DateTime? dueDate,
    TaskPriority priority = TaskPriority.medium,
    TaskCategory category = TaskCategory.assignment,
  }) async {
    state = const AsyncValue.loading();
    try {
      final now = DateTime.now();
      final task = AcademicTask(
        id: const Uuid().v4(),
        subjectId: subjectId,
        title: title.trim(),
        description:
            description?.trim().isEmpty == true ? null : description?.trim(),
        dueDate: dueDate,
        priority: priority,
        category: category,
        createdAt: now,
        updatedAt: now,
      );
      await _repo.upsertTask(task);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateTask(AcademicTask task) async {
    state = const AsyncValue.loading();
    try {
      await _repo.upsertTask(task.copyWith(updatedAt: DateTime.now()));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleCompleted(AcademicTask task) async {
    final now = DateTime.now();
    final nextCompleted = !task.isCompleted;
    await updateTask(
      task.copyWith(
        isCompleted: nextCompleted,
        completedAt: nextCompleted ? now : null,
        clearCompletedAt: !nextCompleted,
        updatedAt: now,
      ),
    );
  }

  Future<void> deleteTask(String id) async {
    try {
      await _repo.softDeleteTask(id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> restoreTask(String id) async {
    try {
      await _repo.restoreTask(id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final taskControllerProvider =
    StateNotifierProvider<TaskController, AsyncValue<void>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  return TaskController(repo);
});
