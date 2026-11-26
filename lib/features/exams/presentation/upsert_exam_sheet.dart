import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_radius.dart';
import '../../../core/design_system/app_spacing.dart';
import '../../../core/design_system/app_typography.dart';
import '../../../core/design_system/components/app_button.dart';
import '../../../core/design_system/components/app_chip.dart';
import '../../../core/design_system/components/app_text_field.dart';
import '../../../core/design_system/components/spring_sheet.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../subjects/data/subject_repository.dart';
import '../data/exam_repository.dart';
import '../domain/exam.dart';
import 'exam_controller.dart';

class UpsertExamSheet extends ConsumerStatefulWidget {
  final Exam? examToEdit;
  final String? preselectedSubjectId;
  final DateTime? preselectedDate;

  const UpsertExamSheet({
    super.key,
    this.examToEdit,
    this.preselectedSubjectId,
    this.preselectedDate,
  });

  static Future<void> show(
    BuildContext context, {
    Exam? examToEdit,
    String? preselectedSubjectId,
    DateTime? preselectedDate,
  }) {
    return SpringSheet.show(
      context: context,
      title: examToEdit == null ? AppStrings.newExam : AppStrings.editExam,
      showCloseButton: true,
      child: UpsertExamSheet(
        examToEdit: examToEdit,
        preselectedSubjectId: preselectedSubjectId,
        preselectedDate: preselectedDate,
      ),
    );
  }

  @override
  ConsumerState<UpsertExamSheet> createState() => _UpsertExamSheetState();
}

