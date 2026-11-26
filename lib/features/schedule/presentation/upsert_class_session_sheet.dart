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
import '../../subjects/data/subject_repository.dart';
import '../data/schedule_repository.dart';
import '../domain/class_session.dart';
import 'schedule_controller.dart';

class UpsertClassSessionSheet extends ConsumerStatefulWidget {
  final ClassSession? sessionToEdit;
  final String? preselectedSubjectId;
  final int? preselectedWeekday;

  const UpsertClassSessionSheet({
    super.key,
    this.sessionToEdit,
    this.preselectedSubjectId,
    this.preselectedWeekday,
  });

  static Future<void> show(
    BuildContext context, {
    ClassSession? sessionToEdit,
    String? preselectedSubjectId,
    int? preselectedWeekday,
  }) {
    return SpringSheet.show(
      context: context,
      title: sessionToEdit == null
          ? 'Nuevo horario de cursada'
          : 'Editar horario de cursada',
      subtitle: sessionToEdit == null
          ? 'Podés marcar varios días si la clase repite horario'
          : null,
      showCloseButton: true,
      child: UpsertClassSessionSheet(
        sessionToEdit: sessionToEdit,
        preselectedSubjectId: preselectedSubjectId,
        preselectedWeekday: preselectedWeekday,
      ),
    );
  }

  @override
  ConsumerState<UpsertClassSessionSheet> createState() =>
      _UpsertClassSessionSheetState();
}

