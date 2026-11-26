import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_spacing.dart';
import '../app_typography.dart';
import '../../../features/exams/presentation/upsert_exam_sheet.dart';
import '../../../features/grades/presentation/upsert_grade_sheet.dart';
import '../../../features/schedule/presentation/upsert_class_session_sheet.dart';
import '../../../features/subjects/data/subject_repository.dart';
import '../../../features/subjects/presentation/upsert_subject_sheet.dart';
import '../../../features/tasks/presentation/upsert_task_sheet.dart';
import 'pressable_scale.dart';
import 'spring_sheet.dart';

/// Centro universal de carga rápida ("Registrar en Aula").
class QuickCaptureSheet extends ConsumerWidget {
  const QuickCaptureSheet({super.key});

  static Future<void> show(BuildContext context) {
    return SpringSheet.show(
      context: context,
      title: 'Registrar en Aula',
      subtitle: 'Elegí qué querés guardar ahora mismo',
      showCloseButton: true,
      child: const QuickCaptureSheet(),
    );
  }

  Future<void> _requireSubjectOrOpen({
    required BuildContext context,
    required bool hasSubjects,
    required Future<void> Function() action,
  }) async {
    Navigator.of(context).pop();
    if (!hasSubjects) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero creá tu primera materia para asociar este registro.'),
        ),
      );
      await UpsertSubjectSheet.show(context);
      return;
    }
    await action();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsStreamProvider).value ?? const [];
    final hasSubjects = subjects.isNotEmpty;
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CaptureOptionTile(
          icon: Icons.check_circle_outline_rounded,
          color: const Color(0xFF0EA5E9),
          title: 'Tarea, Entrega o Trámite',
          subtitle: 'TPs, lecturas, guías o gestiones con fecha opcional',
          onTap: () {
            Navigator.of(context).pop();
            UpsertTaskSheet.show(context);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        _CaptureOptionTile(
          icon: Icons.event_note_rounded,
          color: primary,
          title: 'Evaluación / Examen',
          subtitle: 'Parciales, finales, recuperatorios, orales o quizzes',
          onTap: () => _requireSubjectOrOpen(
            context: context,
            hasSubjects: hasSubjects,
            action: () => UpsertExamSheet.show(context),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _CaptureOptionTile(
          icon: Icons.workspace_premium_rounded,
          color: AppColors.success,
          title: 'Calificación / Nota',
          subtitle: 'Notas ponderadas, recuperatorios y promedios automáticos',
          onTap: () => _requireSubjectOrOpen(
            context: context,
            hasSubjects: hasSubjects,
            action: () => UpsertGradeSheet.show(context),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _CaptureOptionTile(
          icon: Icons.schedule_rounded,
          color: const Color(0xFFD97706),
          title: 'Horario de Cursada',
          subtitle: 'Días, horas, aula y modalidad de tus clases semanales',
          onTap: () => _requireSubjectOrOpen(
            context: context,
            hasSubjects: hasSubjects,
            action: () => UpsertClassSessionSheet.show(context),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _CaptureOptionTile(
          icon: Icons.auto_stories_rounded,
          color: const Color(0xFF7C3AED),
          title: 'Materia',
          subtitle: 'Agregá asignaturas actuales o aprobadas de tu carrera',
          onTap: () {
            Navigator.of(context).pop();
            UpsertSubjectSheet.show(context);
          },
        ),
      ],
    );
  }
}

class _CaptureOptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CaptureOptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
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
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: ShapeDecoration(
          color: AppColors.surfaceSubtle(context),
          shape: AppRadius.continuousMd(
            side: BorderSide(color: AppColors.border(context)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: ShapeDecoration(
                color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                shape: AppRadius.continuousSm(),
              ),
              child: Icon(icon, color: readable, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary(context),
            ),
          ],
        ),
      ),
    );
  }
}
