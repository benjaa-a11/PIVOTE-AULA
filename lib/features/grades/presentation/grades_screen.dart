import 'package:fl_chart/fl_chart.dart';
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
import '../../../core/design_system/components/empty_state.dart';
import '../../../core/design_system/responsive.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../exams/data/exam_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../subjects/data/subject_repository.dart';
import '../../subjects/presentation/upsert_subject_sheet.dart';
import '../data/grade_repository.dart';
import '../domain/grade_entry.dart';
import 'grade_calculator_sheet.dart';
import 'grade_controller.dart';
import 'upsert_grade_sheet.dart';

class GradesScreen extends ConsumerWidget {
  const GradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final profile = ref.watch(profileStreamProvider).value;
    final passingThreshold = profile?.passingGrade ?? 4.0;
    final maxScale = profile?.maxScaleGrade ?? 10.0;

    final allGradesAsync = ref.watch(allGradesStreamProvider);
    final subjects = ref.watch(subjectsStreamProvider).value ?? const [];
    final allExams = ref.watch(examsStreamProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.gradesTitle, style: AppTypography.titleLarge),
        actions: [
          if (subjects.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.calculate_outlined),
              tooltip: 'Simulador de nota necesaria',
              onPressed: () => GradeCalculatorSheet.show(context),
            ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: AppButton(
              label: 'Nueva',
              icon: Icons.add_rounded,
              size: AppButtonSize.sm,
              onPressed: () {
                if (subjects.isEmpty) {
                  UpsertSubjectSheet.show(context);
                } else {
                  UpsertGradeSheet.show(context);
                }
              },
            ),
          ),
        ],
      ),
      body: allGradesAsync.when(
        data: (grades) {
          if (grades.isEmpty) {
            return EmptyState(
              icon: Icons.analytics_rounded,
              title: 'Sin calificaciones registradas',
              description:
                  'Registrá parciales, TPs y finales para ver promedios con y sin aplazos, evolución y simulador.',
              actionLabel: subjects.isEmpty
                  ? 'Crear primera materia'
                  : 'Registrar primera nota',
              onAction: () {
                if (subjects.isEmpty) {
                  UpsertSubjectSheet.show(context);
                } else {
                  UpsertGradeSheet.show(context);
                }
              },
            );
          }

          final effectiveList =
              GradeCalculations.effectiveGrades(grades, exams: allExams);
          final effectiveIds = effectiveList.map((g) => g.id).toSet();
          final weightedAvg =
              GradeCalculations.calculateAverage(grades, exams: allExams);
          final simpleAvg =
              GradeCalculations.calculateSimpleAverage(grades, exams: allExams);
          final noFailsAvg = GradeCalculations.calculateAverageWithoutFails(
            grades,
            passingGrade: passingThreshold,
            exams: allExams,
          );
          final isPassing = weightedAvg >= passingThreshold;

          final sortedEffective = List<GradeEntry>.from(effectiveList)
            ..sort((a, b) => a.date.compareTo(b.date));

          final maxGradeSeen = sortedEffective.fold<double>(
            maxScale,
            (m, g) => g.value > m ? g.value : m,
          );
          final chartMaxY = maxGradeSeen > 10 ? 100.0 : 10.0;

          final spots = <FlSpot>[
            for (int i = 0; i < sortedEffective.length; i++)
              FlSpot(i.toDouble(), sortedEffective[i].value.clamp(0, chartMaxY)),
          ];

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
                    // Hero Summary Row
                    AppCard(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PROMEDIO PONDERADO GENERAL',
                                      style: AppTypography.eyebrow.copyWith(
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isPassing
                                          ? 'Rendimiento general aprobado'
                                          : 'Debajo del umbral mínimo',
                                      style: AppTypography.caption.copyWith(
                                        color: isPassing
                                            ? AppColors.okFg(context)
                                            : AppColors.errFg(context),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${effectiveList.length} calificaciones vigentes',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textTertiary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: ShapeDecoration(
                                  color: (isPassing
                                          ? AppColors.success
                                          : AppColors.error)
                                      .withValues(alpha: isDark ? 0.20 : 0.10),
                                  shape: AppRadius.continuousMd(),
                                ),
                                child: Text(
                                  AppFormatters.grade(weightedAvg, decimals: 2),
                                  style: AppTypography.display.copyWith(
                                    color: isPassing
                                        ? AppColors.okFg(context)
                                        : AppColors.errFg(context),
                                    fontSize: 32,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Divider(color: AppColors.border(context), height: 1),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: _MiniStat(
                                  label: 'Promedio simple',
                                  value: AppFormatters.grade(
                                    simpleAvg,
                                    decimals: 2,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: _MiniStat(
                                  label: 'Sin aplazos',
                                  value: noFailsAvg > 0
                                      ? AppFormatters.grade(
                                          noFailsAvg,
                                          decimals: 2,
                                        )
                                      : '—',
                                ),
                              ),
                              Expanded(
                                child: _MiniStat(
                                  label: 'Aprobación',
                                  value:
                                      '>= ${AppFormatters.grade(passingThreshold)}',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Evolution Line Chart
                    if (spots.length >= 2) ...[
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Curva de evolución académica',
                                  style: AppTypography.titleSmall,
                                ),
                                Text(
                                  'Escala 0–${chartMaxY.toInt()}',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textTertiary(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            SizedBox(
                              height: 160,
                              child: LineChart(
                                LineChartData(
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    horizontalInterval: chartMaxY / 4,
                                    getDrawingHorizontalLine: (_) => FlLine(
                                      color: AppColors.border(context),
                                      strokeWidth: 1,
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 28,
                                        interval: chartMaxY / 2,
                                        getTitlesWidget: (val, _) => Text(
                                          val.toInt().toString(),
                                          style: AppTypography.caption.copyWith(
                                            color:
                                                AppColors.textTertiary(context),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    bottomTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  minY: 0,
                                  maxY: chartMaxY,
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: spots,
                                      isCurved: true,
                                      preventCurveOverShooting: true,
                                      color: primary,
                                      barWidth: 3,
                                      isStrokeCapRound: true,
                                      dotData: const FlDotData(show: true),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: primary.withValues(alpha: 0.14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    const Text(
                      'Desglose por materia',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...subjects.map((sub) {
                      final subGrades =
                          grades.where((g) => g.subjectId == sub.id).toList();
                      if (subGrades.isEmpty) return const SizedBox.shrink();

                      final subAvg = GradeCalculations.calculateAverage(
                        subGrades,
                        exams: allExams,
                      );
                      final subColor = Color(sub.colorValue);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () =>
                                    context.push('/subjects/${sub.id}'),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 11,
                                      height: 11,
                                      decoration: BoxDecoration(
                                        color: subColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        sub.name,
                                        style: AppTypography.titleSmall,
                                      ),
                                    ),
                                    Text(
                                      'Prom: ${AppFormatters.grade(subAvg, decimals: 2)}',
                                      style: AppTypography.titleSmall.copyWith(
                                        color: subAvg >= sub.passingGrade
                                            ? AppColors.okFg(context)
                                            : AppColors.errFg(context),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Divider(
                                height: 1,
                                color: AppColors.border(context),
                              ),
                              ...subGrades.map((g) {
                                final replaced = !effectiveIds.contains(g.id);
                                return Dismissible(
                                  key: Key(g.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 16),
                                    color: AppColors.error,
                                    child: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                  onDismissed: (_) {
                                    ref
                                        .read(gradeControllerProvider.notifier)
                                        .deleteGrade(g.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Se eliminó ${g.title}'),
                                        action: SnackBarAction(
                                          label: AppStrings.undo,
                                          onPressed: () => ref
                                              .read(gradeControllerProvider
                                                  .notifier)
                                              .restoreGrade(g.id),
                                        ),
                                      ),
                                    );
                                  },
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    onTap: () => UpsertGradeSheet.show(
                                      context,
                                      gradeToEdit: g,
                                    ),
                                    title: Text(
                                      g.title,
                                      style: AppTypography.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                        decoration: replaced
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: replaced
                                            ? AppColors.textTertiary(context)
                                            : AppColors.textPrimary(context),
                                      ),
                                    ),
                                    subtitle: Text(
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
                                    trailing: Text(
                                      AppFormatters.grade(
                                        g.value,
                                        decimals: 2,
                                      ),
                                      style: AppTypography.titleMedium.copyWith(
                                        color: replaced
                                            ? AppColors.textTertiary(context)
                                            : (g.value >= sub.passingGrade
                                                ? AppColors.okFg(context)
                                                : AppColors.errFg(context)),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                );
                              }),
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
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
          ),
        ),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}
