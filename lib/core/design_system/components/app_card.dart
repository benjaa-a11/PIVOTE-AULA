import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_spacing.dart';
import 'pressable_scale.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BorderSide? border;
  final ShapeBorder? customShape;
  final Gradient? gradient;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.border,
    this.customShape,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final defaultBorder = BorderSide(
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      width: 1,
    );

    final effectiveShape = customShape ??
        AppRadius.continuousLg(side: border ?? defaultBorder);

    final cardContent = Container(
      padding: padding,
      decoration: ShapeDecoration(
        color: gradient == null ? (color ?? defaultBg) : null,
        gradient: gradient,
        shape: effectiveShape,
        shadows: isDark
            ? const []
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.035),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: child,
    );

    if (onTap != null || onLongPress != null) {
      return PressableScale(
        enableHaptics: true,
        onTap: onTap,
        onLongPress: onLongPress,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