class _UpsertExamSheetState extends ConsumerState<UpsertExamSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _classroomController;
  late final TextEditingController _durationController;

  String? _selectedSubjectId;
  late ExamType _selectedType;
  late ExamStatus _selectedStatus;
  late DateTime _selectedDateTime;
  String? _retakeOfExamId;
  bool _remindersEnabled = true;
  bool _isSaving = false;

  String? _titleError;
  String? _subjectError;

  @override
  void initState() {
    super.initState();
    final e = widget.examToEdit;
    _titleController = TextEditingController(text: e?.title ?? '');
    _classroomController = TextEditingController(text: e?.classroom ?? '');
    _durationController =
        TextEditingController(text: (e?.durationMinutes ?? 120).toString());

    _selectedSubjectId = e?.subjectId ?? widget.preselectedSubjectId;
    _selectedType = e?.type ?? ExamType.midterm;
    _selectedStatus = e?.status ?? ExamStatus.pending;
    if (e != null) {
      _selectedDateTime = e.dateTime;
    } else if (widget.preselectedDate != null) {
      final d = widget.preselectedDate!;
      _selectedDateTime = DateTime(d.year, d.month, d.day, 9, 0);
    } else {
      final base = DateTime.now().add(const Duration(days: 7));
      _selectedDateTime = DateTime(base.year, base.month, base.day, 9, 0);
    }
    _retakeOfExamId = e?.retakeOfExamId;
    _remindersEnabled = e?.remindersEnabled ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _classroomController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  bool _detectConflict(List<Exam> allExams) {
    for (final other in allExams) {
      if (widget.examToEdit != null && other.id == widget.examToEdit!.id) {
        continue;
      }
      final diff = other.dateTime.difference(_selectedDateTime).inMinutes.abs();
      if (diff < (other.durationMinutes.clamp(60, 240))) {
        return true;
      }
    }
    return false;
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    bool hasError = false;
    setState(() {
      if (_titleController.text.trim().isEmpty) {
        _titleError = 'Ingresá el título de la evaluación';
        hasError = true;
      } else {
        _titleError = null;
      }
      if (_selectedSubjectId == null) {
        _subjectError = 'Seleccioná una materia';
        hasError = true;
      } else {
        _subjectError = null;
      }
    });
    if (hasError) return;

    setState(() => _isSaving = true);
    final duration = int.tryParse(_durationController.text.trim()) ?? 120;

    if (widget.examToEdit == null) {
      await ref.read(examControllerProvider.notifier).createExam(
            subjectId: _selectedSubjectId!,
            type: _selectedType,
            title: _titleController.text,
            dateTime: _selectedDateTime,
            durationMinutes: duration,
            classroom: _classroomController.text,
            retakeOfExamId:
                _selectedType == ExamType.retake ? _retakeOfExamId : null,
            status: _selectedStatus,
            remindersEnabled: _remindersEnabled,
          );
    } else {
      final updated = widget.examToEdit!.copyWith(
        subjectId: _selectedSubjectId!,
        type: _selectedType,
        title: _titleController.text.trim(),
        dateTime: _selectedDateTime,
        durationMinutes: duration,
        classroom: _classroomController.text.trim().isEmpty
            ? null
            : _classroomController.text.trim(),
        retakeOfExamId:
            _selectedType == ExamType.retake ? _retakeOfExamId : null,
        status: _selectedStatus,
        remindersEnabled: _remindersEnabled,
      );
      await ref.read(examControllerProvider.notifier).updateExam(updated);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjects = ref.watch(subjectsStreamProvider).value ?? const [];
    final allExams = ref.watch(examsStreamProvider).value ?? const [];

    if (_selectedSubjectId == null && subjects.isNotEmpty) {
      _selectedSubjectId = subjects.first.id;
    }

    final hasConflict = _detectConflict(allExams);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSelectField<String>(
          label: 'Materia',
          value: subjects.any((s) => s.id == _selectedSubjectId)
              ? _selectedSubjectId
              : null,
          errorText: _subjectError,
          items: subjects
              .map(
                (s) => DropdownMenuItem<String>(
                  value: s.id,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Color(s.colorValue),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() {
            _selectedSubjectId = val;
            _subjectError = null;
            _retakeOfExamId = null;
          }),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(AppStrings.examType, style: AppTypography.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ExamType.values.map((type) {
            final isSelected = type == _selectedType;
            return AppChip(
              label: type.label,
              isSelected: isSelected,
              onTap: () => setState(() => _selectedType = type),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_selectedType == ExamType.retake) ...[
          AppSelectField<String?>(
            label: AppStrings.retakeOf,
            value: _retakeOfExamId,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Ninguno (independiente)'),
              ),
              ...allExams
                  .where((e) =>
                      e.subjectId == _selectedSubjectId &&
                      e.type == ExamType.midterm &&
                      e.id != widget.examToEdit?.id)
                  .map(
                    (e) => DropdownMenuItem<String?>(
                      value: e.id,
                      child: Text(e.title, overflow: TextOverflow.ellipsis),
                    ),
                  ),
            ],
            onChanged: (val) => setState(() => _retakeOfExamId = val),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppTextField(
          controller: _titleController,
          label: AppStrings.examTitle,
          hint: 'Ej. 1er Parcial Práctico',
          errorText: _titleError,
          textCapitalization: TextCapitalization.sentences,
          prefixIcon: const Icon(Icons.edit_note_rounded),
          onChanged: (v) {
            if (_titleError != null && v.trim().isNotEmpty) {
              setState(() => _titleError = null);
            }
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: const [
              '1er Parcial',
              '2do Parcial',
              'Recuperatorio',
              'Examen Final',
              'Entrega TP',
            ]
                .map(
                  (suggestion) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(suggestion),
                      onPressed: () => setState(() {
                        _titleController.text = suggestion;
                        _titleError = null;
                      }),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(AppStrings.examDate, style: AppTypography.titleSmall),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: _pickDateTime,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 13,
            ),
            decoration: ShapeDecoration(
              color: AppColors.surfaceSubtle(context),
              shape: AppRadius.continuousMd(
                side: BorderSide(color: AppColors.border(context)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 19,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${AppFormatters.date(_selectedDateTime)} · ${AppFormatters.time(_selectedDateTime)} hs',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  AppFormatters.countdown(_selectedDateTime),
                  style: AppTypography.caption.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasConflict) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: ShapeDecoration(
              color: AppColors.warning.withValues(alpha: 0.14),
              shape: AppRadius.continuousSm(
                side: BorderSide(
                  color: AppColors.warning.withValues(alpha: 0.45),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warnFg(context),
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    AppStrings.conflictWarning,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.warnFg(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _durationController,
                label: AppStrings.duration,
                hint: '120',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.timer_outlined),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(
                controller: _classroomController,
                label: 'Aula / Lugar',
                hint: 'Ej. Aula 204',
                prefixIcon: const Icon(Icons.room_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(AppStrings.status, style: AppTypography.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ExamStatus.values.map((status) {
            return AppChip(
              label: status.label,
              isSelected: status == _selectedStatus,
              onTap: () => setState(() => _selectedStatus = status),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _remindersEnabled,
          title: const Text(
            'Recordatorios automáticos',
            style: AppTypography.titleSmall,
          ),
          subtitle: Text(
            'Aviso 24 hs antes y a las 08:00 del día del examen',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          onChanged: (val) => setState(() => _remindersEnabled = val),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: widget.examToEdit == null ? 'Guardar evaluación' : AppStrings.save,
          isLoading: _isSaving,
          onPressed: _submit,
          isExpanded: true,
        ),
      ],
    );
  }
}
