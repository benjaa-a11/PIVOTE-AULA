import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_typography.dart';

/// Vectorial brand mark for **Pivote Aula**.
///
/// Combines a precision squircle shield with an architectural "A" / Pivot
/// prism and open academic pages — crisp at any resolution from 20px to 256px.
class AulaLogoMark extends StatelessWidget {
  final double size;
  final Color? accentColor;
  final bool showGlow;

  const AulaLogoMark({
    super.key,
    this.size = 40,
    this.accentColor,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = accentColor ?? Theme.of(context).colorScheme.primary;
    final secondary = Color.lerp(primary, const Color(0xFF0EA5E9), 0.38)!;
    final deepBase = Color.lerp(primary, const Color(0xFF0B1120), 0.28)!;
    final radius = size * 0.28;

    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [secondary, primary, deepBase],
          stops: const [0.0, 0.52, 1.0],
        ),
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(radius * 1.65),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.22),
            width: (size * 0.025).clamp(0.8, 2.0),
          ),
        ),
        shadows: showGlow
            ? [
                BoxShadow(
                  color: primary.withValues(alpha: 0.36),
                  blurRadius: size * 0.42,
                  offset: Offset(0, size * 0.14),
                ),
              ]
            : [
                BoxShadow(
                  color: primary.withValues(alpha: 0.18),
                  blurRadius: size * 0.18,
                  offset: Offset(0, size * 0.06),
                ),
              ],
      ),
      child: CustomPaint(
        size: Size.square(size),
        painter: _AulaGlyphPainter(),
      ),
    );
  }
}

class _AulaGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Subtle top gloss arc
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.20),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.55));
    canvas.drawCircle(Offset(w * 0.32, h * 0.16), w * 0.46, glossPaint);

    // Architectural "A" / Pivot spire
    final leftPillar = Path()
      ..moveTo(w * 0.50, h * 0.19)
      ..lineTo(w * 0.24, h * 0.76)
      ..lineTo(w * 0.365, h * 0.76)
      ..lineTo(w * 0.50, h * 0.44)
      ..close();

    final rightPillar = Path()
      ..moveTo(w * 0.50, h * 0.19)
      ..lineTo(w * 0.76, h * 0.76)
      ..lineTo(w * 0.635, h * 0.76)
      ..lineTo(w * 0.50, h * 0.44)
      ..close();

    // Open book / pivot crossbar wing
    final pivotWing = Path()
      ..moveTo(w * 0.30, h * 0.60)
      ..quadraticBezierTo(w * 0.50, h * 0.685, w * 0.70, h * 0.60)
      ..lineTo(w * 0.665, h * 0.675)
      ..quadraticBezierTo(w * 0.50, h * 0.755, w * 0.335, h * 0.675)
      ..close();

    final whiteSolid = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final whiteTranslucent = Paint()
      ..color = Colors.white.withValues(alpha: 0.84)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final accentDotPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(leftPillar, whiteSolid);
    canvas.drawPath(rightPillar, whiteTranslucent);
    canvas.drawPath(pivotWing, whiteSolid);

    // Fulcrum / Pivot jewel dot at apex center
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.545),
      w * 0.048,
      accentDotPaint,
    );
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.545),
      w * 0.024,
      whiteSolid,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Horizontal lockup with logo mark + "Aula" / "PIVOTE" wordmark.
class AulaBrandLockup extends StatelessWidget {
  final double markSize;
  final bool showTagline;
  final bool compact;

  const AulaBrandLockup({
    super.key,
    this.markSize = 34,
    this.showTagline = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AulaLogoMark(size: markSize),
        SizedBox(width: compact ? 8 : 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Aula',
                  style: AppTypography.titleMedium.copyWith(
                    color: textPrimary,
                    fontSize: compact ? 17 : 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.05,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    'PIVOTE',
                    style: AppTypography.eyebrow.copyWith(
                      color: primary,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
              ],
            ),
            if (showTagline) ...[
              const SizedBox(height: 2),
              Text(
                'Gestión académica integral',
                style: AppTypography.caption.copyWith(
                  color: textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
