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
import '../../exams/data/exam_repository.dart';
import '../../exams/domain/exam.dart';
import '../../profile/data/profile_repository.dart';
import '../../subjects/data/subject_repository.dart';
import '../domain/grade_entry.dart';
import 'grade_controller.dart';

class UpsertGradeSheet extends ConsumerStatefulWidget {
  final GradeEntry? gradeToEdit;
  final String? preselectedSubjectId;
  final String? preselectedExamId;

  const UpsertGradeSheet({
    super.key,
    this.gradeToEdit,
    this.preselectedSubjectId,
    this.preselectedExamId,
  });

  static Future<void> show(
    BuildContext context, {
    GradeEntry? gradeToEdit,
    String? preselectedSubjectId,
    String? preselectedExamId,
  }) {
    return SpringSheet.show(
      context: context,
      title: gradeToEdit == null ? AppStrings.newGrade : 'Editar calificación',
      showCloseButton: true,
      child: UpsertGradeSheet(
        gradeToEdit: gradeToEdit,
        preselectedSubjectId: preselectedSubjectId,
        preselectedExamId: preselectedExamId,
      ),
    );
  }

  @override
  ConsumerState<UpsertGradeSheet> createState() => _UpsertGradeSheetState();
}

class _UpsertGradeSheetState extends ConsumerState<UpsertGradeSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _valueController;
  late final TextEditingController _weightController;

  String? _selectedSubjectId;
  String? _selectedExamId;
  late GradeKind _kind;
  late DateTime _date;
  bool _isRetake = false;
  bool _replacesOriginal = true;
  bool _isSaving = false;

  String? _valueError;
  String? _titleError;
  String? _weightError;

  @override
  void initState() {
    super.initState();
    final g = widget.gradeToEdit;
    _titleController = TextEditingController(text: g?.title ?? '');
    _valueController =
        TextEditingController(text: g != null ? AppFormatters.grade(g.value, decimals: 2) : '');
    _weightController = TextEditingController(
      text: ((g?.weight ?? 1.0) * 100).toStringAsFixed(0),
    );

    _selectedSubjectId = g?.subjectId ?? widget.preselectedSubjectId;
    _selectedExamId = g?.examId ?? widget.preselectedExamId;
    _kind = g?.kind ?? GradeKind.exam;
    _date = g?.date ?? DateTime.now();
    _isRetake = g?.isRetake ?? false;
    _replacesOriginal = g?.replacesOriginal ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _valueController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _submit(double maxGrade) async {
    if (_isSaving) return;
    final val =
        double.tryParse(_valueController.text.trim().replaceAll(',', '.'));
    final weightPercent = double.tryParse(
      _weightController.text.trim().replaceAll(',', '.'),
    );
    bool hasError = false;

    setState(() {
      if (val == null || val < 0 || val > maxGrade) {
        _valueError =
            'Ingresá una nota entre 0 y ${maxGrade.toStringAsFixed(0)}';
        hasError = true;
      } else {
        _valueError = null;
      }
      if (_titleController.text.trim().isEmpty) {
        _titleError = 'Ingresá un concepto descriptivo';
        hasError = true;
      } else {
        _titleError = null;
      }
      if (weightPercent == null || weightPercent <= 0 || weightPercent > 100) {
        _weightError = 'Entre 1% y 100%';
        hasError = true;
      } else {
        _weightError = null;
      }
    });

    if (hasError || _selectedSubjectId == null) return;

    setState(() => _isSaving = true);
    final weight = (weightPercent ?? 100) / 100.0;

    if (widget.gradeToEdit == null) {
      await ref.read(gradeControllerProvider.notifier).createGrade(
            subjectId: _selectedSubjectId!,
            examId: _selectedExamId,
            title: _titleController.text,
            value: val!,
            weight: weight,
            kind: _kind,
            isRetake: _isRetake,
            replacesOriginal: _replacesOriginal,
            date: _date,
          );
    } else {
      final updated = widget.gradeToEdit!.copyWith(
        subjectId: _selectedSubjectId!,
        examId: _selectedExamId,
        title: _titleController.text.trim(),
        value: val!,
        weight: weight,
        kind: _kind,
        isRetake: _isRetake,
        replacesOriginal: _replacesOriginal,
        date: _date,
      );
      await ref.read(gradeControllerProvider.notifier).updateGrade(updated);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsStreamProvider).value ?? const [];
    final allExams = ref.watch(examsStreamProvider).value ?? const [];
    final profile = ref.watch(profileStreamProvider).value;
    final maxGrade = profile?.maxScaleGrade ?? 10.0;

    if (_selectedSubjectId == null && subjects.isNotEmpty) {
      _selectedSubjectId = subjects.first.id;
    }

    final availableExams =
        allExams.where((e) => e.subjectId == _selectedSubjectId).toList();

    // Auto-fill title when coming with preselectedExamId
    if (widget.gradeToEdit == null &&
        _selectedExamId != null &&
        _titleController.text.isEmpty) {
      final linked =
          availableExams.where((e) => e.id == _selectedExamId).firstOrNull;
      if (linked != null) {
        _titleController.text = linked.title;
        if (linked.type == ExamType.retake) {
          _isRetake = true;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSelectField<String>(
          label: 'Materia',
          value: subjects.any((s) => s.id == _selectedSubjectId)
              ? _selectedSubjectId
              : null,
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
            _selectedExamId = null;
          }),
        ),
        const SizedBox(height: AppSpacing.md),
        if (availableExams.isNotEmpty) ...[
          AppSelectField<String?>(
            label: 'Vincular a evaluación agendada (opcional)',
            value: availableExams.any((e) => e.id == _selectedExamId)
                ? _selectedExamId
                : null,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Nota independiente'),
              ),
              ...availableExams.map(
                (e) => DropdownMenuItem<String?>(
                  value: e.id,
                  child: Text(
                    '${e.type.label}: ${e.title}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (val) {
              setState(() {
                _selectedExamId = val;
                if (val != null) {
                  final exam = availableExams.firstWhere((e) => e.id == val);
                  if (_titleController.text.trim().isEmpty) {
                    _titleController.text = exam.title;
                  }
                  if (exam.type == ExamType.retake) {
                    _isRetake = true;
                  }
                }
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text('Tipo de calificación', style: AppTypography.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: GradeKind.values.map((k) {
            return AppChip(
              label: k.label,
              isSelected: k == _kind,
              onTap: () => setState(() => _kind = k),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _titleController,
          label: 'Concepto / Evaluación',
          hint: 'Ej. 1er Parcial / TP Integrador / Final',
          errorText: _titleError,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (v) {
            if (_titleError != null && v.trim().isNotEmpty) {
              setState(() => _titleError = null);
            }
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: _valueController,
                label:
                    '${AppStrings.gradeValue} (0–${maxGrade.toStringAsFixed(0)})',
                hint: maxGrade == 100 ? 'Ej. 85' : 'Ej. 8.5',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                errorText: _valueError,
                prefixIcon: const Icon(Icons.workspace_premium_outlined),
                onChanged: (v) {
                  if (_valueError != null && v.trim().isNotEmpty) {
                    setState(() => _valueError = null);
                  }
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(
                controller: _weightController,
                label: 'Peso (%)',
                hint: '100',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                errorText: _weightError,
                prefixIcon: const Icon(Icons.scale_outlined),
                onChanged: (value) {
                  final parsed =
                      double.tryParse(value.trim().replaceAll(',', '.'));
                  if (_weightError != null &&
                      parsed != null &&
                      parsed > 0 &&
                      parsed <= 100) {
                    setState(() => _weightError = null);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: _pickDate,
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
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Fecha: ${AppFormatters.date(_date)}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Es nota de recuperatorio',
            style: AppTypography.titleSmall,
          ),
          subtitle: Text(
            'Permite reemplazar o promediar la calificación anterior',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          value: _isRetake,
          onChanged: (val) => setState(() => _isRetake = val),
        ),
        if (_isRetake) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppChip(
                label: 'Reemplaza nota original',
                isSelected: _replacesOriginal,
                onTap: () => setState(() => _replacesOriginal = true),
              ),
              AppChip(
                label: 'Promedia con original',
                isSelected: !_replacesOriginal,
                onTap: () => setState(() => _replacesOriginal = false),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            if (widget.gradeToEdit != null) ...[
              AppButton(
                label: 'Eliminar',
                icon: Icons.delete_outline_rounded,
                variant: AppButtonVariant.danger,
                onPressed: () async {
                  await ref
                      .read(gradeControllerProvider.notifier)
                      .deleteGrade(widget.gradeToEdit!.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: AppButton(
                label: widget.gradeToEdit == null
                    ? 'Registrar calificación'
                    : AppStrings.save,
                isLoading: _isSaving,
                onPressed: () => _submit(maxGrade),
                isExpanded: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
