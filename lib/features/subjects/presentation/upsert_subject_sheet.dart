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
import '../../profile/data/profile_repository.dart';
import '../domain/subject.dart';
import '../domain/subject_icons.dart';
import 'subject_controller.dart';
import 'subject_form_preferences.dart';

class UpsertSubjectSheet extends ConsumerStatefulWidget {
  final Subject? subjectToEdit;

  const UpsertSubjectSheet({super.key, this.subjectToEdit});

  static Future<void> show(BuildContext context, {Subject? subjectToEdit}) {
    return SpringSheet.show(
      context: context,
      title: subjectToEdit == null
          ? AppStrings.newSubject
          : AppStrings.editSubject,
      showCloseButton: true,
      child: UpsertSubjectSheet(subjectToEdit: subjectToEdit),
    );
  }

  @override
  ConsumerState<UpsertSubjectSheet> createState() => _UpsertSubjectSheetState();
}

class _UpsertSubjectSheetState extends ConsumerState<UpsertSubjectSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _periodController;
  late final TextEditingController _codeController;
  late final TextEditingController _professorController;
  late final TextEditingController _classroomController;
  late final TextEditingController _creditsController;
  late final TextEditingController _notesController;

  late int _selectedColor;
  late int _selectedIcon;
  late SubjectStatus _selectedStatus;
  late double _passingGrade;
  String? _nameError;
  bool _showAdvancedFields = false;
  bool _isSaving = false;
  String? _saveError;
  bool _initializedFromProfile = false;

  @override
  void initState() {
    super.initState();
    final s = widget.subjectToEdit;
    _nameController = TextEditingController(text: s?.name ?? '');
    _periodController = TextEditingController(text: s?.period ?? '');
    _codeController = TextEditingController(text: s?.code ?? '');
    _professorController = TextEditingController(text: s?.professor ?? '');
    _classroomController = TextEditingController(text: s?.classroom ?? '');
    _creditsController =
        TextEditingController(text: s?.credits?.toString() ?? '');
    _notesController = TextEditingController(text: s?.notes ?? '');

    _selectedColor = s?.colorValue ?? AppColors.subjectColors.first.toARGB32();
    _selectedIcon = s?.iconCode ?? SubjectIcons.available.first.codePoint;
    _selectedStatus = s?.status ?? SubjectStatus.enrolled;
    _passingGrade = s?.passingGrade ?? 4.0;
    _showAdvancedFields = s != null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _periodController.dispose();
    _codeController.dispose();
    _professorController.dispose();
    _classroomController.dispose();
    _creditsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'Ingresá el nombre de la materia');
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      final profile = await ref.read(profileRepositoryProvider).getProfile();
      final typedPeriod = _periodController.text.trim();
      final period = typedPeriod.isNotEmpty
          ? typedPeriod
          : (profile?.currentPeriod ?? '1er Cuatrimestre');
      final credits = int.tryParse(_creditsController.text.trim());

      if (widget.subjectToEdit == null) {
        await ref.read(subjectControllerProvider.notifier).createSubject(
              name: _nameController.text,
              code: _codeController.text,
              colorValue: _selectedColor,
              iconCode: _selectedIcon,
              professor: _professorController.text,
              classroom: _classroomController.text,
              credits: credits,
              status: _selectedStatus,
              period: period,
              passingGrade: _passingGrade,
              notes: _notesController.text,
            );
      } else {
        final original = widget.subjectToEdit!;
        final updated = original.copyWith(
          name: _nameController.text.trim(),
          period: period,
          code: _codeController.text.trim().isEmpty
              ? null
              : _codeController.text.trim(),
          colorValue: _selectedColor,
          iconCode: _selectedIcon,
          professor: _professorController.text.trim().isEmpty
              ? null
              : _professorController.text.trim(),
          classroom: _classroomController.text.trim().isEmpty
              ? null
              : _classroomController.text.trim(),
          credits: credits,
          status: _selectedStatus,
          passingGrade: _passingGrade,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
        await ref
            .read(subjectControllerProvider.notifier)
            .updateSubject(updated);
      }

      final result = ref.read(subjectControllerProvider);
      if (result.hasError) {
        throw result.error ?? Exception('No se pudo guardar la materia.');
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saveError =
            'No se pudo guardar. Revisá los datos e intentá otra vez.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final preferences = ref.watch(subjectFormPreferencesProvider);
    final profile = ref.watch(profileStreamProvider).value;

    if (!_initializedFromProfile && profile != null) {
      _initializedFromProfile = true;
      if (widget.subjectToEdit == null) {
        if (_periodController.text.isEmpty) {
          _periodController.text = profile.currentPeriod;
        }
        _passingGrade = profile.passingGrade;
      }
    }

    final isHundredScale = profile?.gradeScale == '0-100' || _passingGrade > 10;
    final sliderMin = isHundredScale ? 40.0 : 1.0;
    final sliderMax = isHundredScale ? 100.0 : 10.0;
    final clampedPassing = _passingGrade.clamp(sliderMin, sliderMax).toDouble();
    final yearNow = DateTime.now().year;
    final suggestedPeriods = <String>{
      if (profile?.currentPeriod.trim().isNotEmpty == true)
        profile!.currentPeriod.trim(),
      '1er Cuatrimestre $yearNow',
      '2do Cuatrimestre $yearNow',
      'Anual $yearNow',
    }.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTextField(
          controller: _nameController,
          label: AppStrings.subjectName,
          hint: 'Ej. Análisis Matemático II',
          errorText: _nameError,
          autofocus: widget.subjectToEdit == null,
          textCapitalization: TextCapitalization.words,
          prefixIcon: const Icon(Icons.auto_stories_outlined),
          onChanged: (v) {
            if (_nameError != null && v.trim().isNotEmpty) {
              setState(() => _nameError = null);
            }
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _periodController,
          label: 'Período / Cuatrimestre',
          hint: 'Ej. 1er Cuatrimestre 2026',
          prefixIcon: const Icon(Icons.date_range_rounded),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSpacing.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: suggestedPeriods
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: AppChip(
                      label: p,
                      isSelected: _periodController.text.trim() == p,
                      activeColor: Color(_selectedColor),
                      onTap: () => setState(() => _periodController.text = p),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (preferences.showStatusSelector) ...[
          Text(AppStrings.status, style: AppTypography.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SubjectStatus.values.map((status) {
              final isSelected = status == _selectedStatus;
              return AppChip(
                label: status.label,
                isSelected: isSelected,
                activeColor: Color(_selectedColor),
                onTap: () => setState(() => _selectedStatus = status),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_showAdvancedFields) ...[
          if (preferences.showColorPicker) ...[
            Text('Color identificatorio', style: AppTypography.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: AppColors.subjectColors.map((color) {
                final isSelected = color.toARGB32() == _selectedColor;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selectedColor = color.toARGB32()),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.textPrimary(context)
                            : Colors.transparent,
                        width: 2.2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 19,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (preferences.showIconPicker) ...[
            Text('Ícono representativo', style: AppTypography.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SubjectIcons.available.map((icon) {
                final isSelected = icon.codePoint == _selectedIcon;
                final selColor = AppColors.readableAccent(
                  Color(_selectedColor),
                  isDark: isDark,
                );
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selectedIcon = icon.codePoint),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: ShapeDecoration(
                      color: isSelected
                          ? Color(_selectedColor)
                              .withValues(alpha: isDark ? 0.24 : 0.12)
                          : AppColors.surfaceSubtle(context),
                      shape: AppRadius.continuousSm(
                        side: BorderSide(
                          color: isSelected
                              ? selColor
                              : AppColors.border(context),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isSelected
                          ? selColor
                          : AppColors.textSecondary(context),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (preferences.showCodeField && preferences.showCreditsField)
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _codeController,
                    label: AppStrings.subjectCode,
                    hint: 'Ej. AM2-204',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    controller: _creditsController,
                    label: AppStrings.credits,
                    hint: 'Ej. 6',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            )
          else if (preferences.showCodeField)
            AppTextField(
              controller: _codeController,
              label: AppStrings.subjectCode,
              hint: 'Ej. AM2-204',
            )
          else if (preferences.showCreditsField)
            AppTextField(
              controller: _creditsController,
              label: AppStrings.credits,
              hint: 'Ej. 6',
              keyboardType: TextInputType.number,
            ),
          if (preferences.showCodeField || preferences.showCreditsField)
            const SizedBox(height: AppSpacing.md),
          if (preferences.showProfessorField && preferences.showClassroomField)
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _professorController,
                    label: AppStrings.professor,
                    hint: 'Ej. Ing. Rossi',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    controller: _classroomController,
                    label: AppStrings.classroom,
                    hint: 'Ej. Aula 402',
                    prefixIcon: const Icon(Icons.room_outlined),
                  ),
                ),
              ],
            )
          else if (preferences.showProfessorField)
            AppTextField(
              controller: _professorController,
              label: AppStrings.professor,
              hint: 'Ej. Ing. Rossi',
              prefixIcon: const Icon(Icons.person_outline_rounded),
            )
          else if (preferences.showClassroomField)
            AppTextField(
              controller: _classroomController,
              label: AppStrings.classroom,
              hint: 'Ej. Aula 402',
              prefixIcon: const Icon(Icons.room_outlined),
            ),
          if (preferences.showProfessorField || preferences.showClassroomField)
            const SizedBox(height: AppSpacing.md),
          if (preferences.showPassingGrade) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  AppStrings.passingGrade,
                  style: AppTypography.titleSmall,
                ),
                Text(
                  isHundredScale
                      ? clampedPassing.toStringAsFixed(0)
                      : clampedPassing.toStringAsFixed(1),
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.readableAccent(
                      Color(_selectedColor),
                      isDark: isDark,
                    ),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Slider(
              value: clampedPassing,
              min: sliderMin,
              max: sliderMax,
              divisions: isHundredScale ? 12 : 18,
              activeColor: Color(_selectedColor),
              onChanged: (value) => setState(() => _passingGrade = value),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (preferences.showNotesField) ...[
            AppTextField(
              controller: _notesController,
              label: 'Régimen de promoción / Apuntes',
              hint: 'Ej. Promoción directa con 2 parciales >= 7...',
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ] else ...[
          AppButton(
            label: 'Personalizar color, ícono, docente y créditos',
            icon: Icons.tune_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () => setState(() => _showAdvancedFields = true),
            isExpanded: true,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_saveError != null) ...[
          Text(
            _saveError!,
            style: AppTypography.caption.copyWith(color: theme.colorScheme.error),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppButton(
          label: widget.subjectToEdit == null
              ? 'Guardar materia'
              : AppStrings.save,
          onPressed: _isSaving ? null : _submit,
          isLoading: _isSaving,
          isExpanded: true,
        ),
      ],
    );
  }
}
