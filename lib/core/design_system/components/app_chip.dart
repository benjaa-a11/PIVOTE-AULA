import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_spacing.dart';
import '../app_typography.dart';
import 'pressable_scale.dart';

class AppChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget? icon;
  final Color? activeColor;
  final int? count;

  const AppChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.icon,
    this.activeColor,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseAccent = activeColor ?? theme.colorScheme.primary;
    final readable = AppColors.readableAccent(baseAccent, isDark: isDark);

    final bg = isSelected
        ? baseAccent.withValues(alpha: isDark ? 0.22 : 0.12)
        : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurface);

    final fg = isSelected
        ? readable
        : AppColors.textSecondary(context);

    final border = isSelected
        ? BorderSide(
            color: readable.withValues(alpha: isDark ? 0.50 : 0.35),
            width: 1.2,
          )
        : BorderSide(
            color: AppColors.border(context),
            width: 1,
          );

    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppRadius.continuousSm(side: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            IconTheme(
              data: IconThemeData(color: fg, size: 15),
              child: icon!,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(
                color: fg,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                count.toString(),
                style: AppTypography.caption.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return PressableScale(
        enableHaptics: true,
        onTap: onTap,
        child: chip,
      );
    }

    return chip;
  }
}
