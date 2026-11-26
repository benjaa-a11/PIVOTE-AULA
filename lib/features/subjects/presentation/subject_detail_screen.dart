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
import '../../../core/design_system/components/app_text_field.dart';
import '../../../core/design_system/components/empty_state.dart';
import '../../../core/design_system/responsive.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/domain/attendance_record.dart';
import '../../attendance/presentation/attendance_controller.dart';
import '../../exams/data/exam_repository.dart';
import '../../exams/presentation/upsert_exam_sheet.dart';
import '../../grades/data/grade_repository.dart';
import '../../grades/presentation/grade_calculator_sheet.dart';
import '../../grades/presentation/grade_controller.dart';
import '../../grades/presentation/upsert_grade_sheet.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../schedule/presentation/upsert_class_session_sheet.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/presentation/task_controller.dart';
import '../../tasks/presentation/upsert_task_sheet.dart';
import '../../topics/data/topic_repository.dart';
import '../../topics/domain/topic.dart';
import '../../topics/presentation/topic_controller.dart';
import '../../topics/presentation/upsert_topic_sheet.dart';
import '../data/subject_repository.dart';
import '../domain/subject.dart';
import '../domain/subject_icons.dart';
import 'subject_controller.dart';
import 'upsert_subject_sheet.dart';

class SubjectDetailScreen extends ConsumerStatefulWidget {
  final String subjectId;
  const SubjectDetailScreen({super.key, required this.subjectId});

  @override
  ConsumerState<SubjectDetailScreen> createState() =>
      _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends ConsumerState<SubjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subjectsAsync = ref.watch(subjectsStreamProvider);

