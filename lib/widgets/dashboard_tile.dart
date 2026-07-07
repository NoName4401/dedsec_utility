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
    required this.onTap,
    this.accent = AppColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: hudPanelDecoration(borderColor: accent, glow: 0.25),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: accent, size: 30),
            const SizedBox(height: 10),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppText.label.copyWith(color: accent),
            ),
          ],
        ),
      ),
    );
  }
}
