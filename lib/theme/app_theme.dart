import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------
/// UPGRADED DEDSEC HIGH-FIDELITY HUD THEME
/// Implements procedural chromatic aberration, terminal overlays, 
/// and interactive configuration properties.
/// ---------------------------------------------------------------------
class AppColors {
  static const background = Color(0xFF090A0F);     // Deep terminal base
  static const surface = Color(0xFF14161D);        // Muted module surface
  static const cyan = Color(0xFF00FFCC);           // Neon Core Accent
  static const hazard = Color(0xFFFF5500);         // Cybernetic Warning Orange
  static const warningYellow = Color(0xFFFFEA00);   // Diagnostic Alert Yellow
  static const glitchGrey = Color(0xFF626875);     // Muted system matrix text
  static const nodeEmpty = Color(0xFF1E212A);      // Locked node mesh color
  static const chromaticRed = Color(0xFFFF2255);   // Split shadow offset color
}

class AppAssets {
  static const dashboardBackground = 'assets/images/dashboard_bg.png';
  static const terminalBackground = 'assets/images/terminal_bg.png';
  static const appIcon = 'assets/images/app_icon.png';
}

class AppText {
  static const _mono = 'monospace';

  /// Chromatic Aberration Text Shadow Matrix
  static const List<Shadow> dedsecGlow = [
    Shadow(color: AppColors.cyan, offset: Offset(-1.5, 1.0), blurRadius: 1.0),
    Shadow(color: AppColors.chromaticRed, offset: Offset(1.5, -1.0), blurRadius: 1.0),
  ];

  static const label = TextStyle(
    fontFamily: _mono,
    color: AppColors.cyan,
    fontSize: 13,
    letterSpacing: 1.5,
    fontWeight: FontWeight.w600,
    shadows: dedsecGlow,
  );

  static const body = TextStyle(
    fontFamily: _mono,
    color: Color(0xFFE5E9F0),
    fontSize: 13,
    height: 1.4,
    letterSpacing: 0.8,
  );

  static const dim = TextStyle(
    fontFamily: _mono,
    color: AppColors.glitchGrey,
    fontSize: 12,
    letterSpacing: 0.5,
  );

  static const hazardLabel = TextStyle(
    fontFamily: _mono,
    color: AppColors.hazard,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    shadows: [
      Shadow(color: AppColors.hazard, offset: Offset(-1.0, 1.0), blurRadius: 0.5),
      Shadow(color: AppColors.warningYellow, offset: Offset(1.0, -1.0), blurRadius: 0.5),
    ],
  );

  static const title = TextStyle(
    fontFamily: _mono,
    color: AppColors.cyan,
    fontSize: 22,
    fontWeight: FontWeight.bold,
    letterSpacing: 2.5,
    shadows: dedsecGlow,
  );
}

/// Sharp, asymmetric asymmetric panel decoration modeled directly from the visualizer.
/// Adds the sharp left cyan pillar block alongside a clean terminal opacity overlay.
BoxDecoration hudPanelDecoration({
  Color borderColor = AppColors.cyan, 
  double opacity = 0.85, 
  double glitchOffset = 2.0,
}) {
  return BoxDecoration(
    color: AppColors.surface.withOpacity(opacity),
    border: Border(
      left: BorderSide(color: borderColor, width: 3.5),
      bottom: BorderSide(color: AppColors.background, width: glitchOffset),
      top: const BorderSide(color: Colors.transparent, width: 0),
      right: const BorderSide(color: Colors.transparent, width: 0),
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.chromaticRed.withOpacity(0.15),
        offset: Offset(glitchOffset, -glitchOffset),
        blurRadius: 0,
      ),
      BoxShadow(
        color: AppColors.cyan.withOpacity(0.1),
        offset: Offset(-glitchOffset, glitchOffset),
        blurRadius: 4,
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
      error: AppColors.chromaticRed,
    ),
    useMaterial3: true,
  );
}