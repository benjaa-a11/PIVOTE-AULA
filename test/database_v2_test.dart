import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pivo_aula/core/database/app_database.dart';
import 'package:pivo_aula/features/attendance/domain/attendance_record.dart';
import 'package:pivo_aula/features/exams/domain/exam.dart';
import 'package:pivo_aula/features/grades/domain/grade_entry.dart';
import 'package:pivo_aula/features/schedule/domain/class_session.dart';
import 'package:pivo_aula/features/subjects/domain/subject.dart';
import 'package:pivo_aula/features/tasks/domain/academic_task.dart';

void main() {
  test('AppDatabase v2 stores and filters subjects, schedules, tasks, attendance, exams and grades', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await db.checkIntegrity(), isTrue);

    final now = DateTime(2026, 4, 10, 10, 0);
    final subject = Subject(
      id: 'sub-1',
      name: 'Física II',
      code: 'FIS-202',
      colorValue: 0xFF4F46E5,
      iconCode: 0xe0ef,
      period: '1er Cuatrimestre 2026',
      createdAt: now,
      updatedAt: now,
    );
    await db.upsertSubject(subject);

    final session = ClassSession(
      id: 'cs-1',
      subjectId: 'sub-1',
      weekday: 2,
      startMinutes: 18 * 60,
      endMinutes: 21 * 60,
      classroom: 'Aula 108',
      createdAt: now,
      updatedAt: now,
    );
    await db.upsertClassSession(session);

    final task = AcademicTask(
      id: 'task-1',
      subjectId: 'sub-1',
      title: 'Guía Electromagnetismo',
      dueDate: now.add(const Duration(days: 5)),
      createdAt: now,
      updatedAt: now,
    );
    await db.upsertAcademicTask(task);

    final attendance = AttendanceRecord(
      id: 'att-1',
      subjectId: 'sub-1',
      date: now,
      status: AttendanceStatus.present,
      createdAt: now,
      updatedAt: now,
    );
    await db.upsertAttendanceRecord(attendance);

    final exam = Exam(
      id: 'ex-1',
      subjectId: 'sub-1',
      type: ExamType.midterm,
      title: '1er Parcial',
      dateTime: now.add(const Duration(days: 14)),
      createdAt: now,
      updatedAt: now,
    );
    await db.upsertExam(exam);

    final grade = GradeEntry(
      id: 'gr-1',
      examId: 'ex-1',
      subjectId: 'sub-1',
      title: '1er Parcial',
      value: 8.5,
      weight: 1.0,
      date: now,
      createdAt: now,
      updatedAt: now,
    );
    await db.upsertGrade(grade);

    expect((await db.watchSubjects().first).length, 1);
    expect((await db.getClassSessions()).length, 1);
    expect((await db.getAcademicTasks()).length, 1);
    expect((await db.getAttendanceRecords()).length, 1);
    expect((await db.watchExams().first).length, 1);
    expect((await db.watchAllGrades().first).length, 1);

    // Soft-deleting the subject hides its dependent items from active queries
    await db.softDeleteSubject('sub-1');
    expect(await db.watchSubjects().first, isEmpty);
    expect(await db.getClassSessions(), isEmpty);
    expect(await db.getAcademicTasks(), isEmpty);
    expect(await db.getAttendanceRecords(), isEmpty);
    expect(await db.watchExams().first, isEmpty);
    expect(await db.watchAllGrades().first, isEmpty);

    // Restoring the subject restores visibility of all its dependent records
    await db.restoreSubject('sub-1');
    expect((await db.watchSubjects().first).length, 1);
    expect((await db.getClassSessions()).length, 1);
    expect((await db.getAcademicTasks()).length, 1);
    expect((await db.getAttendanceRecords()).length, 1);
    expect((await db.watchExams().first).length, 1);
    expect((await db.watchAllGrades().first).length, 1);
  });
}
