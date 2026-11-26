import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_spacing.dart';
import '../../../core/design_system/app_typography.dart';
import '../../../core/design_system/components/app_button.dart';
import '../../../core/design_system/components/app_card.dart';
import '../../../core/design_system/components/app_text_field.dart';
import '../../../core/design_system/components/spring_sheet.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../exams/data/exam_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../subjects/data/subject_repository.dart';
import '../data/grade_repository.dart';
import 'grade_controller.dart';

class GradeCalculatorSheet extends ConsumerStatefulWidget {
  final String? preselectedSubjectId;
  const GradeCalculatorSheet({super.key, this.preselectedSubjectId});

  static Future<void> show(
    BuildContext context, {
    String? preselectedSubjectId,
  }) {
    return SpringSheet.show(
      context: context,
      title: AppStrings.calculatorTitle,
      subtitle: 'Simulá qué nota necesitás para aprobar o promocionar',
      showCloseButton: true,
      child: GradeCalculatorSheet(preselectedSubjectId: preselectedSubjectId),
    );
  }

  @override
  ConsumerState<GradeCalculatorSheet> createState() =>
      _GradeCalculatorSheetState();
}

class _GradeCalculatorSheetState extends ConsumerState<GradeCalculatorSheet> {
  String? _selectedSubjectId;
  late final TextEditingController _targetController;
  final _weightController = TextEditingController(text: '100');
  double? _requiredGrade;
  bool _initializedScale = false;

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.preselectedSubjectId;
    _targetController = TextEditingController(text: '7.0');
  }

  @override
  void dispose() {
    _targetController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (_selectedSubjectId == null) return;
    final allGrades = ref.read(allGradesStreamProvider).value ?? const [];
    final allExams = ref.read(examsStreamProvider).value ?? const [];
    final subjectGrades =
        allGrades.where((g) => g.subjectId == _selectedSubjectId).toList();

    final target =
        double.tryParse(_targetController.text.trim().replaceAll(',', '.'));
    final remainingWeightPercent =
        double.tryParse(_weightController.text.trim().replaceAll(',', '.'));
    if (target == null ||
        remainingWeightPercent == null ||
        remainingWeightPercent <= 0) {
      setState(() => _requiredGrade = null);
      return;
    }

    final result = GradeCalculations.calculateRequiredGrade(
      currentGrades: subjectGrades,
      targetAverage: target,
      remainingWeight: remainingWeightPercent / 100.0,
      exams: allExams,
    );

    setState(() => _requiredGrade = result);
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsStreamProvider).value ?? const [];
    final allGrades = ref.watch(allGradesStreamProvider).value ?? const [];
    final allExams = ref.watch(examsStreamProvider).value ?? const [];
    final profile = ref.watch(profileStreamProvider).value;
    final maxGrade = profile?.maxScaleGrade ?? 10.0;

    if (!_initializedScale && profile != null) {
      _initializedScale = true;
      _targetController.text = maxGrade == 100 ? '70' : '7.0';
    }

    if (_selectedSubjectId == null && subjects.isNotEmpty) {
      _selectedSubjectId = subjects.first.id;
    }

    final selectedSubject =
        subjects.where((s) => s.id == _selectedSubjectId).firstOrNull;
    final subjectGrades = _selectedSubjectId == null
        ? const <Never>[]
        : allGrades.where((g) => g.subjectId == _selectedSubjectId).toList();
    final currentAvg = subjectGrades.isEmpty
        ? null
        : GradeCalculations.calculateAverage(subjectGrades, exams: allExams);
    final passingGrade =
        selectedSubject?.passingGrade ?? profile?.passingGrade ?? 4.0;

    final reachable = _requiredGrade != null && _requiredGrade! <= maxGrade;

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
              .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
              .toList(),
          onChanged: (val) {
            setState(() => _selectedSubjectId = val);
            _calculate();
          },
        ),
        if (currentAvg != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Promedio actual en esta materia: ${AppFormatters.grade(currentAvg, decimals: 2)} (${subjectGrades.length} notas)',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _targetController,
                label: 'Promedio objetivo',
                hint: maxGrade == 100 ? '70' : '7.0',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _calculate(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(
                controller: _weightController,
                label: 'Peso próximo examen (%)',
                hint: '100',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _calculate(),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_requiredGrade != null) ...[
          AppCard(
            color: (reachable ? AppColors.success : AppColors.error)
                .withValues(alpha: 0.12),
            border: BorderSide(
              color: (reachable ? AppColors.success : AppColors.error)
                  .withValues(alpha: 0.35),
            ),
            child: Column(
              children: [
                Text(
                  reachable
                      ? 'Calificación mínima necesaria'
                      : 'Meta fuera de escala con esa ponderación',
                  textAlign: TextAlign.center,
                  style: AppTypography.titleSmall.copyWith(
                    color: reachable
                        ? AppColors.okFg(context)
                        : AppColors.errFg(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _requiredGrade! <= 0
                      ? '0'
                      : _requiredGrade!.toStringAsFixed(2),
                  style: AppTypography.display.copyWith(
                    color: reachable
                        ? AppColors.okFg(context)
                        : AppColors.errFg(context),
                    fontSize: 38,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _requiredGrade! <= 0
                      ? 'Ya aseguraste este promedio objetivo.'
                      : (_requiredGrade! <= passingGrade
                          ? 'Con aprobar (${AppFormatters.grade(passingGrade)}) ya alcanzás tu objetivo.'
                          : (reachable
                              ? 'Necesitás al menos esta nota sobre ${maxGrade.toStringAsFixed(0)} en la próxima instancia.'
                              : 'Incluso obteniendo ${maxGrade.toStringAsFixed(0)} no llegás con ese peso.')),
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        AppButton(
          label: 'Calcular ahora',
          icon: Icons.calculate_rounded,
          onPressed: _calculate,
          isExpanded: true,
        ),
      ],
    );
  }
}
