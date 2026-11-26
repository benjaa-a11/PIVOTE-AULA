enum AttendanceStatus {
  present,
  absent,
  justified,
  cancelled;

  String get label {
    switch (this) {
      case AttendanceStatus.present:
        return 'Presente';
      case AttendanceStatus.absent:
        return 'Ausente';
      case AttendanceStatus.justified:
        return 'Justificada';
      case AttendanceStatus.cancelled:
        return 'Sin clase';
    }
  }
}

/// Registro individual de asistencia por fecha y materia.
class AttendanceRecord {
  final String id;
  final String subjectId;
  final DateTime date;
  final AttendanceStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const AttendanceRecord({
    required this.id,
    required this.subjectId,
    required this.date,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  AttendanceRecord copyWith({
    String? id,
    String? subjectId,
    DateTime? date,
    AttendanceStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      date: date ?? this.date,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectId': subjectId,
        'date': date.toIso8601String(),
        'status': status.name,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        id: json['id'] as String,
        subjectId: json['subjectId'] as String,
        date: DateTime.parse(json['date'] as String),
        status: AttendanceStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => AttendanceStatus.present,
        ),
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        deletedAt: json['deletedAt'] != null
            ? DateTime.parse(json['deletedAt'] as String)
            : null,
      );
}

/// Cálculo resumido de regularidad por asistencia.
class AttendanceSummary {
  final int presents;
  final int absents;
  final int justified;
  final int cancelled;

  const AttendanceSummary({
    required this.presents,
    required this.absents,
    required this.justified,
    required this.cancelled,
  });

  /// Clases efectivamente dictadas (excluye clases suspendidas).
  int get heldClasses => presents + absents + justified;

  /// Porcentaje efectivo de asistencia (presentes + justificadas / dictadas).
  double get percentage =>
      heldClasses == 0 ? 100.0 : ((presents + justified) / heldClasses) * 100.0;

  static AttendanceSummary fromRecords(Iterable<AttendanceRecord> records) {
    var p = 0, a = 0, j = 0, c = 0;
    for (final r in records) {
      if (r.isDeleted) continue;
      switch (r.status) {
        case AttendanceStatus.present:
          p++;
        case AttendanceStatus.absent:
          a++;
        case AttendanceStatus.justified:
          j++;
        case AttendanceStatus.cancelled:
          c++;
      }
    }
    return AttendanceSummary(
      presents: p,
      absents: a,
      justified: j,
      cancelled: c,
    );
  }
}
