import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../exams/domain/exam.dart';
import '../data/grade_repository.dart';
import '../domain/grade_entry.dart';

class GradeController extends StateNotifier<AsyncValue<void>> {
  final GradeRepository _repo;

  GradeController(this._repo) : super(const AsyncValue.data(null));

  Future<void> createGrade({
    String? examId,
    required String subjectId,
    required String title,
    required double value,
    double weight = 1.0,
    GradeKind kind = GradeKind.exam,
    bool isRetake = false,
    bool replacesOriginal = true,
    required DateTime date,
  }) async {
    state = const AsyncValue.loading();
    try {
      final now = DateTime.now();
      final grade = GradeEntry(
        id: const Uuid().v4(),
        examId: examId,
        subjectId: subjectId,
        title: title.trim(),
        value: value,
        weight: weight,
        kind: kind,
        isRetake: isRetake,
        replacesOriginal: replacesOriginal,
        date: date,
        createdAt: now,
        updatedAt: now,
      );
      await _repo.upsertGrade(grade);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateGrade(GradeEntry grade) async {
    state = const AsyncValue.loading();
    try {
      final updated = grade.copyWith(updatedAt: DateTime.now());
      await _repo.upsertGrade(updated);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteGrade(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.softDeleteGrade(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> restoreGrade(String id) async {
    try {
      await _repo.restoreGrade(id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final gradeControllerProvider =
    StateNotifierProvider<GradeController, AsyncValue<void>>((ref) {
  final repo = ref.watch(gradeRepositoryProvider);
  return GradeController(repo);
});

class GradeCalculations {
  GradeCalculations._();

  /// Filtra las calificaciones efectivas aplicando reglas de recuperatorio:
  /// - Si un recuperatorio tiene [replacesOriginal] == true y apunta a un
  ///   examen con `retakeOfExamId`, reemplaza la nota de ese examen original.
  /// - Si no tiene `examId` vinculado pero [isRetake] && [replacesOriginal],
  ///   reemplaza la nota anterior más baja del mismo tipo en esa materia.
  static List<GradeEntry> effectiveGrades(
    List<GradeEntry> grades, {
    List<Exam> exams = const [],
  }) {
    if (grades.length <= 1) return grades;

    final examById = {for (final e in exams) e.id: e};
    final replacedGradeIds = <String>{};

    // Orden cronológico para evaluar recuperatorios posteriores a notas previas
    final chronological = [...grades]
      ..sort((a, b) => a.date.compareTo(b.date));

    for (final g in chronological) {
      if (!g.isRetake || !g.replacesOriginal) continue;

      String? targetOriginalExamId;
      if (g.examId != null) {
        targetOriginalExamId = examById[g.examId]?.retakeOfExamId;
      }

      if (targetOriginalExamId != null) {
        for (final candidate in chronological) {
          if (candidate.id != g.id &&
              candidate.subjectId == g.subjectId &&
              candidate.examId == targetOriginalExamId) {
            replacedGradeIds.add(candidate.id);
          }
        }
      } else {
        // Buscar la nota previa más baja no reemplazada de la misma materia y tipo
        GradeEntry? lowestPrior;
        for (final candidate in chronological) {
          if (candidate.id == g.id) break;
          if (candidate.subjectId == g.subjectId &&
              !candidate.isRetake &&
              candidate.kind == g.kind &&
              !replacedGradeIds.contains(candidate.id)) {
            if (lowestPrior == null || candidate.value < lowestPrior.value) {
              lowestPrior = candidate;
            }
          }
        }
        if (lowestPrior != null) {
          replacedGradeIds.add(lowestPrior.id);
        }
      }
    }

    if (replacedGradeIds.isEmpty) return grades;
    return grades.where((g) => !replacedGradeIds.contains(g.id)).toList();
  }

  /// Calcula el promedio ponderado respetando recuperatorios que reemplazan original.
  static double calculateAverage(
    List<GradeEntry> grades, {
    List<Exam> exams = const [],
  }) {
    final effective = effectiveGrades(grades, exams: exams);
    if (effective.isEmpty) return 0.0;

    double sum = 0.0;
    double totalWeight = 0.0;

    for (final g in effective) {
      sum += g.value * g.weight;
      totalWeight += g.weight;
    }

    if (totalWeight <= 0) return 0.0;
    return sum / totalWeight;
  }

  /// Calcula el promedio aritmético simple sobre las notas efectivas.
  static double calculateSimpleAverage(
    List<GradeEntry> grades, {
    List<Exam> exams = const [],
  }) {
    final effective = effectiveGrades(grades, exams: exams);
    if (effective.isEmpty) return 0.0;
    final sum = effective.fold<double>(0.0, (acc, g) => acc + g.value);
    return sum / effective.length;
  }

  /// Promedio sin aplazos (filtra notas menores a [passingGrade]).
  static double calculateAverageWithoutFails(
    List<GradeEntry> grades, {
    required double passingGrade,
    List<Exam> exams = const [],
  }) {
    final effective = effectiveGrades(grades, exams: exams)
        .where((g) => g.value >= passingGrade)
        .toList();
    if (effective.isEmpty) return 0.0;
    return calculateAverage(effective, exams: exams);
  }

  /// Calcula qué calificación se necesita en el peso restante para llegar a la meta.
  static double? calculateRequiredGrade({
    required List<GradeEntry> currentGrades,
    required double targetAverage,
    required double remainingWeight,
    List<Exam> exams = const [],
  }) {
    if (remainingWeight <= 0) return null;

    final effective = effectiveGrades(currentGrades, exams: exams);
    double currentWeightedSum = 0.0;
    double currentWeight = 0.0;

    for (final g in effective) {
      currentWeightedSum += g.value * g.weight;
      currentWeight += g.weight;
    }

    final totalTargetSum = targetAverage * (currentWeight + remainingWeight);
    return (totalTargetSum - currentWeightedSum) / remainingWeight;
  }
}
