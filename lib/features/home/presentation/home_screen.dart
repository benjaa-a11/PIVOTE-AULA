import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_radius.dart';
import '../../../core/design_system/app_scroll_physics.dart';
import '../../../core/design_system/app_spacing.dart';
import '../../../core/design_system/app_typography.dart';
import '../../../core/design_system/components/animated_counter.dart';
import '../../../core/design_system/components/app_button.dart';
import '../../../core/design_system/components/app_card.dart';
import '../../../core/design_system/components/aula_logo.dart';
import '../../../core/design_system/components/pressable_scale.dart';
import '../../../core/design_system/components/quick_capture_sheet.dart';
import '../../../core/design_system/responsive.dart';
import '../../../core/utils/formatters.dart';
import '../../exams/data/exam_repository.dart';
import '../../exams/domain/exam.dart';
import '../../exams/presentation/upsert_exam_sheet.dart';
import '../../grades/data/grade_repository.dart';
import '../../grades/presentation/grade_controller.dart';
import '../../grades/presentation/upsert_grade_sheet.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/avatar_view.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../schedule/domain/class_session.dart';
import '../../schedule/presentation/upsert_class_session_sheet.dart';
import '../../subjects/data/subject_repository.dart';
import '../../subjects/domain/subject.dart';
import '../../subjects/presentation/upsert_subject_sheet.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/academic_task.dart';
import '../../tasks/presentation/task_controller.dart';
import '../../tasks/presentation/upsert_task_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final profile = ref.watch(profileStreamProvider).value;
    final allExams = ref.watch(examsStreamProvider).value ?? const [];
    final allSubjects = ref.watch(subjectsStreamProvider).value ?? const [];
    final allGrades = ref.watch(allGradesStreamProvider).value ?? const [];
    final allSessions =
        ref.watch(classSessionsStreamProvider).value ?? const [];
    final allTasks = ref.watch(academicTasksStreamProvider).value ?? const [];

    final subjectById = {for (final s in allSubjects) s.id: s};

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nowMinutes = now.hour * 60 + now.minute;

    // Clases de hoy
    final todaySessions = allSessions
        .where((s) => s.weekday == now.weekday)
        .toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    // Próximas evaluaciones
    final upcomingExams = allExams
        .where((e) => !e.dateTime.isBefore(today))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final nextExam = upcomingExams.firstOrNull;

    final thisWeekExams = upcomingExams.where((e) {
      final target =
          DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
      final diff = target.difference(today).inDays;
      return diff >= 0 && diff <= 7;
    }).toList();

    // Evaluaciones rendidas sin nota cargada
    final pastExamsWithoutGrade = allExams.where((e) {
      final examDay =
          DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
      final isPast = examDay.isBefore(today);
      final hasGrade = allGrades.any((g) => g.examId == e.id);
      return isPast && !hasGrade && e.status != ExamStatus.absent;
    }).toList();

    // Tareas pendientes prioritarias
    final pendingTasks = allTasks.where((t) => !t.isCompleted).toList();
    final topTasks = pendingTasks.take(4).toList();

    // Promedios reales con reemplazo de recuperatorios
    final passingThreshold = profile?.passingGrade ?? 4.0;
    final weightedAverage =
        GradeCalculations.calculateAverage(allGrades, exams: allExams);
    final avgWithoutFails = GradeCalculations.calculateAverageWithoutFails(
      allGrades,
      passingGrade: passingThreshold,
      exams: allExams,
    );

    final passedSubjects =
        allSubjects.where((s) => s.status == SubjectStatus.passed).toList();
    final regularSubjects =
        allSubjects.where((s) => s.status == SubjectStatus.regular).length;
    final enrolledSubjects = allSubjects
        .where((s) =>
            s.status == SubjectStatus.enrolled ||
            s.status == SubjectStatus.retaking)
        .length;

    final totalCredits =
        allSubjects.fold<int>(0, (sum, s) => sum + (s.credits ?? 0));
    final earnedCredits =
        passedSubjects.fold<int>(0, (sum, s) => sum + (s.credits ?? 0));

    final careerProgress = totalCredits > 0
        ? (earnedCredits / totalCredits).clamp(0.0, 1.0).toDouble()
        : (allSubjects.isEmpty
            ? 0.0
            : (passedSubjects.length / allSubjects.length)
                .clamp(0.0, 1.0)
                .toDouble());
    final careerProgressLabel = totalCredits > 0
        ? '$earnedCredits de $totalCredits créditos aprobados'
        : '${passedSubjects.length} de ${allSubjects.length} materias aprobadas';

    final firstName =
        (profile?.fullName.trim().split(RegExp(r'\s+')).firstOrNull ?? '')
                .isEmpty
            ? 'Estudiante'
            : profile!.fullName.trim().split(RegExp(r'\s+')).first;

    return Scaffold(
      floatingActionButton: context.useNavigationRail
          ? null
          : FloatingActionButton.extended(
              onPressed: () => QuickCaptureSheet.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Registrar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            context.pageHorizontalPadding,
            AppSpacing.lg,
            context.pageHorizontalPadding,
            96,
          ),
          physics: appScrollPhysics(),
          children: [
            ResponsiveContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header
                  Row(
                    children: [
                      if (!context.useNavigationRail) ...[
                        const AulaLogoMark(size: 38),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hola, $firstName',
                              style: AppTypography.titleLarge.copyWith(
                                color: AppColors.textPrimary(context),
                                fontSize: 23,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (profile?.career.isNotEmpty == true)
                                  profile!.career,
                                if (profile?.currentPeriod.isNotEmpty == true)
                                  profile!.currentPeriod,
                              ].join(' · ').isEmpty
                                  ? 'Panel académico integral'
                                  : [
                                      if (profile?.career.isNotEmpty == true)
                                        profile!.career,
                                      if (profile?.currentPeriod.isNotEmpty ==
                                          true)
                                        profile!.currentPeriod,
                                    ].join(' · '),
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (!context.useNavigationRail)
                        IconButton(
                          tooltip: 'Buscar en Aula',
                          onPressed: () => context.push('/search'),
                          icon: const Icon(Icons.search_rounded),
                        ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => context.go('/settings'),
                        customBorder: const CircleBorder(),
                        child: AvatarView(
                          photoPath: profile?.photoPath,
                          name: profile?.fullName ?? 'A',
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Quick Capture Strip
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 560;
                      final actions = [
                        _QuickActionTile(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Tarea / TP',
                          color: const Color(0xFF0EA5E9),
                          onTap: () => UpsertTaskSheet.show(context),
                        ),
                        _QuickActionTile(
                          icon: Icons.event_note_rounded,
                          label: 'Examen',
                          color: primary,
                          onTap: () {
                            if (allSubjects.isEmpty) {
                              UpsertSubjectSheet.show(context);
                            } else {
                              UpsertExamSheet.show(context);
                            }
                          },
                        ),
                        _QuickActionTile(
                          icon: Icons.workspace_premium_rounded,
                          label: 'Nota',
                          color: AppColors.success,
                          onTap: () {
                            if (allSubjects.isEmpty) {
                              UpsertSubjectSheet.show(context);
                            } else {
                              UpsertGradeSheet.show(context);
                            }
                          },
                        ),
                        _QuickActionTile(
                          icon: Icons.auto_stories_rounded,
                          label: 'Materia',
                          color: const Color(0xFF7C3AED),
                          onTap: () => UpsertSubjectSheet.show(context),
                        ),
                      ];

                      if (wide) {
                        return Row(
                          children: [
                            for (int i = 0; i < actions.length; i++) ...[
                              Expanded(child: actions[i]),
                              if (i < actions.length - 1)
                                const SizedBox(width: AppSpacing.sm),
                            ],
                          ],
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: actions[0]),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(child: actions[1]),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(child: actions[2]),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(child: actions[3]),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Onboarding Empty Prompt if zero subjects yet
                  if (allSubjects.isEmpty) ...[
                    AppCard(
                      border: BorderSide(
                        color: primary.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      color: primary.withValues(alpha: isDark ? 0.12 : 0.05),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.rocket_launch_rounded,
                                  color: primary, size: 22),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Empezá cargando tus materias',
                                  style: AppTypography.titleMedium.copyWith(
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Creá tus asignaturas actuales o aprobadas para registrar horarios de cursada, exámenes, asistencia, apuntes y calificaciones.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppButton(
                            label: 'Agregar primera materia',
                            icon: Icons.add_rounded,
                            onPressed: () => UpsertSubjectSheet.show(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // Overdue Exams Pending Grade Alert
                  if (pastExamsWithoutGrade.isNotEmpty) ...[
                    AppCard(
                      color: AppColors.warning
                          .withValues(alpha: isDark ? 0.14 : 0.08),
                      border: BorderSide(
                        color: AppColors.warning
                            .withValues(alpha: isDark ? 0.40 : 0.30),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.pending_actions_rounded,
                            color: AppColors.warnFg(context),
                            size: 24,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${pastExamsWithoutGrade.length} ${pastExamsWithoutGrade.length == 1 ? 'evaluación pendiente' : 'evaluaciones pendientes'} de nota',
                                  style: AppTypography.titleSmall.copyWith(
                                    color: AppColors.warnFg(context),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Cargá el resultado de "${pastExamsWithoutGrade.first.title}"',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          AppButton(
                            label: 'Cargar',
                            size: AppButtonSize.sm,
                            onPressed: () => UpsertGradeSheet.show(
                              context,
                              preselectedSubjectId:
                                  pastExamsWithoutGrade.first.subjectId,
                              preselectedExamId:
                                  pastExamsWithoutGrade.first.id,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // Cursada de Hoy + Próxima Evaluación (2 columns on desktop)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final twoCols =
                          constraints.maxWidth >= 720 && nextExam != null;
                      final todayWidget = _TodayScheduleSection(
                        todaySessions: todaySessions,
                        subjectById: subjectById,
                        nowMinutes: nowMinutes,
                        hasSubjects: allSubjects.isNotEmpty,
                      );

                      if (!twoCols) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (nextExam != null) ...[
                              _SectionHeader(
                                title: 'Próxima evaluación',
                                actionLabel: 'Agenda',
                                onAction: () => context.go('/calendar'),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              _FeaturedExamCard(
                                exam: nextExam,
                                subject: subjectById[nextExam.subjectId],
                              ),
                              const SizedBox(height: AppSpacing.xl),
                            ],
                            if (allSubjects.isNotEmpty) ...[
                              todayWidget,
                              const SizedBox(height: AppSpacing.xl),
                            ],
                          ],
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SectionHeader(
                                    title: 'Próxima evaluación',
                                    actionLabel: 'Agenda',
                                    onAction: () => context.go('/calendar'),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  _FeaturedExamCard(
                                    exam: nextExam,
                                    subject: subjectById[nextExam.subjectId],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(child: todayWidget),
                          ],
                        ),
                      );
                    },
                  ),

                  // Tareas y Entregas Pendientes
                  _SectionHeader(
                    title: pendingTasks.isEmpty
                        ? 'Tareas y entregas'
                        : 'Pendientes (${pendingTasks.length})',
                    actionLabel: '+ Agregar',
                    onAction: () => UpsertTaskSheet.show(context),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (topTasks.isEmpty)
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(
                            Icons.task_alt_rounded,
                            color: AppColors.okFg(context),
                            size: 22,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Todo al día. Registrá entregas de TP, lecturas o trámites para no olvidar nada.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...topTasks.map((task) {
                      final sub = task.subjectId != null
                          ? subjectById[task.subjectId]
                          : null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _HomeTaskRow(
                          task: task,
                          subject: sub,
                          onToggle: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(taskControllerProvider.notifier)
                                .toggleCompleted(task);
                          },
                          onTap: () =>
                              UpsertTaskSheet.show(context, taskToEdit: task),
                        ),
                      );
                    }),
                  const SizedBox(height: AppSpacing.xl),

                  // Resumen Académico KPI Grid
                  const Text(
                    'Resumen académico',
                    style: AppTypography.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final fourCols = constraints.maxWidth >= 760;
                      final kpis = [
                        _KpiStatCard(
                          eyebrow: 'PROMEDIO PONDERADO',
                          hasValue: allGrades.isNotEmpty,
                          numericValue: weightedAverage,
                          precision: 2,
                          accentColor: allGrades.isEmpty
                              ? AppColors.textPrimary(context)
                              : (weightedAverage >= passingThreshold
                                  ? AppColors.okFg(context)
                                  : AppColors.errFg(context)),
                          caption: 'Con recuperatorios aplicados',
                          onTap: () => context.go('/grades'),
                        ),
                        _KpiStatCard(
                          eyebrow: 'SIN APLAZOS',
                          hasValue: avgWithoutFails > 0,
                          numericValue: avgWithoutFails,
                          precision: 2,
                          accentColor: AppColors.okFg(context),
                          caption: 'Notas aprobadas (>= ${AppFormatters.grade(passingThreshold)})',
                          onTap: () => context.go('/grades'),
                        ),
                        _KpiStatCard(
                          eyebrow: 'CURSANDO AHORA',
                          hasValue: true,
                          numericValue: enrolledSubjects.toDouble(),
                          precision: 0,
                          accentColor: primary,
                          caption: regularSubjects > 0
                              ? '$regularSubjects regulares · ${allSubjects.length} totales'
                              : '${allSubjects.length} materias registradas',
                          onTap: () => context.go('/subjects'),
                        ),
                        _KpiStatCard(
                          eyebrow: totalCredits > 0
                              ? 'CRÉDITOS APROBADOS'
                              : 'MATERIAS APROBADAS',
                          hasValue: true,
                          numericValue: totalCredits > 0
                              ? earnedCredits.toDouble()
                              : passedSubjects.length.toDouble(),
                          precision: 0,
                          accentColor: AppColors.okFg(context),
                          caption: totalCredits > 0
                              ? 'de $totalCredits créditos cargados'
                              : 'de ${allSubjects.length} materias totales',
                          onTap: () => context.go('/subjects'),
                        ),
                      ];

                      if (fourCols) {
                        return Row(
                          children: [
                            for (int i = 0; i < kpis.length; i++) ...[
                              Expanded(child: kpis[i]),
                              if (i < kpis.length - 1)
                                const SizedBox(width: AppSpacing.md),
                            ],
                          ],
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: kpis[0]),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: kpis[1]),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(child: kpis[2]),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: kpis[3]),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Avance de Carrera
                  AppCard(
                    onTap: () => context.go('/subjects'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.school_outlined,
                                color: primary, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Avance de carrera',
                                style: AppTypography.titleSmall.copyWith(
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                            ),
                            Text(
                              '${(careerProgress * 100).round()}%',
                              style: AppTypography.titleMedium.copyWith(
                                color: primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LinearProgressIndicator(
                            value: careerProgress,
                            minHeight: 8,
                            backgroundColor: primary.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(primary),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          careerProgressLabel,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Esta Semana
                  _SectionHeader(
                    title: 'Evaluaciones próximos 7 días',
                    actionLabel: 'Ver calendario',
                    onAction: () => context.go('/calendar'),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (thisWeekExams.isEmpty)
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_available_rounded,
                            color: AppColors.okFg(context),
                            size: 22,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Sin exámenes programados en los próximos 7 días.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...thisWeekExams.map((e) {
                      final sub = subjectById[e.subjectId];
                      final subColor = sub != null
                          ? Color(sub.colorValue)
                          : primary;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          onTap: () => context.push('/exams/${e.id}'),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: subColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.title,
                                      style: AppTypography.titleSmall,
                                    ),
                                    Text(
                                      '${sub?.name ?? 'Materia'} · ${AppFormatters.date(e.dateTime)} ${AppFormatters.time(e.dateTime)} hs',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
                                  AppFormatters.countdown(e.dateTime),
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
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final readable = AppColors.readableAccent(color, isDark: isDark);

    return PressableScale(
      enableHaptics: true,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: ShapeDecoration(
          color: AppColors.surface(context),
          shape: AppRadius.continuousMd(
            side: BorderSide(color: AppColors.border(context)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: ShapeDecoration(
                color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                shape: AppRadius.continuousSm(),
              ),
              child: Icon(icon, color: readable, size: 17),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '+ $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayScheduleSection extends StatelessWidget {
  final List<ClassSession> todaySessions;
  final Map<String, Subject> subjectById;
  final int nowMinutes;
  final bool hasSubjects;

  const _TodayScheduleSection({
    required this.todaySessions,
    required this.subjectById,
    required this.nowMinutes,
    required this.hasSubjects,
  });

  @override
  Widget build(BuildContext context) {
    final dayName = ClassSession.weekdayFullName(DateTime.now().weekday);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Cursada de hoy ($dayName)',
          actionLabel: hasSubjects ? '+ Horario' : null,
          onAction: hasSubjects
              ? () => UpsertClassSessionSheet.show(
                    context,
                    preselectedWeekday: DateTime.now().weekday,
                  )
              : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (todaySessions.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  Icons.free_breakfast_outlined,
                  color: AppColors.textSecondary(context),
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'No tenés clases cargadas para los ${dayName.toLowerCase()}.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...todaySessions.map((session) {
            final sub = subjectById[session.subjectId];
            final baseColor = sub != null
                ? Color(sub.colorValue)
                : Theme.of(context).colorScheme.primary;
            final isLive = nowMinutes >= session.startMinutes &&
                nowMinutes <= session.endMinutes;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                border: isLive
                    ? BorderSide(
                        color: AppColors.readableAccent(
                          baseColor,
                          isDark: isDark,
                        ),
                        width: 1.5,
                      )
                    : null,
                onTap: sub != null
                    ? () => context.push('/subjects/${sub.id}')
                    : null,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: ShapeDecoration(
                        color: baseColor.withValues(alpha: isDark ? 0.22 : 0.10),
                        shape: AppRadius.continuousSm(),
                      ),
                      child: Column(
                        children: [
                          Text(
                            ClassSession.formatMinutes(session.startMinutes),
                            style: AppTypography.label.copyWith(
                              color: AppColors.readableAccent(
                                baseColor,
                                isDark: isDark,
                              ),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            ClassSession.formatMinutes(session.endMinutes),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary(context),
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
                            sub?.name ?? 'Materia',
                            style: AppTypography.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            [
                              session.modality.label,
                              if (session.classroom != null) session.classroom!,
                              if (session.professor != null) session.professor!,
                            ].join(' · '),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          'EN CURSO',
                          style: AppTypography.eyebrow.copyWith(
                            color: AppColors.okFg(context),
                            fontSize: 9.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _HomeTaskRow extends StatelessWidget {
  final AcademicTask task;
  final Subject? subject;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _HomeTaskRow({
    required this.task,
    required this.subject,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overdue = task.isOverdue;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 11),
      onTap: onTap,
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Icon(
                task.isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: task.isCompleted
                    ? AppColors.okFg(context)
                    : (overdue
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
                    color: AppColors.textPrimary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    subject?.name ?? task.category.label,
                    if (task.dueDate != null)
                      AppFormatters.countdown(task.dueDate!),
                  ].join(' · '),
                  style: AppTypography.caption.copyWith(
                    color: overdue
                        ? AppColors.errFg(context)
                        : AppColors.textSecondary(context),
                    fontWeight: overdue ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (subject != null)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.readableAccent(
                  Color(subject!.colorValue),
                  isDark: isDark,
                ),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _KpiStatCard extends StatelessWidget {
  final String eyebrow;
  final bool hasValue;
  final double numericValue;
  final int precision;
  final Color accentColor;
  final String caption;
  final VoidCallback? onTap;

  const _KpiStatCard({
    required this.eyebrow,
    required this.hasValue,
    required this.numericValue,
    required this.precision,
    required this.accentColor,
    required this.caption,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.eyebrow.copyWith(
              color: AppColors.textSecondary(context),
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 6),
          hasValue
              ? AnimatedCounter(
                  value: numericValue,
                  precision: precision,
                  style: AppTypography.statNumber.copyWith(
                    color: accentColor,
                    fontSize: 26,
                  ),
                )
              : Text(
                  '—',
                  style: AppTypography.statNumber.copyWith(
                    color: AppColors.textTertiary(context),
                    fontSize: 26,
                  ),
                ),
          const SizedBox(height: 3),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedExamCard extends StatelessWidget {
  final Exam exam;
  final Subject? subject;

  const _FeaturedExamCard({required this.exam, required this.subject});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subjectColor =
        subject != null ? Color(subject!.colorValue) : theme.colorScheme.primary;
    final readableSubject =
        AppColors.readableAccent(subjectColor, isDark: isDark);

    return AppCard(
      onTap: () => context.push('/exams/${exam.id}'),
      border: BorderSide(
        color: subjectColor.withValues(alpha: isDark ? 0.40 : 0.25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: ShapeDecoration(
                  color: subjectColor.withValues(alpha: isDark ? 0.22 : 0.12),
                  shape: AppRadius.continuousSm(),
                ),
                child: Text(
                  '${subject?.name ?? 'Materia'} · ${exam.type.label}',
                  style: AppTypography.caption.copyWith(
                    color: readableSubject,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: ShapeDecoration(
                  color: AppColors.error.withValues(alpha: isDark ? 0.20 : 0.10),
                  shape: AppRadius.continuousSm(),
                ),
                child: Text(
                  AppFormatters.countdown(exam.dateTime),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.errFg(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            exam.title,
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.textPrimary(context),
              fontSize: 20,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: AppColors.textTertiary(context),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${AppFormatters.date(exam.dateTime)} · ${AppFormatters.time(exam.dateTime)} hs',
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
                      size: 15,
                      color: AppColors.textTertiary(context),
                    ),
                    const SizedBox(width: 4),
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
        ],
      ),
    );
  }
}
