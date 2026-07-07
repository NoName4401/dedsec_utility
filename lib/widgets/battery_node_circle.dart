import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BatteryNodeCircle extends StatelessWidget {
  /// Range 0.0 - 1.0 (device battery %)
  final double percentage;

  const BatteryNodeCircle({super.key, required this.percentage});

  @override
  Widget build(BuildContext context) {
    // Isolated behind RepaintBoundary to lock the complex graphic from redraws
    return RepaintBoundary(
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // =============================================
            // CENTRAL GLOWING BOLT NODE
            // =============================================
            Container(
              width: 70,
              height: 70,
              decoration: hudPanelDecoration(borderColor: AppColors.cyan, glow: 0.25).copyWith(
                shape: BoxShape.circle,
                color: AppColors.background, // Pure core separation
              ),
              child: Center(
                child: Icon(
                  Icons.flash_on,
                  color: AppColors.cyan,
                  size: 38,
                  // Custom glow effect for the icon itself
                  shadows: [
                    Shadow(
                      color: AppColors.cyan.withOpacity(0.9),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),

            // =============================================
            // OUTER ARC RINGS (SEGMENTED)
            // =============================================
            CustomPaint(
              size: const Size(120, 120), // Target viewport size
              painter: _BotnetArcPainter(percentage: percentage),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotnetArcPainter extends CustomPainter {
  final double percentage;

  _BotnetArcPainter({required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;
    const double thickness = 14.0;
    const int segmentsPerArc = 12; // Matching reference geometry

    // Baseline Paint Styles
    final emptyPaint = Paint()
      ..color = AppColors.glitchGrey.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;

    final filledPaint = Paint()
      ..color = AppColors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;

    // Outer framing arc limits (0 - 2*pi)
    const double arcGap = (2 * pi / 30); // Visual separation between left/right arcs

    // =============================================
    // LEFT ARC (REAL BATTERY %): TRACKS PERCENTAGE
    // =============================================
    final leftStart = -pi - (pi / 2) + (arcGap / 2); // Rotated to top-center
    final leftSweep = (pi - arcGap);

    // Draw base (gray)
    canvas.drawArc(Rect.fromCircle(center: center, radius: maxRadius), leftStart, leftSweep, false, emptyPaint);

    // Draw filled (cyan) portion based on percentage
    canvas.drawArc(Rect.fromCircle(center: center, radius: maxRadius), leftStart, leftSweep * percentage, false, filledPaint);

    // =============================================
    // RIGHT ARC (BOTNET LOAD): STATIC FULLY LIT
    // =============================================
    final rightStart = -pi / 2 + (arcGap / 2);
    final rightSweep = (pi - arcGap);

    // Right arc remains completely illuminated as a tactical decor element
    canvas.drawArc(Rect.fromCircle(center: center, radius: maxRadius), rightStart, rightSweep, false, filledPaint);

    // =============================================
    // SEGMENTATION (CUTOUTS): RENDERED ON TOP
    // =============================================
    // This painter uncouples the segments into physical notches
    final cutoutPaint = Paint()
      ..color = AppColors.background.withOpacity(0.85) // Blends with HUD background
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final totalRotation = (2 * pi / segmentsPerArc);

    for (int i = 0; i < segmentsPerArc * 2; i++) {
      final angle = (i * totalRotation);

      final dx = center.dx + maxRadius * cos(angle);
      final dy = center.dy + maxRadius * sin(angle);

      // Simple lines drawn to look like physical segments/notches
      canvas.drawLine(
          Offset(dx - (thickness / 2 + 1), dy - (thickness / 2 + 1)),
          Offset(dx + (thickness / 2 + 1), dy + (thickness / 2 + 1)),
          cutoutPaint
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BotnetArcPainter oldDelegate) => oldDelegate.percentage != percentage;
}