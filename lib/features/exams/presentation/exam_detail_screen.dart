import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_radius.dart';
import '../../../core/design_system/app_scroll_physics.dart';
import '../../../core/design_system/app_spacing.dart';
import '../../../core/design_system/app_typography.dart';
import '../../../core/design_system/components/app_button.dart';
import '../../../core/design_system/components/app_card.dart';
import '../../../core/design_system/components/empty_state.dart';
import '../../../core/design_system/components/pressable_scale.dart';
import '../../../core/design_system/responsive.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../grades/data/grade_repository.dart';
import '../../grades/presentation/upsert_grade_sheet.dart';
import '../../subjects/data/subject_repository.dart';
import '../../topics/data/topic_repository.dart';
import '../../topics/domain/topic.dart';
import '../../topics/presentation/topic_controller.dart';
import '../../topics/presentation/upsert_topic_sheet.dart';
import '../data/exam_repository.dart';
import 'exam_controller.dart';
import 'upsert_exam_sheet.dart';

class ExamDetailScreen extends ConsumerWidget {
  final String examId;
  const ExamDetailScreen({super.key, required this.examId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final examsAsync = ref.watch(examsStreamProvider);
    final exam = examsAsync.value?.where((e) => e.id == examId).firstOrNull;

    if (exam == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Evaluación no encontrada')),
      );
    }

    final subjects = ref.watch(subjectsStreamProvider).value ?? const [];
    final subject = subjects.where((s) => s.id == exam.subjectId).firstOrNull;
    final subjectColor =
        subject != null ? Color(subject.colorValue) : theme.colorScheme.primary;
    final readableSub = AppColors.readableAccent(subjectColor, isDark: isDark);

    final topics = ref.watch(examTopicsStreamProvider(exam.id)).value ?? const [];
    final allGrades = ref.watch(allGradesStreamProvider).value ?? const [];
    final linkedGrade =
        allGrades.where((g) => g.examId == exam.id).firstOrNull;

    final progress = topics.isEmpty
        ? 0.0
        : topics.fold<double>(0.0, (acc, t) => acc + t.status.progressValue) /
            topics.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(exam.type.label, style: AppTypography.titleLarge),
        actions: [
          IconButton(
            tooltip: 'Editar evaluación',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => UpsertExamSheet.show(context, examToEdit: exam),
          ),
          IconButton(
            tooltip: 'Eliminar evaluación',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('¿Eliminar evaluación?'),
                  content: Text(
                    'Se ocultará "${exam.title}". Podés deshacer la acción.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        'Eliminar',
                        style: TextStyle(color: AppColors.errFg(ctx)),
                      ),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                ref.read(examControllerProvider.notifier).deleteExam(exam.id);
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Se eliminó ${exam.title}'),
                    action: SnackBarAction(
                      label: AppStrings.undo,
                      onPressed: () => ref
                          .read(examControllerProvider.notifier)
                          .restoreExam(exam.id),
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          context.pageHorizontalPadding,
          AppSpacing.lg,
          context.pageHorizontalPadding,
          64,
        ),
        physics: appScrollPhysics(),
        children: [
          ResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          if (subject != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: ShapeDecoration(
                                color: subjectColor.withValues(
                                  alpha: isDark ? 0.22 : 0.12,
                                ),
                                shape: AppRadius.continuousSm(),
                              ),
                              child: Text(
                                subject.name,
                                style: AppTypography.caption.copyWith(
                                  color: readableSub,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: ShapeDecoration(
                              color: AppColors.warning.withValues(
                                alpha: isDark ? 0.20 : 0.12,
                              ),
                              shape: AppRadius.continuousSm(),
                            ),
                            child: Text(
                              AppFormatters.countdown(exam.dateTime),
                              style: AppTypography.caption.copyWith(
                                color: AppColors.warnFg(context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        exam.title,
                        style: AppTypography.titleLarge.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 15,
                                color: AppColors.textTertiary(context),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${AppFormatters.date(exam.dateTime)} · ${AppFormatters.time(exam.dateTime)} hs (${exam.durationMinutes} min)',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                          if (exam.classroom != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.room_outlined,
                                  size: 16,
                                  color: AppColors.textTertiary(context),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  exam.classroom!,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (linkedGrade != null)
                        AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          color: AppColors.surfaceSubtle(context),
                          onTap: () => UpsertGradeSheet.show(
                            context,
                            gradeToEdit: linkedGrade,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Calificación obtenida',
                                    style: AppTypography.titleSmall,
                                  ),
                                  Text(
                                    'Tocá para editar (${AppFormatters.date(linkedGrade.date)})',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                AppFormatters.grade(
                                  linkedGrade.value,
                                  decimals: 2,
                                ),
                                style: AppTypography.display.copyWith(
                                  fontSize: 28,
                                  color: linkedGrade.value >=
                                          (subject?.passingGrade ?? 4.0)
                                      ? AppColors.okFg(context)
                                      : AppColors.errFg(context),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        AppButton(
                          label: 'Registrar calificación',
                          icon: Icons.workspace_premium_rounded,
                          variant: AppButtonVariant.secondary,
                          isExpanded: true,
                          onPressed: () => UpsertGradeSheet.show(
                            context,
                            preselectedSubjectId: exam.subjectId,
                            preselectedExamId: exam.id,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Study Checklist Progress
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            AppStrings.topics,
                            style: AppTypography.titleMedium,
                          ),
                          Text(
                            '${(progress * 100).round()}% preparado',
                            style: AppTypography.caption.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      LinearProgressIndicator(value: progress, minHeight: 8),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Tocá el indicador circular para actualizar estado de repaso o arrastrá desde la derecha para ordenar.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                if (topics.isEmpty)
                  EmptyState(
                    icon: Icons.checklist_rounded,
                    title: 'Sin temas cargados',
                    description:
                        'Desglosá las unidades que entran en esta evaluación.',
                    actionLabel: AppStrings.addTopic,
                    onAction: () => UpsertTopicSheet.show(
                      context,
                      subjectId: exam.subjectId,
                      examId: exam.id,
                    ),
                  )
                else ...[
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: topics.length,
                    onReorder: (oldIndex, newIndex) {
                      ref.read(topicControllerProvider.notifier).reorderTopics(
                            List.of(topics),
                            oldIndex,
                            newIndex,
                          );
                    },
                    itemBuilder: (context, index) {
                      final t = topics[index];
                      final stColor = _topicStatusColor(context, t.status);
                      return Padding(
                        key: Key(t.id),
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              PressableScale(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  ref
                                      .read(topicControllerProvider.notifier)
                                      .toggleStatus(t);
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: stColor.withValues(alpha: 0.16),
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: stColor, width: 1.8),
                                  ),
                                  child: Icon(
                                    _topicStatusIcon(t.status),
                                    size: 15,
                                    color: stColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => UpsertTopicSheet.show(
                                    context,
                                    subjectId: exam.subjectId,
                                    examId: exam.id,
                                    topicToEdit: t,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.title,
                                        style: AppTypography.titleSmall.copyWith(
                                          decoration:
                                              t.status == TopicStatus.mastered
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                        ),
                                      ),
                                      Text(
                                        '${t.status.label} · Prioridad ${t.priority.label}',
                                        style: AppTypography.caption.copyWith(
                                          color: stColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.drag_indicator_rounded,
                                    color: AppColors.textTertiary(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: AppButton(
                      label: 'Agregar otro tema',
                      icon: Icons.add_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => UpsertTopicSheet.show(
                        context,
                        subjectId: exam.subjectId,
                        examId: exam.id,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _topicStatusColor(BuildContext context, TopicStatus status) {
    switch (status) {
      case TopicStatus.todo:
        return AppColors.textTertiary(context);
      case TopicStatus.studying:
        return AppColors.warnFg(context);
      case TopicStatus.reviewed:
        return AppColors.info;
      case TopicStatus.mastered:
        return AppColors.okFg(context);
    }
  }

  IconData _topicStatusIcon(TopicStatus status) {
    switch (status) {
      case TopicStatus.todo:
        return Icons.circle_outlined;
      case TopicStatus.studying:
        return Icons.timelapse_rounded;
      case TopicStatus.reviewed:
        return Icons.refresh_rounded;
      case TopicStatus.mastered:
        return Icons.check_rounded;
    }
  }
}