class _UpsertClassSessionSheetState
    extends ConsumerState<UpsertClassSessionSheet> {
  late final TextEditingController _classroomController;
  late final TextEditingController _professorController;

  String? _selectedSubjectId;
  late Set<int> _selectedWeekdays;
  late int _startMinutes;
  late int _endMinutes;
  late ClassModality _modality;
  String? _error;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.sessionToEdit;
    _classroomController = TextEditingController(text: s?.classroom ?? '');
    _professorController = TextEditingController(text: s?.professor ?? '');
    _selectedSubjectId = s?.subjectId ?? widget.preselectedSubjectId;
    final initialDay = s?.weekday ??
        widget.preselectedWeekday ??
        DateTime.now().weekday.clamp(1, 6);
    _selectedWeekdays = {initialDay};
    _startMinutes = s?.startMinutes ?? 18 * 60;
    _endMinutes = s?.endMinutes ?? 20 * 60;
    _modality = s?.modality ?? ClassModality.inPerson;
  }

  @override
  void dispose() {
    _classroomController.dispose();
    _professorController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startMinutes : _endMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
    );
    if (picked == null) return;
    setState(() {
      final mins = picked.hour * 60 + picked.minute;
      if (isStart) {
        _startMinutes = mins;
        if (_endMinutes <= _startMinutes) {
          _endMinutes = (_startMinutes + 120).clamp(0, 23 * 60 + 59);
        }
      } else {
        _endMinutes = mins;
      }
      _error = null;
    });
  }

  bool _hasOverlap(List<ClassSession> existing) {
    for (final s in existing) {
      if (widget.sessionToEdit != null && s.id == widget.sessionToEdit!.id) {
        continue;
      }
      if (!_selectedWeekdays.contains(s.weekday)) continue;
      if (_startMinutes < s.endMinutes && _endMinutes > s.startMinutes) {
        return true;
      }
    }
    return false;
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (_selectedSubjectId == null) {
      setState(() => _error = 'Seleccioná una materia');
      return;
    }
    if (_selectedWeekdays.isEmpty) {
      setState(() => _error = 'Seleccioná al menos un día de cursada');
      return;
    }
    if (_endMinutes <= _startMinutes) {
      setState(() => _error = 'La hora de fin debe ser posterior al inicio');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final notifier = ref.read(scheduleControllerProvider.notifier);
    if (widget.sessionToEdit == null) {
      final sortedDays = _selectedWeekdays.toList()..sort();
      for (final day in sortedDays) {
        await notifier.createSession(
          subjectId: _selectedSubjectId!,
          weekday: day,
          startMinutes: _startMinutes,
          endMinutes: _endMinutes,
          classroom: _classroomController.text,
          modality: _modality,
          professor: _professorController.text,
        );
      }
    } else {
      final updated = widget.sessionToEdit!.copyWith(
        subjectId: _selectedSubjectId!,
        weekday: _selectedWeekdays.first,
        startMinutes: _startMinutes,
        endMinutes: _endMinutes,
        classroom: _classroomController.text.trim().isEmpty
            ? null
            : _classroomController.text.trim(),
        modality: _modality,
        professor: _professorController.text.trim().isEmpty
            ? null
            : _professorController.text.trim(),
      );
      await notifier.updateSession(updated);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsStreamProvider).value ?? const [];
    final allSessions =
        ref.watch(classSessionsStreamProvider).value ?? const [];
    if (_selectedSubjectId == null && subjects.isNotEmpty) {
      _selectedSubjectId = subjects.first.id;
    }
    final overlap = _hasOverlap(allSessions);

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
                        child: Text(
                          s.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _selectedSubjectId = val),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          widget.sessionToEdit == null ? 'Días de cursada' : 'Día de cursada',
          style: AppTypography.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(7, (index) {
            final day = index + 1;
            final selected = _selectedWeekdays.contains(day);
            return AppChip(
              label: ClassSession.weekdayShortName(day),
              isSelected: selected,
              onTap: () {
                setState(() {
                  if (widget.sessionToEdit != null) {
                    _selectedWeekdays = {day};
                  } else if (selected && _selectedWeekdays.length > 1) {
                    _selectedWeekdays.remove(day);
                  } else {
                    _selectedWeekdays.add(day);
                  }
                });
              },
            );
          }),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Franja horaria', style: AppTypography.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final preset in const [
                ('Mañana', 8 * 60, 11 * 60),
                ('Mediodía', 11 * 60, 14 * 60),
                ('Tarde', 14 * 60, 17 * 60),
                ('Vespertino', 18 * 60, 21 * 60),
                ('Noche', 19 * 60, 22 * 60),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: AppChip(
                    label: preset.$1,
                    isSelected: _startMinutes == preset.$2 &&
                        _endMinutes == preset.$3,
                    onTap: () => setState(() {
                      _startMinutes = preset.$2;
                      _endMinutes = preset.$3;
                    }),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _TimeBox(
                label: 'Inicio',
                timeText: ClassSession.formatMinutes(_startMinutes),
                onTap: () => _pickTime(isStart: true),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _TimeBox(
                label: 'Finalización',
                timeText: ClassSession.formatMinutes(_endMinutes),
                onTap: () => _pickTime(isStart: false),
              ),
            ),
          ],
        ),
        if (overlap) ...[
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
                  size: 18,
                  color: AppColors.warnFg(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Superposición detectada con otra clase en ese horario.',
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
        Text('Modalidad', style: AppTypography.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ClassModality.values
              .map(
                (m) => AppChip(
                  label: m.label,
                  isSelected: _modality == m,
                  onTap: () => setState(() => _modality = m),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _classroomController,
                label: 'Aula / Enlace',
                hint: 'Ej. Aula 304 / Zoom',
                prefixIcon: const Icon(Icons.room_outlined),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(
                controller: _professorController,
                label: 'Docente / Comisión',
                hint: 'Opcional',
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            style: AppTypography.caption.copyWith(
              color: AppColors.errFg(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            if (widget.sessionToEdit != null) ...[
              AppButton(
                label: 'Eliminar',
                icon: Icons.delete_outline_rounded,
                variant: AppButtonVariant.danger,
                onPressed: () async {
                  await ref
                      .read(scheduleControllerProvider.notifier)
                      .deleteSession(widget.sessionToEdit!.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: AppButton(
                label: widget.sessionToEdit == null
                    ? 'Guardar horario'
                    : 'Guardar cambios',
                isLoading: _isSaving,
                isExpanded: true,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String label;
  final String timeText;
  final VoidCallback onTap;

  const _TimeBox({
    required this.label,
    required this.timeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 12,
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
              Icons.access_time_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                ),
                Text(
                  '$timeText hs',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
