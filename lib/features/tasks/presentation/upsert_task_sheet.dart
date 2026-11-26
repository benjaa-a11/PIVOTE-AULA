import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_spacing.dart';
import '../../../core/design_system/app_typography.dart';
import '../../../core/design_system/components/app_button.dart';
import '../../../core/design_system/components/app_chip.dart';
import '../../../core/design_system/components/app_text_field.dart';
import '../../../core/design_system/components/spring_sheet.dart';
import '../../../core/utils/formatters.dart';
import '../../subjects/data/subject_repository.dart';
import '../domain/academic_task.dart';
import 'task_controller.dart';

class UpsertTaskSheet extends ConsumerStatefulWidget {
  final AcademicTask? taskToEdit;
  final String? preselectedSubjectId;
  final DateTime? preselectedDate;

  const UpsertTaskSheet({
    super.key,
    this.taskToEdit,
    this.preselectedSubjectId,
    this.preselectedDate,
  });

  static Future<void> show(
    BuildContext context, {
    AcademicTask? taskToEdit,
    String? preselectedSubjectId,
    DateTime? preselectedDate,
  }) {
    return SpringSheet.show(
      context: context,
      title: taskToEdit == null ? 'Nueva tarea o entrega' : 'Editar tarea',
      showCloseButton: true,
      child: UpsertTaskSheet(
        taskToEdit: taskToEdit,
        preselectedSubjectId: preselectedSubjectId,
        preselectedDate: preselectedDate,
      ),
    );
  }

  @override
  ConsumerState<UpsertTaskSheet> createState() => _UpsertTaskSheetState();
}

class _UpsertTaskSheetState extends ConsumerState<UpsertTaskSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  String? _selectedSubjectId;
  DateTime? _dueDate;
  late TaskPriority _priority;
  late TaskCategory _category;
  String? _titleError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.taskToEdit;
    _titleController = TextEditingController(text: t?.title ?? '');
    _descriptionController = TextEditingController(text: t?.description ?? '');
    _selectedSubjectId = t?.subjectId ?? widget.preselectedSubjectId;
    _dueDate = t?.dueDate ?? widget.preselectedDate;
    _priority = t?.priority ?? TaskPriority.medium;
    _category = t?.category ?? TaskCategory.assignment;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (_titleController.text.trim().isEmpty) {
      setState(() => _titleError = 'Ingresá qué tenés que hacer o entregar');
      return;
    }

    setState(() => _isSaving = true);
    final notifier = ref.read(taskControllerProvider.notifier);

    if (widget.taskToEdit == null) {
      await notifier.createTask(
        subjectId: _selectedSubjectId,
        title: _titleController.text,
        description: _descriptionController.text,
        dueDate: _dueDate,
        priority: _priority,
        category: _category,
      );
    } else {
      final updated = widget.taskToEdit!.copyWith(
        subjectId: _selectedSubjectId,
        clearSubjectId: _selectedSubjectId == null,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        clearDescription: _descriptionController.text.trim().isEmpty,
        dueDate: _dueDate,
        clearDueDate: _dueDate == null,
        priority: _priority,
        category: _category,
      );
      await notifier.updateTask(updated);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsStreamProvider).value ?? const [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTextField(
          controller: _titleController,
          label: 'Título',
          hint: 'Ej. Entregar TP 2 / Inscripción a finales / Leer cap. 4',
          errorText: _titleError,
          autofocus: widget.taskToEdit == null,
          textCapitalization: TextCapitalization.sentences,
          prefixIcon: const Icon(Icons.task_alt_rounded),
          onChanged: (val) {
            if (_titleError != null && val.trim().isNotEmpty) {
              setState(() => _titleError = null);
            }
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppSelectField<String?>(
          label: 'Materia asociada (opcional)',
          value: _selectedSubjectId != null &&
                  subjects.any((s) => s.id == _selectedSubjectId)
              ? _selectedSubjectId
              : null,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('General / Trámite universitario'),
            ),
            ...subjects.map(
              (s) => DropdownMenuItem<String?>(
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
            ),
          ],
          onChanged: (val) => setState(() => _selectedSubjectId = val),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Categoría', style: AppTypography.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TaskCategory.values
              .map(
                (c) => AppChip(
                  label: c.label,
                  isSelected: _category == c,
                  onTap: () => setState(() => _category = c),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Fecha límite', style: AppTypography.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppChip(
              label: 'Sin fecha',
              isSelected: _dueDate == null,
              onTap: () => setState(() => _dueDate = null),
            ),
            AppChip(
              label: 'Hoy',
              isSelected:
                  _dueDate != null && DateUtils.isSameDay(_dueDate, today),
              onTap: () => setState(() => _dueDate = today),
            ),
            AppChip(
              label: 'Mañana',
              isSelected:
                  _dueDate != null && DateUtils.isSameDay(_dueDate, tomorrow),
              onTap: () => setState(() => _dueDate = tomorrow),
            ),
            AppChip(
              label: 'En 7 días',
              isSelected:
                  _dueDate != null && DateUtils.isSameDay(_dueDate, nextWeek),
              onTap: () => setState(() => _dueDate = nextWeek),
            ),
            AppChip(
              label: _dueDate == null
                  ? 'Elegir fecha...'
                  : AppFormatters.date(_dueDate!),
              icon: const Icon(Icons.calendar_today_rounded, size: 14),
              isSelected: _dueDate != null &&
                  !DateUtils.isSameDay(_dueDate, today) &&
                  !DateUtils.isSameDay(_dueDate, tomorrow) &&
                  !DateUtils.isSameDay(_dueDate, nextWeek),
              onTap: _pickCustomDate,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Prioridad', style: AppTypography.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TaskPriority.values.map((p) {
            final color = switch (p) {
              TaskPriority.low => AppColors.pending,
              TaskPriority.medium => AppColors.info,
              TaskPriority.high => AppColors.warning,
              TaskPriority.urgent => AppColors.error,
            };
            return AppChip(
              label: p.label,
              activeColor: color,
              isSelected: _priority == p,
              onTap: () => setState(() => _priority = p),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _descriptionController,
          label: 'Notas o consignas (opcional)',
          hint: 'Detalles, enlaces, requisitos de entrega...',
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            if (widget.taskToEdit != null) ...[
              AppButton(
                label: 'Eliminar',
                icon: Icons.delete_outline_rounded,
                variant: AppButtonVariant.danger,
                onPressed: () async {
                  await ref
                      .read(taskControllerProvider.notifier)
                      .deleteTask(widget.taskToEdit!.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: AppButton(
                label: widget.taskToEdit == null
                    ? 'Guardar pendiente'
                    : 'Guardar cambios',
                isLoading: _isSaving,
                isExpanded: true,
                onPressed: _submit,
              ),
            ),
          ],
        ),
        if (widget.taskToEdit != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                await ref
                    .read(taskControllerProvider.notifier)
                    .toggleCompleted(widget.taskToEdit!);
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: Icon(
                widget.taskToEdit!.isCompleted
                    ? Icons.replay_rounded
                    : Icons.check_circle_outline_rounded,
                size: 18,
              ),
              label: Text(
                widget.taskToEdit!.isCompleted
                    ? 'Marcar como pendiente'
                    : 'Marcar como completada',
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}
