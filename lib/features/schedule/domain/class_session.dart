enum ClassModality {
  inPerson,
  virtual,
  hybrid,
  lab;

  String get label {
    switch (this) {
      case ClassModality.inPerson:
        return 'Presencial';
      case ClassModality.virtual:
        return 'Virtual';
      case ClassModality.hybrid:
        return 'Híbrida';
      case ClassModality.lab:
        return 'Práctica / Lab';
    }
  }
}

/// Bloque horario semanal de cursada de una materia.
class ClassSession {
  final String id;
  final String subjectId;
  /// 1 = Lunes ... 7 = Domingo (estándar ISO de Dart DateTime.weekday).
  final int weekday;
  /// Minutos desde las 00:00 (ej. 18:30 => 1110).
  final int startMinutes;
  /// Minutos desde las 00:00 (ej. 21:00 => 1260).
  final int endMinutes;
  final String? classroom;
  final ClassModality modality;
  final String? professor;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const ClassSession({
    required this.id,
    required this.subjectId,
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    this.classroom,
    this.modality = ClassModality.inPerson,
    this.professor,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  int get durationMinutes => (endMinutes - startMinutes).clamp(0, 1440);

  String get weekdayLabel => weekdayFullName(weekday);
  String get weekdayShort => weekdayShortName(weekday);

  String get timeRangeLabel =>
      '${formatMinutes(startMinutes)} – ${formatMinutes(endMinutes)}';

  static String formatMinutes(int minutes) {
    final safe = minutes.clamp(0, 1439);
    final h = (safe ~/ 60).toString().padLeft(2, '0');
    final m = (safe % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String weekdayFullName(int day) {
    const names = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return names[(day - 1).clamp(0, 6)];
  }

  static String weekdayShortName(int day) {
    const names = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return names[(day - 1).clamp(0, 6)];
  }

  ClassSession copyWith({
    String? id,
    String? subjectId,
    int? weekday,
    int? startMinutes,
    int? endMinutes,
    String? classroom,
    ClassModality? modality,
    String? professor,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return ClassSession(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      weekday: weekday ?? this.weekday,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      classroom: classroom ?? this.classroom,
      modality: modality ?? this.modality,
      professor: professor ?? this.professor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectId': subjectId,
        'weekday': weekday,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'classroom': classroom,
        'modality': modality.name,
        'professor': professor,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory ClassSession.fromJson(Map<String, dynamic> json) => ClassSession(
        id: json['id'] as String,
        subjectId: json['subjectId'] as String,
        weekday: (json['weekday'] as num?)?.toInt() ?? 1,
        startMinutes: (json['startMinutes'] as num?)?.toInt() ?? 480,
        endMinutes: (json['endMinutes'] as num?)?.toInt() ?? 600,
        classroom: json['classroom'] as String?,
        modality: ClassModality.values.firstWhere(
          (m) => m.name == json['modality'],
          orElse: () => ClassModality.inPerson,
        ),
        professor: json['professor'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        deletedAt: json['deletedAt'] != null
            ? DateTime.parse(json['deletedAt'] as String)
            : null,
      );
}
