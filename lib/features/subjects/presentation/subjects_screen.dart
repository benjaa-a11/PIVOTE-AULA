import 'package:flutter/material.dart';
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
import '../../../core/design_system/components/app_text_field.dart';
import '../../../core/design_system/components/empty_state.dart';
import '../../../core/design_system/responsive.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../exams/data/exam_repository.dart';
import '../../grades/data/grade_repository.dart';
import '../../grades/presentation/grade_controller.dart';
import '../../schedule/data/schedule_repository.dart';
import '../data/subject_repository.dart';
import '../domain/cuatrimestre.dart';
import '../domain/subject.dart';
import '../domain/subject_icons.dart';
import 'subject_controller.dart';
import 'upsert_subject_sheet.dart';

class SubjectsScreen extends ConsumerStatefulWidget {
  const SubjectsScreen({super.key});

  @override
  ConsumerState<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends ConsumerState<SubjectsScreen> {
  final _searchController = TextEditingController();
  SubjectStatus? _selectedStatusFilter;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectsStreamProvider);
    final allGrades = ref.watch(allGradesStreamProvider).value ?? const [];
    final allExams = ref.watch(examsStreamProvider).value ?? const [];
    final allSessions =
        ref.watch(classSessionsStreamProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppStrings.subjectsTitle,
          style: AppTypography.titleLarge,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: AppButton(
              label: 'Nueva',
              icon: Icons.add_rounded,
              size: AppButtonSize.sm,
              onPressed: () => UpsertSubjectSheet.show(context),
            ),
          ),
        ],
      ),
      body: subjectsAsync.when(
        data: (subjects) {
          final filtered = subjects.where((s) {
            final matchesStatus = _selectedStatusFilter == null ||
                s.status == _selectedStatusFilter;
            final q = _searchQuery.toLowerCase();
            final matchesSearch = q.isEmpty ||
                s.name.toLowerCase().contains(q) ||
                (s.code?.toLowerCase().contains(q) ?? false) ||
                (s.professor?.toLowerCase().contains(q) ?? false) ||
                s.period.toLowerCase().contains(q);
            return matchesStatus && matchesSearch;
          }).toList();
          final cuatrimestres = Cuatrimestre.agruparMaterias(filtered);

          return ListView(
            padding: EdgeInsets.fromLTRB(
              context.pageHorizontalPadding,
              AppSpacing.md,
              context.pageHorizontalPadding,
              88,
            ),
            physics: appScrollPhysics(),
            children: [
              ResponsiveContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSearchBar(
                      controller: _searchController,
                      hintText:
                          'Buscar por materia, código, docente o cuatrimestre...',
                      currentQuery: _searchQuery,
                      onChanged: (val) =>
                          setState(() => _searchQuery = val.trim()),
                      onClear: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: appScrollPhysics(),
                      child: Row(
                        children: [
                          AppChip(
                            label: 'Todas',
                            count: subjects.length,
                            isSelected: _selectedStatusFilter == null,
                            onTap: () =>
                                setState(() => _selectedStatusFilter = null),
                          ),
                          ...SubjectStatus.values.map((status) {
                            final count = subjects
                                .where((s) => s.status == status)
                                .length;
                            if (count == 0) return const SizedBox.shrink();
                            return Padding(
                              padding:
                                  const EdgeInsets.only(left: AppSpacing.sm),
                              child: AppChip(
                                label: status.label,
                                count: count,
                                isSelected: _selectedStatusFilter == status,
                                onTap: () => setState(
                                  () => _selectedStatusFilter = status,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (filtered.isEmpty)
                      EmptyState(
                        icon: Icons.auto_stories_rounded,
                        title: subjects.isEmpty
                            ? AppStrings.noSubjectsYet
                            : 'Sin coincidencias',
                        description: subjects.isEmpty
                            ? AppStrings.noSubjectsDesc
                            : 'Probá con otro término o limpiá el filtro activo.',
                        actionLabel:
                            subjects.isEmpty ? AppStrings.newSubject : null,
                        onAction: subjects.isEmpty
                            ? () => UpsertSubjectSheet.show(context)
                            : null,
                      )
                    else
                      ...cuatrimestres.map((cuatrimestre) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          child: _PeriodGroupCard(
                            cuatrimestre: cuatrimestre,
                            allGrades: allGrades,
                            allExams: allExams,
                            allSessions: allSessions,
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
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _PeriodGroupCard extends StatelessWidget {
  final Cuatrimestre cuatrimestre;
  final List<dynamic> allGrades;
  final List<dynamic> allExams;
  final List<dynamic> allSessions;

  const _PeriodGroupCard({
    required this.cuatrimestre,
    required this.allGrades,
    required this.allExams,
    required this.allSessions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: ShapeDecoration(
        color: AppColors.surface(context),
        shape: AppRadius.continuousLg(
          side: BorderSide(color: AppColors.border(context)),
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 4,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: ShapeDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: AppRadius.continuousSm(),
            ),
            child: Icon(
              Icons.layers_outlined,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          title: Text(
            cuatrimestre.nombre,
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            [
              '${cuatrimestre.cantidadMaterias} ${cuatrimestre.cantidadMaterias == 1 ? 'materia' : 'materias'}',
              '${cuatrimestre.materiasAprobadas} aprobadas',
              if (cuatrimestre.creditosTotales > 0)
                '${cuatrimestre.creditosAprobados}/${cuatrimestre.creditosTotales} créd.',
            ].join(' · '),
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          children: cuatrimestre.materias.map((subject) {
            final subGrades = allGrades
                .where((g) => g.subjectId == subject.id)
                .toList()
                .cast<dynamic>();
            final subAvg = subGrades.isEmpty
                ? null
                : GradeCalculations.calculateAverage(
                    subGrades.cast(),
                    exams: allExams.cast(),
                  );
            final subSessions = allSessions
                .where((s) => s.subjectId == subject.id)
                .toList();
            final scheduleSummary = subSessions.isEmpty
                ? null
                : subSessions
                    .map((s) => '${s.weekdayShort} ${s.timeRangeLabel}')
                    .join(' · ');

            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: _SubjectCard(
                subject: subject,
                average: subAvg,
                scheduleSummary: scheduleSummary,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SubjectCard extends ConsumerWidget {
  final Subject subject;
  final double? average;
  final String? scheduleSummary;

  const _SubjectCard({
    required this.subject,
    this.average,
    this.scheduleSummary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subjectColor = Color(subject.colorValue);
    final readableSub = AppColors.readableAccent(subjectColor, isDark: isDark);

    return Dismissible(
      key: Key(subject.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: ShapeDecoration(
          color: AppColors.error,
          shape: AppRadius.continuousMd(),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('¿Ocultar materia?'),
            content: Text(
              'Se archivará "${subject.name}". Podés deshacer esta acción.',
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
        return confirmed ?? false;
      },
      onDismissed: (_) {
        ref.read(subjectControllerProvider.notifier).deleteSubject(subject.id);
        ScaffoldMessenger.of(context).showSnackBar(
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
      },
      child: AppCard(
        color: AppColors.surfaceSubtle(context),
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () => context.push('/subjects/${subject.id}'),
        child: Row(
          children: [
            Hero(
              tag: 'subject_icon_${subject.id}',
              child: Container(
                width: 46,
                height: 46,
                decoration: ShapeDecoration(
                  color: subjectColor.withValues(alpha: isDark ? 0.24 : 0.12),
                  shape: AppRadius.continuousMd(),
                ),
                child: Icon(
                  SubjectIcons.fromCodePoint(subject.iconCode),
                  color: readableSub,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subject.name,
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.textPrimary(context),
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: ShapeDecoration(
                          color: subjectColor.withValues(
                            alpha: isDark ? 0.22 : 0.12,
                          ),
                          shape: AppRadius.continuousSm(),
                        ),
                        child: Text(
                          subject.status.label,
                          style: AppTypography.caption.copyWith(
                            color: readableSub,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (subject.code != null) subject.code!,
                      if (subject.professor != null) subject.professor!,
                      if (subject.classroom != null) subject.classroom!,
                      if (scheduleSummary != null) scheduleSummary!,
                    ].isEmpty
                        ? 'Tocá para gestionar horarios, exámenes, asistencia y notas'
                        : [
                            if (subject.code != null) subject.code!,
                            if (subject.professor != null) subject.professor!,
                            if (subject.classroom != null) subject.classroom!,
                            if (scheduleSummary != null) scheduleSummary!,
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
            if (average != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: ShapeDecoration(
                  color: (average! >= subject.passingGrade
                          ? AppColors.success
                          : AppColors.error)
                      .withValues(alpha: isDark ? 0.20 : 0.10),
                  shape: AppRadius.continuousSm(),
                ),
                child: Text(
                  AppFormatters.grade(average),
                  style: AppTypography.label.copyWith(
                    color: average! >= subject.passingGrade
                        ? AppColors.okFg(context)
                        : AppColors.errFg(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
