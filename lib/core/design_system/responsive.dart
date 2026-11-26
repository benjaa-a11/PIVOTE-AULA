import 'package:flutter/material.dart';
import 'app_spacing.dart';

/// Sistema responsivo para adaptar Pivote Aula desde móviles compactos (320dp)
/// hasta tablets, pantallas plegables y escritorio/web.
class AppBreakpoints {
  AppBreakpoints._();

  static const double compact = 640;
  static const double rail = 760;
  static const double expanded = 1080;
  static const double maxContentWidth = 1120;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  bool get isCompact => screenWidth < AppBreakpoints.compact;
  bool get useNavigationRail => screenWidth >= AppBreakpoints.rail;
  bool get isExpanded => screenWidth >= AppBreakpoints.expanded;

  double get pageHorizontalPadding {
    if (screenWidth >= AppBreakpoints.expanded) return AppSpacing.xxl;
    if (screenWidth >= AppBreakpoints.compact) return AppSpacing.xl;
    return AppSpacing.lg;
  }

  int adaptiveColumns({double minTileWidth = 280, int maxColumns = 4}) {
    final usable = (screenWidth - pageHorizontalPadding * 2)
        .clamp(200.0, AppBreakpoints.maxContentWidth);
    return (usable / minTileWidth).floor().clamp(1, maxColumns);
  }
}

/// Centra y limita el ancho máximo del contenido en pantallas anchas sin
/// afectar el scroll completo del viewport.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      ),
    );
  }
}
