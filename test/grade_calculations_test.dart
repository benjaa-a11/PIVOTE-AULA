import 'package:flutter_test/flutter_test.dart';
import 'package:pivo_aula/features/exams/domain/exam.dart';
import 'package:pivo_aula/features/grades/domain/grade_entry.dart';
import 'package:pivo_aula/features/grades/presentation/grade_controller.dart';

void main() {
  group('GradeCalculations Tests', () {
    test('calculateAverage with equal weights', () {
      final grades = [
        GradeEntry(
          id: '1',
          subjectId: 'sub1',
          title: 'Parcial 1',
          value: 8.0,
          weight: 1.0,
          date: DateTime(2026, 5, 1),
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 1),
        ),
        GradeEntry(
          id: '2',
          subjectId: 'sub1',
          title: 'Parcial 2',
          value: 6.0,
          weight: 1.0,
          date: DateTime(2026, 6, 1),
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 1),
        ),
      ];

      final avg = GradeCalculations.calculateAverage(grades);
      expect(avg, 7.0);
    });

    test('calculateAverage with weighted values', () {
      final grades = [
        GradeEntry(
          id: '1',
          subjectId: 'sub1',
          title: 'Parcial',
          value: 10.0,
          weight: 0.7,
          date: DateTime(2026, 5, 1),
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 1),
        ),
        GradeEntry(
          id: '2',
          subjectId: 'sub1',
          title: 'TP',
          value: 5.0,
          weight: 0.3,
          date: DateTime(2026, 5, 10),
          createdAt: DateTime(2026, 5, 10),
          updatedAt: DateTime(2026, 5, 10),
        ),
      ];

      final avg = GradeCalculations.calculateAverage(grades);
      expect(avg, closeTo(8.5, 0.001));
    });

    test('retake grade with replacesOriginal replaces original exam grade', () {
      final midterm = Exam(
        id: 'ex-1',
        subjectId: 'sub1',
        type: ExamType.midterm,
        title: '1er Parcial',
        dateTime: DateTime(2026, 5, 1),
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
      );
      final retake = Exam(
        id: 'ex-2',
        subjectId: 'sub1',
        type: ExamType.retake,
        title: 'Recuperatorio 1er Parcial',
        retakeOfExamId: 'ex-1',
        dateTime: DateTime(2026, 5, 15),
        createdAt: DateTime(2026, 5, 2),
        updatedAt: DateTime(2026, 5, 2),
      );

      final grades = [
        GradeEntry(
          id: 'g-1',
          examId: 'ex-1',
          subjectId: 'sub1',
          title: '1er Parcial',
          value: 2.0,
          weight: 1.0,
          date: DateTime(2026, 5, 1),
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 1),
        ),
        GradeEntry(
          id: 'g-2',
          examId: 'ex-2',
          subjectId: 'sub1',
          title: 'Recuperatorio 1er Parcial',
          value: 8.0,
          weight: 1.0,
          isRetake: true,
          replacesOriginal: true,
          date: DateTime(2026, 5, 15),
          createdAt: DateTime(2026, 5, 15),
          updatedAt: DateTime(2026, 5, 15),
        ),
      ];

      final avg = GradeCalculations.calculateAverage(
        grades,
        exams: [midterm, retake],
      );
      expect(avg, closeTo(8.0, 0.001));
    });

    test('calculateRequiredGrade for target average', () {
      final grades = [
        GradeEntry(
          id: '1',
          subjectId: 'sub1',
          title: 'Parcial 1',
          value: 6.0,
          weight: 1.0,
          date: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final needed = GradeCalculations.calculateRequiredGrade(
        currentGrades: grades,
        targetAverage: 8.0,
        remainingWeight: 1.0,
      );

      expect(needed, closeTo(10.0, 0.001));
    });

    test('calculateRequiredGrade impossible target returns > 10', () {
      final grades = [
        GradeEntry(
          id: '1',
          subjectId: 'sub1',
          title: 'Parcial 1',
          value: 2.0,
          weight: 1.0,
          date: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final needed = GradeCalculations.calculateRequiredGrade(
        currentGrades: grades,
        targetAverage: 9.0,
        remainingWeight: 1.0,
      );

      expect(needed, closeTo(16.0, 0.001));
      expect(needed! > 10.0, isTrue);
    });
  });
}
