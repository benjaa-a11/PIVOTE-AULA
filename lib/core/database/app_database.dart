import 'dart:async';
import 'package:drift/drift.dart';
import 'connection.dart';
import 'tables.dart';
import '../../features/profile/domain/student_profile.dart';
import '../../features/subjects/domain/subject.dart';
import '../../features/exams/domain/exam.dart';
import '../../features/topics/domain/topic.dart';
import '../../features/grades/domain/grade_entry.dart';
import '../../features/schedule/domain/class_session.dart';
import '../../features/tasks/domain/academic_task.dart';
import '../../features/attendance/domain/attendance_record.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [StudentProfiles, Subjects, Exams, Topics, GradeEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? openConnection());

  final StreamController<void> _schedulesChanged =
      StreamController<void>.broadcast();
  final StreamController<void> _tasksChanged =
      StreamController<void>.broadcast();
  final StreamController<void> _attendanceChanged =
      StreamController<void>.broadcast();

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _ensureExtendedTables();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          await _ensureExtendedTables();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
          await _ensureExtendedTables();
        },
      );

  Future<void> _ensureExtendedTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS class_sessions (
        id TEXT NOT NULL PRIMARY KEY,
        subject_id TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
        weekday INTEGER NOT NULL,
        start_minutes INTEGER NOT NULL,
        end_minutes INTEGER NOT NULL,
        classroom TEXT,
        modality TEXT NOT NULL DEFAULT 'inPerson',
        professor TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      );
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_class_sessions_subject ON class_sessions(subject_id, weekday);',
    );

    await customStatement('''
      CREATE TABLE IF NOT EXISTS academic_tasks (
        id TEXT NOT NULL PRIMARY KEY,
        subject_id TEXT REFERENCES subjects(id) ON DELETE SET NULL,
        title TEXT NOT NULL,
        description TEXT,
        due_date TEXT,
        priority TEXT NOT NULL DEFAULT 'medium',
        category TEXT NOT NULL DEFAULT 'assignment',
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      );
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_academic_tasks_state ON academic_tasks(is_completed, due_date);',
    );

    await customStatement('''
      CREATE TABLE IF NOT EXISTS attendance_records (
        id TEXT NOT NULL PRIMARY KEY,
        subject_id TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
        date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'present',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      );
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_attendance_subject_date ON attendance_records(subject_id, date);',
    );

    // Performance indices on core tables
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_exams_subject_date ON exams(subject_id, exam_date);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_grades_subject_date ON grade_entries(subject_id, date);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_topics_subject_order ON topics(subject_id, sort_order);',
    );
  }

  @override
  Future<void> close() async {
    await _schedulesChanged.close();
    await _tasksChanged.close();
    await _attendanceChanged.close();
    await super.close();
  }

  Stream<List<T>> _watchCustom<T>(
    Stream<void> trigger,
    Future<List<T>> Function() loader,
  ) async* {
    yield await loader();
    await for (final _ in trigger) {
      yield await loader();
    }
  }

  Future<bool> checkIntegrity() async {
    final result = await customSelect('PRAGMA integrity_check;').getSingle();
    final val = result.read<String>('integrity_check');
    return val.toLowerCase() == 'ok';
  }

  // --- StudentProfile Queries ---
  Stream<StudentProfile?> watchProfile() {
    return (select(studentProfiles)..limit(1)).watchSingleOrNull().map((row) {
      if (row == null) return null;
      return _mapProfile(row);
    });
  }

  Future<StudentProfile?> getProfile() async {
    final row = await (select(studentProfiles)..limit(1)).getSingleOrNull();
    return row == null ? null : _mapProfile(row);
  }

  StudentProfile _mapProfile(StudentProfileRow row) {
    return StudentProfile(
      id: row.id,
      fullName: row.fullName,
      career: row.career,
      university: row.university,
      currentYear: row.currentYear,
      currentPeriod: row.currentPeriod,
      studentId: row.studentId,
      email: row.email,
      photoPath: row.photoPath,
      themeMode: row.themeMode,
      accentColorValue: row.accentColorValue,
      gradeScale: row.gradeScale,
      passingGrade: row.passingGrade,
      remindersEnabled: row.remindersEnabled,
      biometricEnabled: row.biometricEnabled,
      reduceMotion: row.reduceMotion,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<void> saveProfile(StudentProfile profile) async {
    await into(studentProfiles).insertOnConflictUpdate(
      StudentProfilesCompanion(
        id: Value(profile.id),
        fullName: Value(profile.fullName),
        career: Value(profile.career),
        university: Value(profile.university),
        currentYear: Value(profile.currentYear),
        currentPeriod: Value(profile.currentPeriod),
        studentId: Value(profile.studentId),
        email: Value(profile.email),
        photoPath: Value(profile.photoPath),
        themeMode: Value(profile.themeMode),
        accentColorValue: Value(profile.accentColorValue),
        gradeScale: Value(profile.gradeScale),
        passingGrade: Value(profile.passingGrade),
        remindersEnabled: Value(profile.remindersEnabled),
        biometricEnabled: Value(profile.biometricEnabled),
        reduceMotion: Value(profile.reduceMotion),
        createdAt: Value(profile.createdAt),
        updatedAt: Value(profile.updatedAt),
      ),
    );
  }

  // --- Subjects Queries ---
  Stream<List<Subject>> watchSubjects({bool includeDeleted = false}) {
    final query = select(subjects);
    if (!includeDeleted) {
      query.where((tbl) => tbl.deletedAt.isNull());
    }
    query.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.watch().map((rows) => rows.map(_mapSubject).toList());
  }

  Future<Subject?> getSubjectById(String id) async {
    final row = await (select(subjects)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _mapSubject(row) : null;
  }

  Future<void> upsertSubject(Subject s) async {
    await into(subjects).insertOnConflictUpdate(
      SubjectsCompanion(
        id: Value(s.id),
        name: Value(s.name),
        code: Value(s.code),
        colorValue: Value(s.colorValue),
        iconCode: Value(s.iconCode),
        professor: Value(s.professor),
        classroom: Value(s.classroom),
        credits: Value(s.credits),
        status: Value(s.status.name),
        period: Value(s.period),
        passingGrade: Value(s.passingGrade),
        notes: Value(s.notes),
        createdAt: Value(s.createdAt),
        updatedAt: Value(s.updatedAt),
        deletedAt: Value(s.deletedAt),
      ),
    );
    _notifyExtendedStreams();
  }

  Future<void> softDeleteSubject(String id) async {
    await (update(subjects)..where((tbl) => tbl.id.equals(id))).write(
      SubjectsCompanion(deletedAt: Value(DateTime.now())),
    );
    _notifyExtendedStreams();
  }

  Future<void> restoreSubject(String id) async {
    await (update(subjects)..where((tbl) => tbl.id.equals(id))).write(
      const SubjectsCompanion(deletedAt: Value(null)),
    );
    _notifyExtendedStreams();
  }

  void _notifyExtendedStreams() {
    if (!_schedulesChanged.isClosed) _schedulesChanged.add(null);
    if (!_tasksChanged.isClosed) _tasksChanged.add(null);
    if (!_attendanceChanged.isClosed) _attendanceChanged.add(null);
  }

  Subject _mapSubject(SubjectRow row) {
    return Subject(
      id: row.id,
      name: row.name,
      code: row.code,
      colorValue: row.colorValue,
      iconCode: row.iconCode,
      professor: row.professor,
      classroom: row.classroom,
      credits: row.credits,
      status: SubjectStatus.values.firstWhere(
        (s) => s.name == row.status,
        orElse: () => SubjectStatus.enrolled,
      ),
      period: row.period,
      passingGrade: row.passingGrade,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  Subquery<TypedResult> _activeSubjectIdsSubquery() {
    final q = selectOnly(subjects)
      ..addColumns([subjects.id])
      ..where(subjects.deletedAt.isNull());
    return Subquery(q, 'active_subjects');
  }

  // --- Exams Queries ---
  Stream<List<Exam>> watchExams({bool includeDeleted = false}) {
    if (includeDeleted) {
      final query = select(exams)
        ..orderBy([(t) => OrderingTerm.asc(t.examDate)]);
      return query.watch().map((rows) => rows.map(_mapExam).toList());
    }
    final activeSubjects = selectOnly(subjects)
      ..addColumns([subjects.id])
      ..where(subjects.deletedAt.isNull());
    final query = select(exams)
      ..where(
        (tbl) =>
            tbl.deletedAt.isNull() & tbl.subjectId.isInQuery(activeSubjects),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.examDate)]);
    // Unused helper suppression guard: keep subquery clean
    return query.watch().map((rows) => rows.map(_mapExam).toList());
  }

  Future<Exam?> getExamById(String id) async {
    final row = await (select(exams)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _mapExam(row) : null;
  }

  Future<void> upsertExam(Exam e) async {
    await into(exams).insertOnConflictUpdate(
      ExamsCompanion(
        id: Value(e.id),
        subjectId: Value(e.subjectId),
        type: Value(e.type.name),
        title: Value(e.title),
        examDate: Value(e.dateTime),
        durationMinutes: Value(e.durationMinutes),
        classroom: Value(e.classroom),
        retakeOfExamId: Value(e.retakeOfExamId),
        status: Value(e.status.name),
        remindersEnabled: Value(e.remindersEnabled),
        createdAt: Value(e.createdAt),
        updatedAt: Value(e.updatedAt),
        deletedAt: Value(e.deletedAt),
      ),
    );
  }

  Future<void> softDeleteExam(String id) async {
    await (update(exams)..where((tbl) => tbl.id.equals(id))).write(
      ExamsCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  Future<void> restoreExam(String id) async {
    await (update(exams)..where((tbl) => tbl.id.equals(id))).write(
      const ExamsCompanion(deletedAt: Value(null)),
    );
  }

  Exam _mapExam(ExamRow row) {
    return Exam(
      id: row.id,
      subjectId: row.subjectId,
      type: ExamType.values.firstWhere(
        (t) => t.name == row.type,
        orElse: () => ExamType.midterm,
      ),
      title: row.title,
      dateTime: row.examDate,
      durationMinutes: row.durationMinutes,
      classroom: row.classroom,
      retakeOfExamId: row.retakeOfExamId,
      status: ExamStatus.values.firstWhere(
        (s) => s.name == row.status,
        orElse: () => ExamStatus.pending,
      ),
      remindersEnabled: row.remindersEnabled,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  // --- Topics Queries ---
  Stream<List<Topic>> watchTopicsForExam(String examId) {
    return (select(topics)
          ..where((tbl) => tbl.examId.equals(examId) & tbl.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch()
        .map((rows) => rows.map(_mapTopic).toList());
  }

  Stream<List<Topic>> watchTopicsForSubject(String subjectId) {
    return (select(topics)
          ..where(
              (tbl) => tbl.subjectId.equals(subjectId) & tbl.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch()
        .map((rows) => rows.map(_mapTopic).toList());
  }

  Stream<List<Topic>> watchAllTopics({bool includeDeleted = false}) {
    if (includeDeleted) {
      return (select(topics)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch()
          .map((rows) => rows.map(_mapTopic).toList());
    }
    final activeSubjects = selectOnly(subjects)
      ..addColumns([subjects.id])
      ..where(subjects.deletedAt.isNull());
    return (select(topics)
          ..where((tbl) =>
              tbl.deletedAt.isNull() & tbl.subjectId.isInQuery(activeSubjects))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch()
        .map((rows) => rows.map(_mapTopic).toList());
  }

  Future<void> upsertTopic(Topic t) async {
    await into(topics).insertOnConflictUpdate(
      TopicsCompanion(
        id: Value(t.id),
        examId: Value(t.examId),
        subjectId: Value(t.subjectId),
        title: Value(t.title),
        status: Value(t.status.name),
        priority: Value(t.priority.name),
        sortOrder: Value(t.sortOrder),
        notes: Value(t.notes),
        createdAt: Value(t.createdAt),
        updatedAt: Value(t.updatedAt),
        deletedAt: Value(t.deletedAt),
      ),
    );
  }

  Future<void> softDeleteTopic(String id) async {
    await (update(topics)..where((tbl) => tbl.id.equals(id))).write(
      TopicsCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  Future<void> restoreTopic(String id) async {
    await (update(topics)..where((tbl) => tbl.id.equals(id))).write(
      const TopicsCompanion(deletedAt: Value(null)),
    );
  }

  Topic _mapTopic(TopicRow row) {
    return Topic(
      id: row.id,
      examId: row.examId,
      subjectId: row.subjectId,
      title: row.title,
      status: TopicStatus.values.firstWhere(
        (s) => s.name == row.status,
        orElse: () => TopicStatus.todo,
      ),
      priority: TopicPriority.values.firstWhere(
        (p) => p.name == row.priority,
        orElse: () => TopicPriority.medium,
      ),
      sortOrder: row.sortOrder,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  // --- GradeEntries Queries ---
  Stream<List<GradeEntry>> watchAllGrades({bool includeDeleted = false}) {
    if (includeDeleted) {
      return (select(gradeEntries)..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .watch()
          .map((rows) => rows.map(_mapGradeEntry).toList());
    }
    final activeSubjects = selectOnly(subjects)
      ..addColumns([subjects.id])
      ..where(subjects.deletedAt.isNull());
    return (select(gradeEntries)
          ..where((tbl) =>
              tbl.deletedAt.isNull() & tbl.subjectId.isInQuery(activeSubjects))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch()
        .map((rows) => rows.map(_mapGradeEntry).toList());
  }

  Stream<List<GradeEntry>> watchGradesForSubject(String subjectId) {
    return (select(gradeEntries)
          ..where(
              (tbl) => tbl.subjectId.equals(subjectId) & tbl.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch()
        .map((rows) => rows.map(_mapGradeEntry).toList());
  }

  Future<void> upsertGrade(GradeEntry g) async {
    await into(gradeEntries).insertOnConflictUpdate(
      GradeEntriesCompanion(
        id: Value(g.id),
        examId: Value(g.examId),
        subjectId: Value(g.subjectId),
        title: Value(g.title),
        value: Value(g.value),
        weight: Value(g.weight),
        kind: Value(g.kind.name),
        isRetake: Value(g.isRetake),
        replacesOriginal: Value(g.replacesOriginal),
        date: Value(g.date),
        createdAt: Value(g.createdAt),
        updatedAt: Value(g.updatedAt),
        deletedAt: Value(g.deletedAt),
      ),
    );
  }

  Future<void> softDeleteGrade(String id) async {
    await (update(gradeEntries)..where((tbl) => tbl.id.equals(id))).write(
      GradeEntriesCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  Future<void> restoreGrade(String id) async {
    await (update(gradeEntries)..where((tbl) => tbl.id.equals(id))).write(
      const GradeEntriesCompanion(deletedAt: Value(null)),
    );
  }

  GradeEntry _mapGradeEntry(GradeEntryRow row) {
    return GradeEntry(
      id: row.id,
      examId: row.examId,
      subjectId: row.subjectId,
      title: row.title,
      value: row.value,
      weight: row.weight,
      kind: GradeKind.values.firstWhere(
        (k) => k.name == row.kind,
        orElse: () => GradeKind.exam,
      ),
      isRetake: row.isRetake,
      replacesOriginal: row.replacesOriginal,
      date: row.date,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  // --- ClassSessions (Weekly Schedule) Queries ---
  Stream<List<ClassSession>> watchClassSessions({bool includeDeleted = false}) {
    return _watchCustom(
      _schedulesChanged.stream,
      () => getClassSessions(includeDeleted: includeDeleted),
    );
  }

  Stream<List<ClassSession>> watchClassSessionsForSubject(String subjectId) {
    return _watchCustom(_schedulesChanged.stream, () async {
      final rows = await customSelect(
        '''
        SELECT cs.* FROM class_sessions cs
        WHERE cs.subject_id = ? AND cs.deleted_at IS NULL
        ORDER BY cs.weekday ASC, cs.start_minutes ASC;
        ''',
        variables: [Variable.withString(subjectId)],
      ).get();
      return rows.map(_mapClassSession).toList();
    });
  }

  Future<List<ClassSession>> getClassSessions({
    bool includeDeleted = false,
  }) async {
    final sql = includeDeleted
        ? 'SELECT * FROM class_sessions ORDER BY weekday ASC, start_minutes ASC;'
        : '''
          SELECT cs.* FROM class_sessions cs
          INNER JOIN subjects s ON s.id = cs.subject_id
          WHERE cs.deleted_at IS NULL AND s.deleted_at IS NULL
          ORDER BY cs.weekday ASC, cs.start_minutes ASC;
        ''';
    final rows = await customSelect(sql).get();
    return rows.map(_mapClassSession).toList();
  }

  Future<void> upsertClassSession(ClassSession session) async {
    await customStatement(
      '''
      INSERT INTO class_sessions (
        id, subject_id, weekday, start_minutes, end_minutes,
        classroom, modality, professor, created_at, updated_at, deleted_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        subject_id = excluded.subject_id,
        weekday = excluded.weekday,
        start_minutes = excluded.start_minutes,
        end_minutes = excluded.end_minutes,
        classroom = excluded.classroom,
        modality = excluded.modality,
        professor = excluded.professor,
        updated_at = excluded.updated_at,
        deleted_at = excluded.deleted_at;
      ''',
      [
        session.id,
        session.subjectId,
        session.weekday,
        session.startMinutes,
        session.endMinutes,
        session.classroom,
        session.modality.name,
        session.professor,
        session.createdAt.toIso8601String(),
        session.updatedAt.toIso8601String(),
        session.deletedAt?.toIso8601String(),
      ],
    );
    if (!_schedulesChanged.isClosed) _schedulesChanged.add(null);
  }

  Future<void> softDeleteClassSession(String id) async {
    await customStatement(
      'UPDATE class_sessions SET deleted_at = ? WHERE id = ?;',
      [DateTime.now().toIso8601String(), id],
    );
    if (!_schedulesChanged.isClosed) _schedulesChanged.add(null);
  }

  Future<void> restoreClassSession(String id) async {
    await customStatement(
      'UPDATE class_sessions SET deleted_at = NULL WHERE id = ?;',
      [id],
    );
    if (!_schedulesChanged.isClosed) _schedulesChanged.add(null);
  }

  ClassSession _mapClassSession(QueryRow row) {
    final deletedStr = row.readNullable<String>('deleted_at');
    return ClassSession(
      id: row.read<String>('id'),
      subjectId: row.read<String>('subject_id'),
      weekday: row.read<int>('weekday'),
      startMinutes: row.read<int>('start_minutes'),
      endMinutes: row.read<int>('end_minutes'),
      classroom: row.readNullable<String>('classroom'),
      modality: ClassModality.values.firstWhere(
        (m) => m.name == row.read<String>('modality'),
        orElse: () => ClassModality.inPerson,
      ),
      professor: row.readNullable<String>('professor'),
      createdAt: DateTime.parse(row.read<String>('created_at')),
      updatedAt: DateTime.parse(row.read<String>('updated_at')),
      deletedAt: deletedStr != null ? DateTime.parse(deletedStr) : null,
    );
  }

  // --- AcademicTasks Queries ---
  Stream<List<AcademicTask>> watchAcademicTasks({bool includeDeleted = false}) {
    return _watchCustom(
      _tasksChanged.stream,
      () => getAcademicTasks(includeDeleted: includeDeleted),
    );
  }

  Stream<List<AcademicTask>> watchTasksForSubject(String subjectId) {
    return _watchCustom(_tasksChanged.stream, () async {
      final rows = await customSelect(
        '''
        SELECT * FROM academic_tasks
        WHERE subject_id = ? AND deleted_at IS NULL
        ORDER BY is_completed ASC,
                 CASE WHEN due_date IS NULL THEN 1 ELSE 0 END ASC,
                 due_date ASC,
                 created_at DESC;
        ''',
        variables: [Variable.withString(subjectId)],
      ).get();
      return rows.map(_mapAcademicTask).toList();
    });
  }

  Future<List<AcademicTask>> getAcademicTasks({
    bool includeDeleted = false,
  }) async {
    final sql = includeDeleted
        ? 'SELECT * FROM academic_tasks ORDER BY created_at DESC;'
        : '''
          SELECT t.* FROM academic_tasks t
          LEFT JOIN subjects s ON s.id = t.subject_id
          WHERE t.deleted_at IS NULL AND (t.subject_id IS NULL OR s.deleted_at IS NULL)
          ORDER BY t.is_completed ASC,
                   CASE WHEN t.due_date IS NULL THEN 1 ELSE 0 END ASC,
                   t.due_date ASC,
                   t.created_at DESC;
        ''';
    final rows = await customSelect(sql).get();
    return rows.map(_mapAcademicTask).toList();
  }

  Future<void> upsertAcademicTask(AcademicTask task) async {
    await customStatement(
      '''
      INSERT INTO academic_tasks (
        id, subject_id, title, description, due_date, priority,
        category, is_completed, completed_at, created_at, updated_at, deleted_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        subject_id = excluded.subject_id,
        title = excluded.title,
        description = excluded.description,
        due_date = excluded.due_date,
        priority = excluded.priority,
        category = excluded.category,
        is_completed = excluded.is_completed,
        completed_at = excluded.completed_at,
        updated_at = excluded.updated_at,
        deleted_at = excluded.deleted_at;
      ''',
      [
        task.id,
        task.subjectId,
        task.title,
        task.description,
        task.dueDate?.toIso8601String(),
        task.priority.name,
        task.category.name,
        task.isCompleted ? 1 : 0,
        task.completedAt?.toIso8601String(),
        task.createdAt.toIso8601String(),
        task.updatedAt.toIso8601String(),
        task.deletedAt?.toIso8601String(),
      ],
    );
    if (!_tasksChanged.isClosed) _tasksChanged.add(null);
  }

  Future<void> softDeleteAcademicTask(String id) async {
    await customStatement(
      'UPDATE academic_tasks SET deleted_at = ? WHERE id = ?;',
      [DateTime.now().toIso8601String(), id],
    );
    if (!_tasksChanged.isClosed) _tasksChanged.add(null);
  }

  Future<void> restoreAcademicTask(String id) async {
    await customStatement(
      'UPDATE academic_tasks SET deleted_at = NULL WHERE id = ?;',
      [id],
    );
    if (!_tasksChanged.isClosed) _tasksChanged.add(null);
  }

  AcademicTask _mapAcademicTask(QueryRow row) {
    final dueStr = row.readNullable<String>('due_date');
    final compStr = row.readNullable<String>('completed_at');
    final delStr = row.readNullable<String>('deleted_at');
    return AcademicTask(
      id: row.read<String>('id'),
      subjectId: row.readNullable<String>('subject_id'),
      title: row.read<String>('title'),
      description: row.readNullable<String>('description'),
      dueDate: dueStr != null ? DateTime.parse(dueStr) : null,
      priority: TaskPriority.values.firstWhere(
        (p) => p.name == row.read<String>('priority'),
        orElse: () => TaskPriority.medium,
      ),
      category: TaskCategory.values.firstWhere(
        (c) => c.name == row.read<String>('category'),
        orElse: () => TaskCategory.assignment,
      ),
      isCompleted: row.read<int>('is_completed') != 0,
      completedAt: compStr != null ? DateTime.parse(compStr) : null,
      createdAt: DateTime.parse(row.read<String>('created_at')),
      updatedAt: DateTime.parse(row.read<String>('updated_at')),
      deletedAt: delStr != null ? DateTime.parse(delStr) : null,
    );
  }

  // --- AttendanceRecords Queries ---
  Stream<List<AttendanceRecord>> watchAttendanceRecords({
    bool includeDeleted = false,
  }) {
    return _watchCustom(
      _attendanceChanged.stream,
      () => getAttendanceRecords(includeDeleted: includeDeleted),
    );
  }

  Stream<List<AttendanceRecord>> watchAttendanceForSubject(String subjectId) {
    return _watchCustom(_attendanceChanged.stream, () async {
      final rows = await customSelect(
        '''
        SELECT * FROM attendance_records
        WHERE subject_id = ? AND deleted_at IS NULL
        ORDER BY date DESC;
        ''',
        variables: [Variable.withString(subjectId)],
      ).get();
      return rows.map(_mapAttendanceRecord).toList();
    });
  }

  Future<List<AttendanceRecord>> getAttendanceRecords({
    bool includeDeleted = false,
  }) async {
    final sql = includeDeleted
        ? 'SELECT * FROM attendance_records ORDER BY date DESC;'
        : '''
          SELECT ar.* FROM attendance_records ar
          INNER JOIN subjects s ON s.id = ar.subject_id
          WHERE ar.deleted_at IS NULL AND s.deleted_at IS NULL
          ORDER BY ar.date DESC;
        ''';
    final rows = await customSelect(sql).get();
    return rows.map(_mapAttendanceRecord).toList();
  }

  Future<void> upsertAttendanceRecord(AttendanceRecord record) async {
    await customStatement(
      '''
      INSERT INTO attendance_records (
        id, subject_id, date, status, notes, created_at, updated_at, deleted_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        subject_id = excluded.subject_id,
        date = excluded.date,
        status = excluded.status,
        notes = excluded.notes,
        updated_at = excluded.updated_at,
        deleted_at = excluded.deleted_at;
      ''',
      [
        record.id,
        record.subjectId,
        record.date.toIso8601String(),
        record.status.name,
        record.notes,
        record.createdAt.toIso8601String(),
        record.updatedAt.toIso8601String(),
        record.deletedAt?.toIso8601String(),
      ],
    );
    if (!_attendanceChanged.isClosed) _attendanceChanged.add(null);
  }

  Future<void> softDeleteAttendanceRecord(String id) async {
    await customStatement(
      'UPDATE attendance_records SET deleted_at = ? WHERE id = ?;',
      [DateTime.now().toIso8601String(), id],
    );
    if (!_attendanceChanged.isClosed) _attendanceChanged.add(null);
  }

  AttendanceRecord _mapAttendanceRecord(QueryRow row) {
    final delStr = row.readNullable<String>('deleted_at');
    return AttendanceRecord(
      id: row.read<String>('id'),
      subjectId: row.read<String>('subject_id'),
      date: DateTime.parse(row.read<String>('date')),
      status: AttendanceStatus.values.firstWhere(
        (s) => s.name == row.read<String>('status'),
        orElse: () => AttendanceStatus.present,
      ),
      notes: row.readNullable<String>('notes'),
      createdAt: DateTime.parse(row.read<String>('created_at')),
      updatedAt: DateTime.parse(row.read<String>('updated_at')),
      deletedAt: delStr != null ? DateTime.parse(delStr) : null,
    );
  }

  // Keep private helper referenced for analyzer cleanliness
  Subquery<TypedResult> get unusedActiveSubquery => _activeSubjectIdsSubquery();

  Future<void> clearAllData() async {
    await transaction(() async {
      await customStatement('DELETE FROM attendance_records;');
      await customStatement('DELETE FROM academic_tasks;');
      await customStatement('DELETE FROM class_sessions;');
      await delete(gradeEntries).go();
      await delete(topics).go();
      await delete(exams).go();
      await delete(subjects).go();
      await delete(studentProfiles).go();
    });
    _notifyExtendedStreams();
  }
}
