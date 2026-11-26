import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_scroll_physics.dart';
import '../../../core/design_system/app_spacing.dart';
import '../../../core/design_system/app_typography.dart';
import '../../../core/design_system/components/app_card.dart';
import '../../../core/design_system/components/app_text_field.dart';
import '../../../core/design_system/responsive.dart';
import '../../../core/utils/formatters.dart';
import '../../exams/data/exam_repository.dart';
import '../../grades/data/grade_repository.dart';
import '../../grades/presentation/upsert_grade_sheet.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../schedule/presentation/upsert_class_session_sheet.dart';
import '../../subjects/data/subject_repository.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/presentation/upsert_task_sheet.dart';
import '../../topics/data/topic_repository.dart';
import '../../topics/presentation/upsert_topic_sheet.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsStreamProvider).value ?? const [];
    final exams = ref.watch(examsStreamProvider).value ?? const [];
    final topics = ref.watch(allTopicsStreamProvider).value ?? const [];
    final grades = ref.watch(allGradesStreamProvider).value ?? const [];
    final tasks = ref.watch(academicTasksStreamProvider).value ?? const [];
    final sessions = ref.watch(classSessionsStreamProvider).value ?? const [];

    final subjectById = {for (final s in subjects) s.id: s};
    final q = _query.toLowerCase().trim();

    final matchingSubjects = q.isEmpty
        ? const []
        : subjects
            .where((s) =>
                s.name.toLowerCase().contains(q) ||
                (s.code?.toLowerCase().contains(q) ?? false) ||
                (s.professor?.toLowerCase().contains(q) ?? false) ||
                (s.notes?.toLowerCase().contains(q) ?? false) ||
                s.period.toLowerCase().contains(q))
            .toList();

    final matchingExams = q.isEmpty
        ? const []
        : exams
            .where((e) =>
                e.title.toLowerCase().contains(q) ||
                (e.classroom?.toLowerCase().contains(q) ?? false) ||
                e.type.label.toLowerCase().contains(q))
            .toList();

    final matchingTasks = q.isEmpty
        ? const []
        : tasks
            .where((t) =>
                t.title.toLowerCase().contains(q) ||
                (t.description?.toLowerCase().contains(q) ?? false))
            .toList();

    final matchingSessions = q.isEmpty
        ? const []
        : sessions
            .where((s) =>
                s.weekdayLabel.toLowerCase().contains(q) ||
                (s.classroom?.toLowerCase().contains(q) ?? false) ||
                (subjectById[s.subjectId]?.name.toLowerCase().contains(q) ??
                    false))
            .toList();

    final matchingTopics = q.isEmpty
        ? const []
        : topics
            .where((t) =>
                t.title.toLowerCase().contains(q) ||
                (t.notes?.toLowerCase().contains(q) ?? false))
            .toList();

    final matchingGrades = q.isEmpty
        ? const []
        : grades.where((g) => g.title.toLowerCase().contains(q)).toList();

    final totalResults = matchingSubjects.length +
        matchingExams.length +
        matchingTasks.length +
        matchingSessions.length +
        matchingTopics.length +
        matchingGrades.length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: AppSearchBar(
            controller: _searchController,
            autofocus: true,
            hintText: 'Materias, parciales, tareas, horarios, apuntes...',
            currentQuery: _query,
            onChanged: (val) => setState(() => _query = val),
            onClear: () {
              _searchController.clear();
              setState(() => _query = '');
            },
          ),
        ),
      ),
      body: q.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.manage_search_rounded,
                      size: 52,
                      color: AppColors.textTertiary(context),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Buscador académico global',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Encontrá instantáneamente materias, cátedras, apuntes, exámenes, horarios, tareas y calificaciones.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : totalResults == 0
              ? Center(
                  child: Text(
                    'Sin resultados para "$_query"',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                )
              : ListView(
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
                          if (matchingSubjects.isNotEmpty) ...[
                            Text(
                              'Materias (${matchingSubjects.length})',
                              style: AppTypography.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            ...matchingSubjects.map(
                              (s) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xs,
                                ),
                                child: AppCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: 4,
                                  ),
                                  onTap: () => context.push('/subjects/${s.id}'),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      radius: 6,
                                      backgroundColor: Color(s.colorValue),
                                    ),
                                    title: Text(
                                      s.name,
                                      style: AppTypography.titleSmall,
                                    ),
                                    subtitle: Text(
                                      [
                                        s.period,
                                        s.status.label,
                                        if (s.code != null) s.code!,
                                      ].join(' · '),
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          if (matchingExams.isNotEmpty) ...[
                            Text(
                              'Evaluaciones (${matchingExams.length})',
                              style: AppTypography.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            ...matchingExams.map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xs,
                                ),
                                child: AppCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: 4,
                                  ),
                                  onTap: () => context.push('/exams/${e.id}'),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.event_note_rounded,
                                    ),
                                    title: Text(
                                      e.title,
                                      style: AppTypography.titleSmall,
                                    ),
                                    subtitle: Text(
                                      '${subjectById[e.subjectId]?.name ?? ''} · ${AppFormatters.date(e.dateTime)} · ${e.type.label}',
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          if (matchingTasks.isNotEmpty) ...[
                            Text(
                              'Tareas y entregas (${matchingTasks.length})',
                              style: AppTypography.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            ...matchingTasks.map(
                              (t) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xs,
                                ),
                                child: AppCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: 4,
                                  ),
                                  onTap: () => UpsertTaskSheet.show(
                                    context,
                                    taskToEdit: t,
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      t.isCompleted
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked_rounded,
                                    ),
                                    title: Text(
                                      t.title,
                                      style: AppTypography.titleSmall,
                                    ),
                                    subtitle: Text(
                                      t.subjectId != null
                                          ? (subjectById[t.subjectId]?.name ??
                                              t.category.label)
                                          : t.category.label,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          if (matchingSessions.isNotEmpty) ...[
                            Text(
                              'Horarios de cursada (${matchingSessions.length})',
                              style: AppTypography.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            ...matchingSessions.map(
                              (s) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xs,
                                ),
                                child: AppCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: 4,
                                  ),
                                  onTap: () => UpsertClassSessionSheet.show(
                                    context,
                                    sessionToEdit: s,
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.schedule_rounded),
                                    title: Text(
                                      subjectById[s.subjectId]?.name ??
                                          'Materia',
                                      style: AppTypography.titleSmall,
                                    ),
                                    subtitle: Text(
                                      '${s.weekdayLabel} ${s.timeRangeLabel} hs · ${s.classroom ?? s.modality.label}',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          if (matchingTopics.isNotEmpty) ...[
                            Text(
                              'Temas de estudio (${matchingTopics.length})',
                              style: AppTypography.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            ...matchingTopics.map(
                              (t) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xs,
                                ),
                                child: AppCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: 4,
                                  ),
                                  onTap: () => UpsertTopicSheet.show(
                                    context,
                                    subjectId: t.subjectId,
                                    examId: t.examId,
                                    topicToEdit: t,
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading:
                                        const Icon(Icons.checklist_rounded),
                                    title: Text(
                                      t.title,
                                      style: AppTypography.titleSmall,
                                    ),
                                    subtitle: Text(
                                      '${subjectById[t.subjectId]?.name ?? ''} · ${t.status.label}',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          if (matchingGrades.isNotEmpty) ...[
                            Text(
                              'Calificaciones (${matchingGrades.length})',
                              style: AppTypography.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            ...matchingGrades.map(
                              (g) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xs,
                                ),
                                child: AppCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: 4,
                                  ),
                                  onTap: () => UpsertGradeSheet.show(
                                    context,
                                    gradeToEdit: g,
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.workspace_premium_rounded,
                                    ),
                                    title: Text(
                                      g.title,
                                      style: AppTypography.titleSmall,
                                    ),
                                    subtitle: Text(
                                      '${subjectById[g.subjectId]?.name ?? ''} · ${AppFormatters.date(g.date)}',
                                    ),
                                    trailing: Text(
                                      AppFormatters.grade(
                                        g.value,
                                        decimals: 2,
                                      ),
                                      style: AppTypography.titleMedium.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
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
}
