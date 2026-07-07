import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------
/// ORIGINAL DedSec-INSPIRED THEME
/// Colors/typography evoke the aesthetic; no game assets are used.
/// Drop your own background art into assets/images/ (see README) and
/// reference it via AppAssets below once you've added files there.
/// ---------------------------------------------------------------------
class AppColors {
  static const background = Color(0xFF0B0B0B);
  static const surface = Color(0xFF121212);
  static const cyan = Color(0xFF00E5FF);
  static const hazard = Color(0xFFFF3D00);
  static const warningYellow = Color(0xFFFFEA00);
  static const glitchGrey = Color(0xFF424242);
  static const nodeEmpty = Color(0xFF1E1E1E);
}

class AppAssets {
  // PLACEHOLDER SLOTS -----------------------------------------------------
  // Drop your own images into assets/images/ with these exact filenames
  // (or change the paths below) to have them show up as backgrounds.
  // If a file is missing, the UI falls back to a solid/gradient background
  // automatically -- see BackgroundSlot widget.
  static const dashboardBackground = 'assets/images/dashboard_bg.png';
  static const terminalBackground = 'assets/images/terminal_bg.png';
  static const appIcon = 'assets/images/app_icon.png';
}

class AppText {
  static const _mono = 'monospace'; // swap for a bundled font if you add one

  static const label = TextStyle(
    fontFamily: _mono,
    color: AppColors.cyan,
    fontSize: 13,
    letterSpacing: 1.5,
    fontWeight: FontWeight.w600,
  );

  static const body = TextStyle(
    fontFamily: _mono,
    color: Color(0xFFD0F5FF),
    fontSize: 13,
    height: 1.4,
  );

  static const dim = TextStyle(
    fontFamily: _mono,
    color: AppColors.glitchGrey,
    fontSize: 12,
  );

  static const hazardLabel = TextStyle(
    fontFamily: _mono,
    color: AppColors.hazard,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  static const title = TextStyle(
    fontFamily: _mono,
    color: AppColors.cyan,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.0,
  );
}

/// Sharp, angular panel decoration used across every screen.
BoxDecoration hudPanelDecoration({Color borderColor = AppColors.cyan, double glow = 0.35}) {
  return BoxDecoration(
    color: AppColors.surface,
    border: Border.all(color: borderColor, width: 1.4),
    borderRadius: BorderRadius.circular(2),
    boxShadow: [
      BoxShadow(
        color: borderColor.withOpacity(glow),
        blurRadius: 14,
        spreadRadius: 0.5,
      ),
    ],
  );
}

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'monospace',
    colorScheme: const ColorScheme.dark(
      primary: AppColors.cyan,
      secondary: AppColors.hazard,
      surface: AppColors.surface,
    ),
    useMaterial3: true,
  );
}
