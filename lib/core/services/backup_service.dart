import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../database/app_database.dart';
import '../../features/profile/domain/student_profile.dart';
import '../../features/subjects/domain/subject.dart';
import '../../features/exams/domain/exam.dart';
import '../../features/topics/domain/topic.dart';
import '../../features/grades/domain/grade_entry.dart';
import '../../features/schedule/domain/class_session.dart';
import '../../features/tasks/domain/academic_task.dart';
import '../../features/attendance/domain/attendance_record.dart';

class BackupService {
  final AppDatabase _db;
  BackupService(this._db);

  /// Capa 1: Copia automática rotativa en el dispositivo (conserva las últimas 5).
  Future<void> performAutoBackup() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(docs.path, 'backups_local'));
      if (!backupDir.existsSync()) {
        backupDir.createSync(recursive: true);
      }

      final dbFile = File(p.join(docs.path, 'aula_local.sqlite'));
      if (!dbFile.existsSync()) return;

      await _db.customStatement('PRAGMA wal_checkpoint(FULL);');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetFile =
          File(p.join(backupDir.path, 'backup_$timestamp.sqlite'));
      await dbFile.copy(targetFile.path);

      final files = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sqlite'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      if (files.length > 5) {
        for (int i = 5; i < files.length; i++) {
          try {
            files[i].deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Devuelve las instantáneas locales ordenadas de más reciente a más antigua.
  Future<List<File>> listLocalBackups() async {
    final docs = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(docs.path, 'backups_local'));
    if (!await backupDir.exists()) return const <File>[];

    final backups = backupDir
        .listSync()
        .whereType<File>()
        .where((file) =>
            p.basename(file.path).startsWith('backup_') &&
            file.path.toLowerCase().endsWith('.sqlite'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return backups;
  }

  /// Inspecciona el manifest sin tocar la base de datos activa.
  Future<bool> backupRequiresPassword(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) {
      throw Exception('El archivo de respaldo no es válido (falta manifest).');
    }
    final manifest = jsonDecode(
      utf8.decode(manifestFile.content as List<int>),
    ) as Map<String, dynamic>;
    return manifest['isEncrypted'] as bool? ?? false;
  }

  /// Restaura una instantánea SQLite local verificando su integridad previamente.
  Future<void> restoreLocalBackup(String filePath) async {
    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      throw Exception('La copia local ya no está disponible.');
    }

    final snapshotDb = AppDatabase(
      NativeDatabase.createInBackground(
        sourceFile,
        setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
    try {
      if (!await snapshotDb.checkIntegrity()) {
        throw Exception('La copia local está dañada y no se puede restaurar.');
      }
      final profile = await snapshotDb.getProfile();
      final subjects =
          await snapshotDb.watchSubjects(includeDeleted: true).first;
      final exams = await snapshotDb.watchExams(includeDeleted: true).first;
      final topics =
          await snapshotDb.watchAllTopics(includeDeleted: true).first;
      final grades =
          await snapshotDb.watchAllGrades(includeDeleted: true).first;
      final sessions = await snapshotDb.getClassSessions(includeDeleted: true);
      final tasks = await snapshotDb.getAcademicTasks(includeDeleted: true);
      final attendance =
          await snapshotDb.getAttendanceRecords(includeDeleted: true);

      if (profile == null &&
          subjects.isEmpty &&
          exams.isEmpty &&
          topics.isEmpty &&
          grades.isEmpty &&
          sessions.isEmpty &&
          tasks.isEmpty &&
          attendance.isEmpty) {
        throw Exception('La copia local no contiene datos para recuperar.');
      }

      await _db.transaction(() async {
        await _db.clearAllData();
        if (profile != null) await _db.saveProfile(profile);
        for (final subject in subjects) {
          await _db.upsertSubject(subject);
        }
        for (final exam in exams) {
          await _db.upsertExam(exam);
        }
        for (final topic in topics) {
          await _db.upsertTopic(topic);
        }
        for (final grade in grades) {
          await _db.upsertGrade(grade);
        }
        for (final session in sessions) {
          await _db.upsertClassSession(session);
        }
        for (final task in tasks) {
          await _db.upsertAcademicTask(task);
        }
        for (final record in attendance) {
          await _db.upsertAttendanceRecord(record);
        }
      });
    } finally {
      await snapshotDb.close();
    }
  }

  /// Exporta todos los registros a un paquete `.aula` con checksum SHA-256 y cifrado AES-GCM opcional.
  Future<String> exportBackup({String? password}) async {
    final profile = await _db.getProfile();
    final subjects = await _db.watchSubjects(includeDeleted: true).first;
    final exams = await _db.watchExams(includeDeleted: true).first;
    final topics = await _db.watchAllTopics(includeDeleted: true).first;
    final grades = await _db.watchAllGrades(includeDeleted: true).first;
    final sessions = await _db.getClassSessions(includeDeleted: true);
    final tasks = await _db.getAcademicTasks(includeDeleted: true);
    final attendance = await _db.getAttendanceRecords(includeDeleted: true);

    final dataMap = {
      'profile': profile?.toJson(),
      'subjects': subjects.map((s) => s.toJson()).toList(),
      'exams': exams.map((e) => e.toJson()).toList(),
      'topics': topics.map((t) => t.toJson()).toList(),
      'grades': grades.map((g) => g.toJson()).toList(),
      'classSessions': sessions.map((s) => s.toJson()).toList(),
      'academicTasks': tasks.map((t) => t.toJson()).toList(),
      'attendanceRecords': attendance.map((a) => a.toJson()).toList(),
    };

    final jsonString = jsonEncode(dataMap);
    final dataBytes = utf8.encode(jsonString);
    final checksum = sha256.convert(dataBytes).toString();

    final manifest = {
      'schemaVersion': 2,
      'appVersion': '2.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'checksum': checksum,
      'isEncrypted': password != null && password.isNotEmpty,
    };

    final archive = Archive();
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    if (password != null && password.isNotEmpty) {
      final algorithm = AesGcm.with256bits();
      final secretKey = await algorithm.newSecretKeyFromBytes(
        sha256.convert(utf8.encode(password)).bytes,
      );
      final secretBox =
          await algorithm.encrypt(dataBytes, secretKey: secretKey);
      final encryptedBytes = secretBox.concatenation();
      archive.addFile(
        ArchiveFile('data.enc', encryptedBytes.length, encryptedBytes),
      );
    } else {
      archive.addFile(ArchiveFile('data.json', dataBytes.length, dataBytes));
    }

    if (profile?.photoPath != null) {
      final photoFile = File(profile!.photoPath!);
      if (photoFile.existsSync()) {
        final photoBytes = photoFile.readAsBytesSync();
        archive.addFile(
          ArchiveFile(
            'photo${p.extension(photoFile.path)}',
            photoBytes.length,
            photoBytes,
          ),
        );
      }
    }

    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) {
      throw Exception('No se pudo generar el archivo de respaldo.');
    }

    final tempDir = await getTemporaryDirectory();
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final outPath = p.join(
      tempDir.path,
      'pivote_aula_${now.year}_${two(now.month)}_${two(now.day)}.aula',
    );
    final outFile = File(outPath);
    await outFile.writeAsBytes(zipData, flush: true);

    return outPath;
  }

  Future<void> shareBackupFile(String filePath) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        subject: 'Respaldo de Pivote Aula',
        text: 'Respaldo seguro y privado de mis datos académicos.',
      ),
    );
  }

  /// Restaura un paquete `.aula` (compatible con v1 y v2) de forma transaccional.
  Future<void> restoreBackup(String filePath, {String? password}) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) {
      throw Exception('El archivo de respaldo no es válido (falta manifest).');
    }

    final manifestJson = jsonDecode(
      utf8.decode(manifestFile.content as List<int>),
    ) as Map<String, dynamic>;
    final isEncrypted = manifestJson['isEncrypted'] as bool? ?? false;
    final expectedChecksum = manifestJson['checksum'] as String;

    List<int> rawDataBytes;

    if (isEncrypted) {
      if (password == null || password.isEmpty) {
        throw Exception(
          'Este respaldo está cifrado. Ingresá la contraseña para restaurar.',
        );
      }
      final encFile = archive.findFile('data.enc');
      if (encFile == null) {
        throw Exception('Falta el archivo cifrado de datos.');
      }

      final algorithm = AesGcm.with256bits();
      final secretKey = await algorithm.newSecretKeyFromBytes(
        sha256.convert(utf8.encode(password)).bytes,
      );

      final encBytes = encFile.content as List<int>;
      final secretBox = SecretBox.fromConcatenation(
        encBytes,
        nonceLength: algorithm.nonceLength,
        macLength: algorithm.macAlgorithm.macLength,
      );

      try {
        rawDataBytes =
            await algorithm.decrypt(secretBox, secretKey: secretKey);
      } catch (_) {
        throw Exception(
          'Contraseña incorrecta. No se pudo descifrar el respaldo.',
        );
      }
    } else {
      final dataFile = archive.findFile('data.json');
      if (dataFile == null) {
        throw Exception('Falta data.json en el respaldo.');
      }
      rawDataBytes = dataFile.content as List<int>;
    }

    final actualChecksum = sha256.convert(rawDataBytes).toString();
    if (actualChecksum != expectedChecksum) {
      throw Exception(
        'Error de integridad: el respaldo fue modificado o está dañado.',
      );
    }

    final data = jsonDecode(utf8.decode(rawDataBytes)) as Map<String, dynamic>;

    var restoredProfile = data['profile'] == null
        ? null
        : StudentProfile.fromJson(data['profile'] as Map<String, dynamic>);
    final restoredSubjects = (data['subjects'] as List? ?? const [])
        .map((item) => Subject.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final restoredExams = (data['exams'] as List? ?? const [])
        .map((item) => Exam.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final restoredTopics = (data['topics'] as List? ?? const [])
        .map((item) => Topic.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final restoredGrades = (data['grades'] as List? ?? const [])
        .map((item) => GradeEntry.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final restoredSessions = (data['classSessions'] as List? ?? const [])
        .map((item) => ClassSession.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final restoredTasks = (data['academicTasks'] as List? ?? const [])
        .map((item) => AcademicTask.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final restoredAttendance = (data['attendanceRecords'] as List? ?? const [])
        .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);

    final photoArchive =
        archive.files.where((f) => f.name.startsWith('photo')).firstOrNull;
    if (photoArchive != null) {
      final docs = await getApplicationDocumentsDirectory();
      final photoTarget = File(
        p.join(
          docs.path,
          'restored_${DateTime.now().millisecondsSinceEpoch}_${photoArchive.name}',
        ),
      );
      await photoTarget.writeAsBytes(photoArchive.content as List<int>);
      if (restoredProfile != null) {
        restoredProfile = restoredProfile.copyWith(photoPath: photoTarget.path);
      }
    }

    await _db.transaction(() async {
      await _db.clearAllData();
      if (restoredProfile != null) await _db.saveProfile(restoredProfile);
      for (final subject in restoredSubjects) {
        await _db.upsertSubject(subject);
      }
      for (final exam in restoredExams) {
        await _db.upsertExam(exam);
      }
      for (final topic in restoredTopics) {
        await _db.upsertTopic(topic);
      }
      for (final grade in restoredGrades) {
        await _db.upsertGrade(grade);
      }
      for (final session in restoredSessions) {
        await _db.upsertClassSession(session);
      }
      for (final task in restoredTasks) {
        await _db.upsertAcademicTask(task);
      }
      for (final record in restoredAttendance) {
        await _db.upsertAttendanceRecord(record);
      }
    });
  }
}
