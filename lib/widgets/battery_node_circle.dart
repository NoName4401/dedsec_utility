import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BatteryNodeCircle extends StatelessWidget {
  /// Range 0.0 - 1.0 (device battery %)
  final double percentage;

  const BatteryNodeCircle({super.key, required this.percentage});

  @override
  Widget build(BuildContext context) {
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.background,
                border: Border.all(color: AppColors.cyan, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyan.withOpacity(0.25),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.flash_on,
                  color: AppColors.cyan,
                  size: 38,
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
            // HIGH-PRECISION SEGMENTED OUT ARCS
            // =============================================
            CustomPaint(
              size: const Size(110, 110), // Tightened viewport dimension
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
    const double thickness = 10.0; // Sharp, aggressive profile thickness
    const int totalSegmentsPerSide = 12; // 12 on left, 12 on right

    // Paint Styles
    final emptyPaint = Paint()
      ..color = AppColors.glitchGrey.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;

    final filledPaint = Paint()
      ..color = AppColors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;

    final Rect arcBounds = Rect.fromCircle(center: center, radius: maxRadius);

    // Angular Constants (in Radians)
    const double totalHalfArcAngle = pi - (pi / 8); // Leaves a distinct top and bottom gap
    final double segmentAngle = totalHalfArcAngle / totalSegmentsPerSide;
    const double gapAngle = 0.045; // Clean, uniform gap spacing between segments
    final double activeDrawAngle = segmentAngle - gapAngle;

    // =============================================
    // DRAW LEFT ARC (REAL BATTERY % PROGRESS DECK)
    // =============================================
    // Calculates how many of the 12 left segments should turn cyan
    final int litSegmentsOnLeft = (totalSegmentsPerSide * percentage).round();

    for (int i = 0; i < totalSegmentsPerSide; i++) {
      // Calculate starting coordinate position for each individual chunk (growing down from top)
      final double startAngle = -pi / 2 - (i * segmentAngle) - segmentAngle + (gapAngle / 2);
      final bool isLit = i < litSegmentsOnLeft;

      canvas.drawArc(
        arcBounds,
        startAngle,
        activeDrawAngle,
        false,
        isLit ? filledPaint : emptyPaint,
      );
    }

    // =============================================
    // DRAW RIGHT ARC (BOTNET LOAD - FULLY ILLUMINATED)
    // =============================================
    for (int i = 0; i < totalSegmentsPerSide; i++) {
      // Mirror math tracing down the right side from top-center
      final double startAngle = -pi / 2 + (i * segmentAngle) + (gapAngle / 2);

      canvas.drawArc(
        arcBounds,
        startAngle,
        activeDrawAngle,
        false,
        filledPaint, // Keeping right side fully powered up for HUD balance
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BotnetArcPainter oldDelegate) => oldDelegate.percentage != percentage;
}