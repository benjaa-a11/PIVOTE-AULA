import 'package:flutter/material.dart';

/// Conjunto canónico de íconos académicos para materias.
/// Constantes en tiempo de compilación para preservar tree-shaking en release.
abstract final class SubjectIcons {
  static const List<IconData> available = [
    Icons.book_rounded,
    Icons.calculate_rounded,
    Icons.science_rounded,
    Icons.computer_rounded,
    Icons.code_rounded,
    Icons.language_rounded,
    Icons.architecture_rounded,
    Icons.psychology_rounded,
    Icons.draw_rounded,
    Icons.gavel_rounded,
    Icons.biotech_rounded,
    Icons.account_balance_rounded,
    Icons.insights_rounded,
    Icons.medical_services_rounded,
    Icons.memory_rounded,
    Icons.public_rounded,
  ];

  static IconData fromCodePoint(int codePoint) {
    for (final icon in available) {
      if (icon.codePoint == codePoint) {
        return icon;
      }
    }
    return Icons.book_rounded;
  }
}
