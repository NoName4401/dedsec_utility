import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DashboardTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const DashboardTile({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // 🟢 FIXED: utilizing the new procedural asymmetric borders
        decoration: hudPanelDecoration(borderColor: accent, opacity: 0.7, glitchOffset: 2.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              color: accent, 
              size: 38,
              shadows: [
                Shadow(color: accent.withOpacity(0.8), blurRadius: 10),
              ]
            ),
            const SizedBox(height: 14),
            Text(label.toUpperCase(), style: AppText.label.copyWith(color: accent)),
          ],
        ),
      ),
    );
  }
}