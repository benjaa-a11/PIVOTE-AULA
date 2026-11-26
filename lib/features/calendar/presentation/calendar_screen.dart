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
import '../../../core/design_system/components/app_chip.dart';
import '../../../core/design_system/components/empty_state.dart';
import '../../../core/design_system/responsive.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../exams/data/exam_repository.dart';
import '../../exams/domain/exam.dart';
import '../../exams/presentation/upsert_exam_sheet.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../schedule/domain/class_session.dart';
import '../../schedule/presentation/schedule_controller.dart';
import '../../schedule/presentation/upsert_class_session_sheet.dart';
import '../../subjects/data/subject_repository.dart';
import '../../subjects/domain/subject.dart';
import '../../subjects/presentation/upsert_subject_sheet.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/academic_task.dart';
import '../../tasks/presentation/task_controller.dart';
import '../../tasks/presentation/upsert_task_sheet.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  DateTime _currentMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  String? _selectedSubjectFilter;
  ExamType? _selectedTypeFilter;
  String _taskFilter = 'pending'; // pending | overdue | completed | all

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final allExams = ref.watch(examsStreamProvider).value ?? const [];
    final allSubjects = ref.watch(subjectsStreamProvider).value ?? const [];
    final allSessions =
        ref.watch(classSessionsStreamProvider).value ?? const [];
    final allTasks = ref.watch(academicTasksStreamProvider).value ?? const [];

    final subjectById = {for (final s in allSubjects) s.id: s};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda Académica', style: AppTypography.titleLarge),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: AppButton(
              label: 'Nuevo',
              icon: Icons.add_rounded,
              size: AppButtonSize.sm,
              onPressed: () {
                final idx = _tabController.index;
                if (idx == 1) {
                  if (allSubjects.isEmpty) {
                    UpsertSubjectSheet.show(context);
                  } else {
                    UpsertClassSessionSheet.show(context);
                  }
                } else if (idx == 2) {
                  UpsertTaskSheet.show(context);
                } else {
                  if (allSubjects.isEmpty) {
                    UpsertSubjectSheet.show(context);
                  } else {
                    UpsertExamSheet.show(
                      context,
                      preselectedDate: _selectedDay,
                    );
                  }
                }
              },
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Calendario'),
            Tab(text: 'Horarios'),
            Tab(text: 'Tareas y TPs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCalendarTab(
            context: context,
            allExams: allExams,
            allTasks: allTasks,
            allSubjects: allSubjects,
            subjectById: subjectById,
          ),
          _buildWeeklyScheduleTab(
            context: context,
            allSessions: allSessions,
            allSubjects: allSubjects,
            subjectById: subjectById,
          ),
          _buildTasksTab(
            context: context,
            allTasks: allTasks,
            subjectById: subjectById,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarTab({
    required BuildContext context,
    required List<Exam> allExams,
    required List<AcademicTask> allTasks,
    required List<Subject> allSubjects,
    required Map<String, Subject> subjectById,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final filteredExams = allExams.where((e) {
      final matchesSub =
          _selectedSubjectFilter == null || e.subjectId == _selectedSubjectFilter;
      final matchesType =
          _selectedTypeFilter == null || e.type == _selectedTypeFilter;
      return matchesSub && matchesType;
    }).toList();

    final filteredTasks = allTasks.where((t) {
      if (t.dueDate == null) return false;
      return _selectedSubjectFilter == null ||
          t.subjectId == _selectedSubjectFilter;
    }).toList();

    final daysInMonth =
        DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstWeekday =
        DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;

    final selectedDayExams = filteredExams
        .where((e) => DateUtils.isSameDay(e.dateTime, _selectedDay))
        .toList();
    final selectedDayTasks = filteredTasks
        .where((t) => DateUtils.isSameDay(t.dueDate, _selectedDay))
        .toList();

    final upcomingExams = filteredExams
        .where((e) => !DateTime(
              e.dateTime.year,
              e.dateTime.month,
              e.dateTime.day,
            ).isBefore(today))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.pageHorizontalPadding,
        AppSpacing.lg,
        context.pageHorizontalPadding,
        88,
      ),
      physics: appScrollPhysics(),
      children: [
        ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subject Filter Row
              if (allSubjects.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: appScrollPhysics(),
                  child: Row(
                    children: [
                      AppChip(
                        label: 'Todas las materias',
                        isSelected: _selectedSubjectFilter == null,
                        onTap: () =>
                            setState(() => _selectedSubjectFilter = null),
                      ),
                      ...allSubjects.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.xs),
                          child: AppChip(
                            label: s.name,
                            isSelected: _selectedSubjectFilter == s.id,
                            activeColor: Color(s.colorValue),
                            onTap: () =>
                                setState(() => _selectedSubjectFilter = s.id),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              // Exam Type Filter Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: appScrollPhysics(),
                child: Row(
                  children: [
                    AppChip(
                      label: 'Todos los tipos',
                      isSelected: _selectedTypeFilter == null,
                      onTap: () => setState(() => _selectedTypeFilter = null),
                    ),
                    ...ExamType.values.map(
                      (type) => Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.xs),
                        child: AppChip(
                          label: type.label,
                          isSelected: _selectedTypeFilter == type,
                          onTap: () =>
                              setState(() => _selectedTypeFilter = type),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Monthly Calendar Card
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: () => _changeMonth(-1),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentMonth = DateTime(now.year, now.month, 1);
                              _selectedDay = today;
                            });
                          },
                          child: Text(
                            '${_monthName(_currentMonth.month)} ${_currentMonth.year}',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: () => _changeMonth(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: const ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                          .map(
                            (d) => Expanded(
                              child: Center(
                                child: Text(d, style: AppTypography.eyebrow),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        childAspectRatio: 1.05,
                      ),
                      itemCount: (firstWeekday - 1) + daysInMonth,
                      itemBuilder: (context, index) {
                        if (index < firstWeekday - 1) {
                          return const SizedBox.shrink();
                        }
                        final dayNum = index - (firstWeekday - 1) + 1;
                        final dayDate = DateTime(
                          _currentMonth.year,
                          _currentMonth.month,
                          dayNum,
                        );

                        final isSelected =
                            DateUtils.isSameDay(dayDate, _selectedDay);
                        final isToday = DateUtils.isSameDay(dayDate, today);

                        final dayExams = filteredExams
                            .where((e) => DateUtils.isSameDay(e.dateTime, dayDate))
                            .toList();
                        final dayTasks = filteredTasks
                            .where((t) =>
                                !t.isCompleted &&
                                DateUtils.isSameDay(t.dueDate, dayDate))
                            .toList();

                        final dotColors = <Color>[
                          ...dayExams.map((e) {
                            final sub = subjectById[e.subjectId];
                            return sub != null
                                ? Color(sub.colorValue)
                                : primary;
                          }),
                          ...dayTasks.map((_) => const Color(0xFF0EA5E9)),
                        ];

                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedDay = dayDate);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primary
                                  : (isToday
                                      ? primary.withValues(alpha: 0.14)
                                      : Colors.transparent),
                              borderRadius: BorderRadius.circular(10),
                              border: isToday && !isSelected
                                  ? Border.all(color: primary, width: 1.4)
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  dayNum.toString(),
                                  style: AppTypography.label.copyWith(
                                    color: isSelected
                                        ? theme.colorScheme.onPrimary
                                        : AppColors.textPrimary(context),
                                    fontWeight: isSelected || isToday
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                                if (dotColors.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: dotColors.take(3).map((c) {
                                      return Container(
                                        width: 5,
                                        height: 5,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? theme.colorScheme.onPrimary
                                              : c,
                                          shape: BoxShape.circle,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Selected Day Card
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                color: AppColors.surfaceSubtle(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Día seleccionado: ${AppFormatters.date(_selectedDay)}',
                          style: AppTypography.titleSmall,
                        ),
                        Wrap(
                          spacing: 6,
                          children: [
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 32),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onPressed: () => UpsertTaskSheet.show(
                                context,
                                preselectedDate: _selectedDay,
                              ),
                              icon: const Icon(Icons.add_task_rounded, size: 16),
                              label: const Text('Tarea'),
                            ),
                            if (allSubjects.isNotEmpty)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 32),
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                ),
                                onPressed: () => UpsertExamSheet.show(
                                  context,
                                  preselectedDate: _selectedDay,
                                ),
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Examen'),
                              ),
                          ],
                        ),
                      ],
                    ),
                    if (selectedDayExams.isEmpty && selectedDayTasks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Sin evaluaciones ni entregas agendadas en esta fecha.',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      )
                    else ...[
                      const SizedBox(height: AppSpacing.xs),
                      ...selectedDayExams.map((e) {
                        final sub = subjectById[e.subjectId];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.event_note_rounded,
                            color: sub != null
                                ? Color(sub.colorValue)
                                : primary,
                          ),
                          title: Text(e.title, style: AppTypography.titleSmall),
                          subtitle: Text(
                            '${sub?.name ?? ''} · ${AppFormatters.time(e.dateTime)} hs · ${e.type.label}',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/exams/${e.id}'),
                        );
                      }),
                      ...selectedDayTasks.map((t) {
                        final sub = t.subjectId != null
                            ? subjectById[t.subjectId]
                            : null;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            t.isCompleted
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: t.isCompleted
                                ? AppColors.okFg(context)
                                : const Color(0xFF0EA5E9),
                          ),
                          title: Text(t.title, style: AppTypography.titleSmall),
                          subtitle: Text(sub?.name ?? t.category.label),
                          onTap: () =>
                              UpsertTaskSheet.show(context, taskToEdit: t),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Upcoming Chronological Agenda
              const Text(
                'Próximas evaluaciones',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (upcomingExams.isEmpty)
                EmptyState(
                  icon: Icons.event_available_rounded,
                  title: 'Sin evaluaciones próximas',
                  description:
                      'Programá parciales, recuperatorios, finales o entregas.',
                  actionLabel:
                      allSubjects.isNotEmpty ? 'Agendar evaluación' : null,
                  onAction: allSubjects.isNotEmpty
                      ? () => UpsertExamSheet.show(context)
                      : null,
                )
              else
                ...upcomingExams.map((exam) {
                  final sub = subjectById[exam.subjectId];
                  final subColor =
                      sub != null ? Color(sub.colorValue) : primary;
                  final readableSub =
                      AppColors.readableAccent(subColor, isDark: isDark);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      onTap: () => context.push('/exams/${exam.id}'),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: ShapeDecoration(
                              color: subColor.withValues(
                                alpha: isDark ? 0.22 : 0.12,
                              ),
                              shape: AppRadius.continuousSm(),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  exam.dateTime.day.toString(),
                                  style: AppTypography.titleLarge.copyWith(
                                    color: readableSub,
                                    fontSize: 20,
                                  ),
                                ),
                                Text(
                                  _monthShort(exam.dateTime.month),
                                  style: AppTypography.eyebrow.copyWith(
                                    color: readableSub,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exam.title,
                                  style: AppTypography.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (sub != null) sub.name,
                                    '${AppFormatters.time(exam.dateTime)} hs',
                                    exam.type.label,
                                    if (exam.classroom != null) exam.classroom!,
                                  ].join(' · '),
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: ShapeDecoration(
                              color: AppColors.warning
                                  .withValues(alpha: isDark ? 0.20 : 0.12),
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
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyScheduleTab({
    required BuildContext context,
    required List<ClassSession> allSessions,
    required List<Subject> allSubjects,
    required Map<String, Subject> subjectById,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (allSessions.isEmpty) {
      return EmptyState(
        icon: Icons.schedule_rounded,
        title: 'Todavía no cargaste horarios de cursada',
        description:
            'Registrá qué días y en qué aula o enlace cursás cada materia para ver tu semana completa.',
        actionLabel: allSubjects.isEmpty
            ? 'Crear primera materia'
            : 'Agregar horario de cursada',
        onAction: () {
          if (allSubjects.isEmpty) {
            UpsertSubjectSheet.show(context);
          } else {
            UpsertClassSessionSheet.show(context);
          }
        },
      );
    }

    final grouped = <int, List<ClassSession>>{};
    for (final s in allSessions) {
      grouped.putIfAbsent(s.weekday, () => []).add(s);
    }
    final activeDays = grouped.keys.toList()..sort();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.pageHorizontalPadding,
        AppSpacing.lg,
        context.pageHorizontalPadding,
        88,
      ),
      physics: appScrollPhysics(),
      children: [
        ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final day in activeDays) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ClassSession.weekdayFullName(day),
                        style: AppTypography.titleMedium.copyWith(
                          color: day == DateTime.now().weekday
                              ? Theme.of(context).colorScheme.primary
                              : AppColors.textPrimary(context),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () => UpsertClassSessionSheet.show(
                          context,
                          preselectedWeekday: day,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Sumar bloque'),
                      ),
                    ],
                  ),
                ),
                ...grouped[day]!.map((session) {
                  final sub = subjectById[session.subjectId];
                  final baseColor = sub != null
                      ? Color(sub.colorValue)
                      : Theme.of(context).colorScheme.primary;
                  final readable =
                      AppColors.readableAccent(baseColor, isDark: isDark);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Dismissible(
                      key: Key('sched_${session.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: AppSpacing.xl),
                        decoration: ShapeDecoration(
                          color: AppColors.error,
                          shape: AppRadius.continuousLg(),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                      onDismissed: (_) {
                        ref
                            .read(scheduleControllerProvider.notifier)
                            .deleteSession(session.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Horario eliminado'),
                            action: SnackBarAction(
                              label: AppStrings.undo,
                              onPressed: () => ref
                                  .read(scheduleControllerProvider.notifier)
                                  .restoreSession(session.id),
                            ),
                          ),
                        );
                      },
                      child: AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        onTap: () => UpsertClassSessionSheet.show(
                          context,
                          sessionToEdit: session,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 44,
                              decoration: BoxDecoration(
                                color: baseColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sub?.name ?? 'Materia',
                                    style: AppTypography.titleSmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      session.modality.label,
                                      if (session.classroom != null)
                                        session.classroom!,
                                      if (session.professor != null)
                                        session.professor!,
                                    ].join(' · '),
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: ShapeDecoration(
                                color: baseColor.withValues(
                                  alpha: isDark ? 0.22 : 0.10,
                                ),
                                shape: AppRadius.continuousSm(),
                              ),
                              child: Text(
                                session.timeRangeLabel,
                                style: AppTypography.label.copyWith(
                                  color: readable,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTasksTab({
    required BuildContext context,
    required List<AcademicTask> allTasks,
    required Map<String, Subject> subjectById,
  }) {
    final filtered = allTasks.where((t) {
      switch (_taskFilter) {
        case 'pending':
          return !t.isCompleted;
        case 'overdue':
          return t.isOverdue;
        case 'completed':
          return t.isCompleted;
        default:
          return true;
      }
    }).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.pageHorizontalPadding,
        AppSpacing.lg,
        context.pageHorizontalPadding,
        88,
      ),
      physics: appScrollPhysics(),
      children: [
        ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    AppChip(
                      label: 'Pendientes',
                      count: allTasks.where((t) => !t.isCompleted).length,
                      isSelected: _taskFilter == 'pending',
                      onTap: () => setState(() => _taskFilter = 'pending'),
                    ),
                    const SizedBox(width: 8),
                    AppChip(
                      label: 'Vencidas',
                      count: allTasks.where((t) => t.isOverdue).length,
                      activeColor: AppColors.error,
                      isSelected: _taskFilter == 'overdue',
                      onTap: () => setState(() => _taskFilter = 'overdue'),
                    ),
                    const SizedBox(width: 8),
                    AppChip(
                      label: 'Completadas',
                      count: allTasks.where((t) => t.isCompleted).length,
                      activeColor: AppColors.success,
                      isSelected: _taskFilter == 'completed',
                      onTap: () => setState(() => _taskFilter = 'completed'),
                    ),
                    const SizedBox(width: 8),
                    AppChip(
                      label: 'Todas',
                      isSelected: _taskFilter == 'all',
                      onTap: () => setState(() => _taskFilter = 'all'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (filtered.isEmpty)
                EmptyState(
                  icon: Icons.task_alt_rounded,
                  title: 'No hay tareas en esta vista',
                  description:
                      'Registrá entregas de TP, guías de ejercicios, lecturas o trámites universitarios.',
                  actionLabel: 'Nueva tarea o entrega',
                  onAction: () => UpsertTaskSheet.show(context),
                )
              else
                ...filtered.map((task) {
                  final sub = task.subjectId != null
                      ? subjectById[task.subjectId]
                      : null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Dismissible(
                      key: Key('task_${task.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: AppSpacing.xl),
                        decoration: ShapeDecoration(
                          color: AppColors.error,
                          shape: AppRadius.continuousLg(),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                      onDismissed: (_) {
                        ref
                            .read(taskControllerProvider.notifier)
                            .deleteTask(task.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Se eliminó "${task.title}"'),
                            action: SnackBarAction(
                              label: AppStrings.undo,
                              onPressed: () => ref
                                  .read(taskControllerProvider.notifier)
                                  .restoreTask(task.id),
                            ),
                          ),
                        );
                      },
                      child: AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        onTap: () =>
                            UpsertTaskSheet.show(context, taskToEdit: task),
                        child: Row(
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                ref
                                    .read(taskControllerProvider.notifier)
                                    .toggleCompleted(task);
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  right: AppSpacing.md,
                                ),
                                child: Icon(
                                  task.isCompleted
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: task.isCompleted
                                      ? AppColors.okFg(context)
                                      : (task.isOverdue
                                          ? AppColors.errFg(context)
                                          : AppColors.textSecondary(context)),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.title,
                                    style: AppTypography.titleSmall.copyWith(
                                      decoration: task.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: task.isCompleted
                                          ? AppColors.textTertiary(context)
                                          : AppColors.textPrimary(context),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      sub?.name ?? task.category.label,
                                      'Prioridad ${task.priority.label}',
                                      if (task.dueDate != null)
                                        AppFormatters.date(task.dueDate!),
                                    ].join(' · '),
                                    style: AppTypography.caption.copyWith(
                                      color: task.isOverdue
                                          ? AppColors.errFg(context)
                                          : AppColors.textSecondary(context),
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
            ],
          ),
        ),
      ],
    );
  }

  String _monthName(int month) {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return months[month - 1];
  }

  String _monthShort(int month) {
    const shorts = [
      'ENE',
      'FEB',
      'MAR',
      'ABR',
      'MAY',
      'JUN',
      'JUL',
      'AGO',
      'SEP',
      'OCT',
      'NOV',
      'DIC',
    ];
    return shorts[month - 1];
  }
}
