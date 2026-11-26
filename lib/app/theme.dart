import 'package:flutter/material.dart';
import '../core/design_system/app_colors.dart';
import '../core/design_system/app_spacing.dart';
import '../core/design_system/app_typography.dart';
import '../core/design_system/academic_status_colors.dart';

/// Sistema de diseño global Material 3 para Pivote Aula.
class AppTheme {
  AppTheme._();

  static const TextTheme _textTheme = TextTheme(
    displayLarge: AppTypography.display,
    headlineLarge: AppTypography.display,
    headlineMedium: AppTypography.titleLarge,
    headlineSmall: AppTypography.titleMedium,
    titleLarge: AppTypography.titleLarge,
    titleMedium: AppTypography.titleMedium,
    titleSmall: AppTypography.titleSmall,
    bodyLarge: AppTypography.bodyLarge,
    bodyMedium: AppTypography.bodyMedium,
    bodySmall: AppTypography.bodySmall,
    labelLarge: AppTypography.button,
    labelMedium: AppTypography.label,
    labelSmall: AppTypography.caption,
  );

  static ButtonStyle _buttonStyle(Color foreground, Color background) =>
      ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
        ),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: const WidgetStatePropertyAll(AppTypography.button),
        foregroundColor: WidgetStatePropertyAll(foreground),
        backgroundColor: WidgetStatePropertyAll(background),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );

  static IconButtonThemeData _iconButtonTheme() => IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(42, 42)),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  static InputDecorationTheme _inputTheme({
    required bool isDark,
    required Color primary,
  }) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final fillColor =
        isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceSubtle;

    OutlineInputBorder outline(BorderSide side) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: side,
        );

    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: outline(BorderSide(color: borderColor)),
      enabledBorder: outline(BorderSide(color: borderColor)),
      focusedBorder: outline(BorderSide(color: primary, width: 1.6)),
      errorBorder: outline(const BorderSide(color: AppColors.error)),
      focusedErrorBorder:
          outline(const BorderSide(color: AppColors.error, width: 1.6)),
    );
  }

  static ColorScheme _scheme({
    required bool isDark,
    required Color accentColor,
  }) {
    final primary = AppColors.readableAccent(accentColor, isDark: isDark);
    final onPrimary =
        ThemeData.estimateBrightnessForColor(primary) == Brightness.dark
            ? Colors.white
            : const Color(0xFF090D16);

    if (isDark) {
      final primaryContainer =
          Color.lerp(accentColor, const Color(0xFF090D16), 0.72)!;
      final onPrimaryContainer =
          Color.lerp(primary, Colors.white, 0.55)!;
      return ColorScheme(
        brightness: Brightness.dark,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: AppColors.secondaryDark,
        onSecondary: const Color(0xFF082F49),
        secondaryContainer: const Color(0xFF12334A),
        onSecondaryContainer: const Color(0xFFE0F2FE),
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        surfaceContainerLowest: AppColors.darkBg,
        surfaceContainerLow: AppColors.darkSurfaceSubtle,
        surfaceContainer: AppColors.darkSurface,
        surfaceContainerHigh: AppColors.darkSurfaceElevated,
        surfaceContainerHighest: const Color(0xFF24324B),
        error: AppColors.errorDarkText,
        onError: const Color(0xFF450A0A),
        outline: AppColors.darkBorder,
        outlineVariant: AppColors.darkBorderSubtle,
      );
    }

    final primaryContainer = Color.lerp(accentColor, Colors.white, 0.88)!;
    final onPrimaryContainer =
        Color.lerp(accentColor, const Color(0xFF0B1120), 0.35)!;

    return ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFE0F2FE),
      onSecondaryContainer: const Color(0xFF075985),
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: AppColors.lightSurfaceSubtle,
      surfaceContainer: AppColors.lightSurfaceSubtle,
      surfaceContainerHigh: const Color(0xFFEEF2F7),
      surfaceContainerHighest: AppColors.lightBorder,
      error: AppColors.error,
      onError: Colors.white,
      outline: AppColors.lightBorder,
      outlineVariant: AppColors.lightBorderSubtle,
    );
  }

  static ThemeData light({Color accentColor = AppColors.primary}) {
    return _buildTheme(
      scheme: _scheme(isDark: false, accentColor: accentColor),
      isDark: false,
    );
  }

  static ThemeData dark({Color accentColor = AppColors.primary}) {
    return _buildTheme(
      scheme: _scheme(isDark: true, accentColor: accentColor),
      isDark: true,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required bool isDark,
  }) {
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bgColor,
      canvasColor: surfaceColor,
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFallbacks,
      textTheme: _textTheme.apply(
        bodyColor: textColor,
        displayColor: textColor,
      ),
      extensions: <ThemeExtension<dynamic>>[
        isDark ? AcademicStatusColors.dark : AcademicStatusColors.light,
      ],
      inputDecorationTheme:
          _inputTheme(isDark: isDark, primary: scheme.primary),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _buttonStyle(scheme.onPrimary, scheme.primary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonStyle(scheme.onPrimary, scheme.primary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle(scheme.primary, Colors.transparent).copyWith(
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _buttonStyle(scheme.primary, Colors.transparent),
      ),
      iconButtonTheme: _iconButtonTheme(),
      dividerTheme:
          DividerThemeData(color: borderColor, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.titleLarge.copyWith(color: textColor),
        iconTheme: IconThemeData(color: textColor),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w500),
        labelColor: scheme.primary,
        unselectedLabelColor: secondaryTextColor,
        dividerColor: borderColor,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        modalBackgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: borderColor),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: borderColor),
        ),
        elevation: isDark ? 0 : 4,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? AppColors.darkSurfaceElevated : AppColors.lightTextPrimary,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: isDark ? scheme.primary : const Color(0xFF93C5FD),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        elevation: 0,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.22 : 0.12),
        labelTextStyle: const WidgetStatePropertyAll(AppTypography.label),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.20 : 0.12),
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 22),
        unselectedIconTheme: IconThemeData(color: secondaryTextColor, size: 22),
        selectedLabelTextStyle: AppTypography.label.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: AppTypography.label.copyWith(
          color: secondaryTextColor,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        labelStyle: AppTypography.label.copyWith(color: textColor),
        backgroundColor: surfaceColor,
        selectedColor: scheme.primary.withValues(alpha: 0.14),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        textColor: textColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? AppColors.darkTextSecondary : const Color(0xFFCBD5E1);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return Colors.transparent;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
