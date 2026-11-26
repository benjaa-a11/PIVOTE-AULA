import 'package:flutter/material.dart';

/// Tokens globales de color para Pivote Aula.
/// Calibrados para alto contraste, legibilidad editorial y cero ruido visual
/// tanto en modo claro como oscuro.
class AppColors {
  AppColors._();

  // Marca principal (Electric Indigo)
  static const int defaultAccentValue = 0xFF4F46E5;
  static const Color primary = Color(defaultAccentValue);
  static const Color primaryDark = Color(0xFF818CF8);
  static const Color secondary = Color(0xFF0EA5E9);
  static const Color secondaryDark = Color(0xFF38BDF8);

  // Paleta curada de acentos de interfaz
  static const List<Color> accentOptions = [
    Color(0xFF4F46E5), // Indigo
    Color(0xFF2563EB), // Cobalt
    Color(0xFF0284C7), // Sky
    Color(0xFF0D9488), // Teal
    Color(0xFF059669), // Emerald
    Color(0xFF7C3AED), // Violet
    Color(0xFFD97706), // Amber
    Color(0xFFE11D48), // Rose
  ];

  // Paleta armónica para identificar materias
  static const List<Color> subjectColors = [
    Color(0xFF4F46E5),
    Color(0xFF2563EB),
    Color(0xFF0284C7),
    Color(0xFF0D9488),
    Color(0xFF10B981),
    Color(0xFF16A34A),
    Color(0xFFD97706),
    Color(0xFFEA580C),
    Color(0xFFE11D48),
    Color(0xFFDB2777),
    Color(0xFF7C3AED),
    Color(0xFF475569),
  ];

  // Semántica académica (modo claro base + adaptadores dinámicos)
  static const Color success = Color(0xFF10B981);
  static const Color successDarkText = Color(0xFF34D399);
  static const Color enrolled = Color(0xFF3B82F6);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningDarkText = Color(0xFFFBBF24);
  static const Color error = Color(0xFFEF4444);
  static const Color errorDarkText = Color(0xFFF87171);
  static const Color pending = Color(0xFF64748B);
  static const Color info = secondary;

  // Light Mode Surfaces & Ink
  static const Color lightBg = Color(0xFFF4F6FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightSurfaceSubtle = Color(0xFFF8FAFC);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderSubtle = Color(0xFFEEF2F6);
  static const Color lightTextPrimary = Color(0xFF0B1120);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextTertiary = Color(0xFF94A3B8);

  // Dark Mode Surfaces & Ink
  static const Color darkBg = Color(0xFF090D16);
  static const Color darkSurface = Color(0xFF111726);
  static const Color darkSurfaceElevated = Color(0xFF172033);
  static const Color darkSurfaceSubtle = Color(0xFF0E1422);
  static const Color darkBorder = Color(0xFF222F46);
  static const Color darkBorderSubtle = Color(0xFF1A2436);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);

  // Tinted status containers
  static const Color successLight = Color(0xFFECFDF5);
  static const Color successDark = Color(0xFF064E3B);
  static const Color enrolledLight = Color(0xFFEFF6FF);
  static const Color enrolledDark = Color(0xFF172554);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color warningDark = Color(0xFF451A03);
  static const Color errorLight = Color(0xFFFEF2F2);
  static const Color errorDark = Color(0xFF450A0A);
  static const Color pendingLight = Color(0xFFF1F5F9);
  static const Color pendingDark = Color(0xFF1E293B);
  static const Color infoLight = Color(0xFFF0F9FF);
  static const Color infoDark = Color(0xFF082F49);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
      _isDark(context) ? darkBg : lightBg;

  static Color surface(BuildContext context) =>
      _isDark(context) ? darkSurface : lightSurface;

  static Color surfaceElevated(BuildContext context) =>
      _isDark(context) ? darkSurfaceElevated : lightSurfaceElevated;

  static Color surfaceSubtle(BuildContext context) =>
      _isDark(context) ? darkSurfaceSubtle : lightSurfaceSubtle;

  static Color border(BuildContext context) =>
      _isDark(context) ? darkBorder : lightBorder;

  static Color borderSubtle(BuildContext context) =>
      _isDark(context) ? darkBorderSubtle : lightBorderSubtle;

  static Color textPrimary(BuildContext context) =>
      _isDark(context) ? darkTextPrimary : lightTextPrimary;

  static Color textSecondary(BuildContext context) =>
      _isDark(context) ? darkTextSecondary : lightTextSecondary;

  static Color textTertiary(BuildContext context) =>
      _isDark(context) ? darkTextTertiary : lightTextTertiary;

  static Color okFg(BuildContext context) =>
      _isDark(context) ? successDarkText : const Color(0xFF059669);

  static Color warnFg(BuildContext context) =>
      _isDark(context) ? warningDarkText : const Color(0xFFD97706);

  static Color errFg(BuildContext context) =>
      _isDark(context) ? errorDarkText : const Color(0xFFDC2626);

  /// Ajusta un color arbitrario (ej. color de materia o acento) para asegurar
  /// legibilidad cuando se usa como texto o ícono sobre superficies oscuras.
  static Color readableAccent(Color base, {required bool isDark}) {
    if (!isDark) return base;
    final hsl = HSLColor.fromColor(base);
    if (hsl.lightness < 0.66) {
      return hsl.withLightness(0.70).withSaturation((hsl.saturation * 1.05).clamp(0.0, 1.0)).toColor();
    }
    return base;
  }
}