    return subjectsAsync.when(
      data: (subjects) {
        final subject =
            subjects.where((s) => s.id == widget.subjectId).firstOrNull;
        if (subject == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Materia no encontrada')),
          );
        }

        final subjectColor = Color(subject.colorValue);
        final readableSub =
            AppColors.readableAccent(subjectColor, isDark: isDark);

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            title: Text(
              subject.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Editar materia',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => UpsertSubjectSheet.show(
                  context,
                  subjectToEdit: subject,
                ),
              ),
              IconButton(
                tooltip: 'Eliminar materia',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('¿Eliminar materia?'),
                      content: Text(
                        'Se ocultará "${subject.name}". Podés deshacer la acción.',
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
                  if (confirmed == true && mounted) {
                    ref
                        .read(subjectControllerProvider.notifier)
                        .deleteSubject(subject.id);
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Se eliminó ${subject.name}'),
                        action: SnackBarAction(
                          label: AppStrings.undo,
                          onPressed: () => ref
                              .read(subjectControllerProvider.notifier)
                              .restoreSubject(subject.id),
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Subject Summary Header Banner
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  border: Border(
                    bottom: BorderSide(color: AppColors.border(context)),
                  ),
                ),
                child: ResponsiveContainer(
                  padding: EdgeInsets.fromLTRB(
                    context.pageHorizontalPadding,
                    AppSpacing.xs,
                    context.pageHorizontalPadding,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Hero(
                            tag: 'subject_icon_${subject.id}',
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: ShapeDecoration(
                                color: subjectColor,
                                shape: AppRadius.continuousMd(),
                              ),
                              child: Icon(
                                SubjectIcons.fromCodePoint(subject.iconCode),
                                color: Colors.white,
                                size: 23,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _MetaBadge(
                                  text: subject.status.label,
                                  color: readableSub,
                                  bg: subjectColor.withValues(
                                    alpha: isDark ? 0.22 : 0.12,
                                  ),
                                ),
                                _MetaBadge(
                                  text: subject.period,
                                  color: AppColors.textSecondary(context),
                                  bg: AppColors.surfaceSubtle(context),
                                ),
                                if (subject.code != null)
                                  _MetaBadge(
                                    text: subject.code!,
                                    color: AppColors.textSecondary(context),
                                    bg: AppColors.surfaceSubtle(context),
                                  ),
                                if (subject.professor != null)
                                  _MetaBadge(
                                    icon: Icons.person_outline_rounded,
                                    text: subject.professor!,
                                    color: AppColors.textSecondary(context),
                                    bg: AppColors.surfaceSubtle(context),
                                  ),
                                if (subject.classroom != null)
                                  _MetaBadge(
                                    icon: Icons.room_outlined,
                                    text: subject.classroom!,
                                    color: AppColors.textSecondary(context),
                                    bg: AppColors.surfaceSubtle(context),
                                  ),
                                _MetaBadge(
                                  text:
                                      'Aprueba >= ${AppFormatters.grade(subject.passingGrade)}',
                                  color: readableSub,
                                  bg: subjectColor.withValues(
                                    alpha: isDark ? 0.16 : 0.08,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicatorColor: readableSub,
                        labelColor: readableSub,
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(text: 'Cursada y Asistencia'),
                          Tab(text: 'Exámenes y TPs'),
                          Tab(text: 'Temas'),
                          Tab(text: 'Calificaciones'),
                          Tab(text: 'Apuntes'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _SubjectScheduleAndAttendanceTab(subject: subject),
                    _SubjectExamsAndTasksTab(subject: subject),
                    _SubjectTopicsTab(subject: subject),
                    _SubjectGradesTab(subject: subject),
                    _SubjectNotesTab(subject: subject),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Color color;
  final Color bg;

  const _MetaBadge({
    this.icon,
    required this.text,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppRadius.continuousSm(
          side: BorderSide(color: AppColors.border(context)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectScheduleAndAttendanceTab extends ConsumerWidget {
  final Subject subject;
  const _SubjectScheduleAndAttendanceTab({required this.subject});

  Future<void> _logQuickAttendance(
    BuildContext context,
    WidgetRef ref,
    AttendanceStatus status,
  ) async {
    HapticFeedback.lightImpact();
    await ref.read(attendanceControllerProvider.notifier).logAttendance(
          subjectId: subject.id,
          date: DateTime.now(),
          status: status,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Asistencia registrada: ${status.label}')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions =
        ref.watch(subjectSessionsStreamProvider(subject.id)).value ?? const [];
    final records =
        ref.watch(subjectAttendanceStreamProvider(subject.id)).value ??
            const [];
    final summary = AttendanceSummary.fromRecords(records);
    final isRegularOk = summary.percentage >= 75.0;
    final subjectColor = Color(subject.colorValue);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final readableSub = AppColors.readableAccent(subjectColor, isDark: isDark);

    return ListView(
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
              // Horarios de cursada
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Horarios de cursada',
                    style: AppTypography.titleMedium,
                  ),
                  AppButton(
                    label: 'Agregar horario',
                    icon: Icons.add_rounded,
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => UpsertClassSessionSheet.show(
                      context,
                      preselectedSubjectId: subject.id,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (sessions.isEmpty)
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'Todavía no registraste en qué días y horarios cursás esta materia.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                )
              else
                ...sessions.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      onTap: () => UpsertClassSessionSheet.show(
                        context,
                        sessionToEdit: s,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: ShapeDecoration(
                              color: subjectColor.withValues(
                                alpha: isDark ? 0.22 : 0.12,
                              ),
                              shape: AppRadius.continuousSm(),
                            ),
                            child: Text(
                              s.weekdayLabel,
                              style: AppTypography.label.copyWith(
                                color: readableSub,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${s.timeRangeLabel} hs',
                                  style: AppTypography.titleSmall,
                                ),
                                Text(
                                  [
                                    s.modality.label,
                                    if (s.classroom != null) s.classroom!,
                                    if (s.professor != null) s.professor!,
                                  ].join(' · '),
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: AppColors.textTertiary(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: AppSpacing.xl),

              // Control de Asistencia
              const Text(
                'Control de asistencia',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Asistencia efectiva',
                              style: AppTypography.titleSmall,
                            ),
                            Text(
                              summary.heldClasses == 0
                                  ? 'Sin clases registradas aún'
                                  : '${summary.presents} presentes · ${summary.absents} faltas · ${summary.justified} justif.',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${summary.percentage.round()}%',
                          style: AppTypography.display.copyWith(
                            fontSize: 28,
                            color: isRegularOk
                                ? AppColors.okFg(context)
                                : AppColors.errFg(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Registrar clase de hoy (${AppFormatters.date(DateTime.now())}):',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppButton(
                          label: 'Presente',
                          icon: Icons.check_rounded,
                          size: AppButtonSize.sm,
                          onPressed: () => _logQuickAttendance(
                            context,
                            ref,
                            AttendanceStatus.present,
                          ),
                        ),
                        AppButton(
                          label: 'Ausente',
                          icon: Icons.close_rounded,
                          size: AppButtonSize.sm,
                          variant: AppButtonVariant.danger,
                          onPressed: () => _logQuickAttendance(
                            context,
                            ref,
                            AttendanceStatus.absent,
                          ),
                        ),
                        AppButton(
                          label: 'Justificada',
                          size: AppButtonSize.sm,
                          variant: AppButtonVariant.secondary,
                          onPressed: () => _logQuickAttendance(
                            context,
                            ref,
                            AttendanceStatus.justified,
                          ),
                        ),
                        AppButton(
                          label: 'Sin clase',
                          size: AppButtonSize.sm,
                          variant: AppButtonVariant.secondary,
                          onPressed: () => _logQuickAttendance(
                            context,
                            ref,
                            AttendanceStatus.cancelled,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (records.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                ...records.take(20).map((r) {
                  final statusColor = switch (r.status) {
                    AttendanceStatus.present => AppColors.okFg(context),
                    AttendanceStatus.absent => AppColors.errFg(context),
                    AttendanceStatus.justified => AppColors.warnFg(context),
                    AttendanceStatus.cancelled =>
                      AppColors.textSecondary(context),
                  };
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 9, color: statusColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              AppFormatters.date(r.date),
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            r.status.label,
                            style: AppTypography.caption.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 17,
                            tooltip: 'Borrar registro',
                            onPressed: () => ref
                                .read(attendanceControllerProvider.notifier)
                                .deleteAttendance(r.id),
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.textTertiary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SubjectExamsAndTasksTab extends ConsumerWidget {
  final Subject subject;
  const _SubjectExamsAndTasksTab({required this.subject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allExams = ref.watch(examsStreamProvider).value ?? const [];
    final exams = allExams.where((e) => e.subjectId == subject.id).toList();
    final tasks =
        ref.watch(subjectTasksStreamProvider(subject.id)).value ?? const [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = Color(subject.colorValue);
    final readableSub = AppColors.readableAccent(subColor, isDark: isDark);

    return ListView(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Evaluaciones', style: AppTypography.titleMedium),
                  AppButton(
                    label: 'Nueva evaluación',
                    icon: Icons.add_rounded,
                    size: AppButtonSize.sm,
                    onPressed: () => UpsertExamSheet.show(
                      context,
                      preselectedSubjectId: subject.id,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (exams.isEmpty)
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'Sin parciales, recuperatorios ni finales agendados.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                )
              else
                ...exams.map((exam) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      onTap: () => context.push('/exams/${exam.id}'),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: ShapeDecoration(
                                        color: subColor.withValues(
                                          alpha: isDark ? 0.22 : 0.12,
                                        ),
                                        shape: AppRadius.continuousSm(),
                                      ),
                                      child: Text(
                                        exam.type.label,
                                        style: AppTypography.caption.copyWith(
                                          color: readableSub,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppFormatters.countdown(exam.dateTime),
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.warnFg(context),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(exam.title, style: AppTypography.titleSmall),
                                Text(
                                  [
                                    '${AppFormatters.date(exam.dateTime)} ${AppFormatters.time(exam.dateTime)} hs',
                                    if (exam.classroom != null) exam.classroom!,
                                  ].join(' · '),
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Editar evaluación',
                            icon: const Icon(Icons.edit_outlined, size: 19),
                            onPressed: () =>
                                UpsertExamSheet.show(context, examToEdit: exam),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Entregas, TPs y lecturas',
                    style: AppTypography.titleMedium,
                  ),
                  AppButton(
                    label: 'Nueva tarea',
                    icon: Icons.add_rounded,
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => UpsertTaskSheet.show(
                      context,
                      preselectedSubjectId: subject.id,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (tasks.isEmpty)
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'Sin entregas ni pendientes activos en esta materia.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                )
              else
                ...tasks.map((t) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      onTap: () =>
                          UpsertTaskSheet.show(context, taskToEdit: t),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => ref
                                .read(taskControllerProvider.notifier)
                                .toggleCompleted(t),
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(right: AppSpacing.md),
                              child: Icon(
                                t.isCompleted
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: t.isCompleted
                                    ? AppColors.okFg(context)
                                    : AppColors.textSecondary(context),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.title,
                                  style: AppTypography.titleSmall.copyWith(
                                    decoration: t.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                Text(
                                  [
                                    t.category.label,
                                    if (t.dueDate != null)
                                      AppFormatters.date(t.dueDate!),
                                  ].join(' · '),
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubjectTopicsTab extends ConsumerWidget {
  final Subject subject;
  const _SubjectTopicsTab({required this.subject});

  Color _statusColor(BuildContext context, TopicStatus status) {
    return switch (status) {
      TopicStatus.todo => AppColors.textTertiary(context),
      TopicStatus.studying => AppColors.warnFg(context),
      TopicStatus.reviewed => AppColors.info,
      TopicStatus.mastered => AppColors.okFg(context),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(subjectTopicsStreamProvider(subject.id));

    return topicsAsync.when(
      data: (topics) {
        if (topics.isEmpty) {
          return EmptyState(
            icon: Icons.checklist_rounded,
            title: 'Programa / Temario vacío',
            description:
                'Cargá unidades o temas para seguir tu avance de estudio.',
            actionLabel: 'Agregar unidad o tema',
            onAction: () =>
                UpsertTopicSheet.show(context, subjectId: subject.id),
          );
        }

        final progress = topics.fold<double>(
              0.0,
              (acc, t) => acc + t.status.progressValue,
            ) /
            topics.length;

        return ListView(
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Dominio del programa',
                              style: AppTypography.titleSmall,
                            ),
                            Text(
                              '${(progress * 100).round()}%',
                              style: AppTypography.titleMedium.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        LinearProgressIndicator(value: progress, minHeight: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...topics.map((t) {
                    final stColor = _statusColor(context, t.status);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Dismissible(
                        key: Key('topic_${t.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: AppSpacing.xl),
                          decoration: ShapeDecoration(
                            color: AppColors.error,
                            shape: AppRadius.continuousMd(),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (_) {
                          ref
                              .read(topicControllerProvider.notifier)
                              .deleteTopic(t.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Se eliminó "${t.title}"'),
                              action: SnackBarAction(
                                label: AppStrings.undo,
                                onPressed: () => ref
                                    .read(topicControllerProvider.notifier)
                                    .restoreTopic(t.id),
                              ),
                            ),
                          );
                        },
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          onTap: () => UpsertTopicSheet.show(
                            context,
                            subjectId: subject.id,
                            topicToEdit: t,
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  ref
                                      .read(topicControllerProvider.notifier)
                                      .toggleStatus(t);
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  margin: const EdgeInsets.only(
                                    right: AppSpacing.md,
                                  ),
                                  decoration: BoxDecoration(
                                    color: stColor.withValues(alpha: 0.16),
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: stColor, width: 1.8),
                                  ),
                                  child: Icon(
                                    t.status == TopicStatus.mastered
                                        ? Icons.check_rounded
                                        : Icons.lens_rounded,
                                    size: t.status == TopicStatus.mastered
                                        ? 16
                                        : 8,
                                    color: stColor,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.title,
                                      style: AppTypography.titleSmall,
                                    ),
                                    Text(
                                      [
                                        t.status.label,
                                        'Prioridad ${t.priority.label}',
                                        if (t.notes != null) t.notes!,
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: AppButton(
                      label: 'Agregar unidad o tema',
                      icon: Icons.add_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: () =>
                          UpsertTopicSheet.show(context, subjectId: subject.id),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _SubjectGradesTab extends ConsumerWidget {
  final Subject subject;
  const _SubjectGradesTab({required this.subject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradesAsync = ref.watch(subjectGradesStreamProvider(subject.id));
    final allExams = ref.watch(examsStreamProvider).value ?? const [];

    return gradesAsync.when(
      data: (grades) {
        if (grades.isEmpty) {
          return EmptyState(
            icon: Icons.workspace_premium_rounded,
            title: 'Sin calificaciones registradas',
            description:
                'Cargá parciales, TPs o nota final para calcular tu promedio real.',
            actionLabel: 'Registrar nota',
            onAction: () => UpsertGradeSheet.show(
              context,
              preselectedSubjectId: subject.id,
            ),
          );
        }

        final effectiveIds = GradeCalculations.effectiveGrades(
          grades,
          exams: allExams,
        ).map((g) => g.id).toSet();
        final average =
            GradeCalculations.calculateAverage(grades, exams: allExams);
        final isPassing = average >= subject.passingGrade;

        return ListView(
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
                    color: (isPassing ? AppColors.success : AppColors.error)
                        .withValues(alpha: 0.10),
                    border: BorderSide(
                      color: (isPassing ? AppColors.success : AppColors.error)
                          .withValues(alpha: 0.35),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Promedio ponderado efectivo',
                                style: AppTypography.titleSmall,
                              ),
                              Text(
                                isPassing
                                    ? 'En condición de aprobación'
                                    : 'Debajo de la nota mínima (${AppFormatters.grade(subject.passingGrade)})',
                                style: AppTypography.caption.copyWith(
                                  color: isPassing
                                      ? AppColors.okFg(context)
                                      : AppColors.errFg(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          AppFormatters.grade(average, decimals: 2),
                          style: AppTypography.display.copyWith(
                            color: isPassing
                                ? AppColors.okFg(context)
                                : AppColors.errFg(context),
                            fontSize: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppButton(
                        label: 'Registrar nota',
                        icon: Icons.add_rounded,
                        size: AppButtonSize.sm,
                        onPressed: () => UpsertGradeSheet.show(
                          context,
                          preselectedSubjectId: subject.id,
                        ),
                      ),
                      AppButton(
                        label: 'Simular nota necesaria',
                        icon: Icons.calculate_outlined,
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => GradeCalculatorSheet.show(
                          context,
                          preselectedSubjectId: subject.id,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...grades.map((g) {
                    final replaced = !effectiveIds.contains(g.id);
                    final passed = g.value >= subject.passingGrade;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        onTap: () =>
                            UpsertGradeSheet.show(context, gradeToEdit: g),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    g.title,
                                    style: AppTypography.titleSmall.copyWith(
                                      decoration: replaced
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: replaced
                                          ? AppColors.textTertiary(context)
                                          : AppColors.textPrimary(context),
                                    ),
                                  ),
                                  Text(
                                    [
                                      g.kind.label,
                                      'Peso ${(g.weight * 100).toStringAsFixed(0)}%',
                                      AppFormatters.date(g.date),
                                      if (g.isRetake) 'Recuperatorio',
                                      if (replaced) 'Reemplazada',
                                    ].join(' · '),
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              AppFormatters.grade(g.value, decimals: 2),
                              style: AppTypography.titleLarge.copyWith(
                                color: replaced
                                    ? AppColors.textTertiary(context)
                                    : (passed
                                        ? AppColors.okFg(context)
                                        : AppColors.errFg(context)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _SubjectNotesTab extends ConsumerStatefulWidget {
  final Subject subject;

  const _SubjectNotesTab({required this.subject});

  @override
  ConsumerState<_SubjectNotesTab> createState() => _SubjectNotesTabState();
}

class _SubjectNotesTabState extends ConsumerState<_SubjectNotesTab> {
  late final TextEditingController _notesController;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.subject.notes ?? '');
  }

  @override
  void didUpdateWidget(covariant _SubjectNotesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newNotes = widget.subject.notes ?? '';
    if ((oldWidget.subject.notes ?? '') != newNotes &&
        newNotes != _notesController.text) {
      _notesController.text = newNotes;
      _hasChanges = false;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    if (_isSaving || !_hasChanges) return;
    setState(() => _isSaving = true);

    await ref.read(subjectControllerProvider.notifier).updateSubject(
          widget.subject.copyWith(notes: _notesController.text.trim()),
        );

    if (!mounted) return;
    final hasError = ref.read(subjectControllerProvider).hasError;
    setState(() {
      _isSaving = false;
      _hasChanges = hasError;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasError
              ? 'No se pudieron guardar los apuntes.'
              : 'Apuntes guardados en el dispositivo.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.pageHorizontalPadding,
        AppSpacing.lg,
        context.pageHorizontalPadding,
        64,
      ),
      physics: appScrollPhysics(),
      children: [
        ResponsiveContainer(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.sticky_note_2_outlined,
                      color: Color(widget.subject.colorValue),
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(
                      child: Text(
                        'Cuaderno de apuntes y criterios de cátedra',
                        style: AppTypography.titleSmall,
                      ),
                    ),
                    AppButton(
                      label: 'Guardar',
                      icon: Icons.save_outlined,
                      size: AppButtonSize.sm,
                      isLoading: _isSaving,
                      onPressed: _hasChanges ? _saveNotes : null,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _notesController,
                  minLines: 10,
                  maxLines: 18,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  hint:
                      'Anotá régimen de promoción, horarios de consulta, links de cátedra, bibliografía o fórmulas clave...',
                  onChanged: (_) => setState(() => _hasChanges = true),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
