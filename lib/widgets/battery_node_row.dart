import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Renders the 10-node "botnet battery" array. [litNodes] in range 0-10.
class BatteryNodeRow extends StatelessWidget {
  final int litNodes;
  const BatteryNodeRow({super.key, required this.litNodes});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(10, (i) {
        final lit = i < litNodes;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: lit ? AppColors.cyan : AppColors.nodeEmpty,
              border: Border.all(
                color: lit ? AppColors.cyan : AppColors.glitchGrey,
                width: 1.2,
              ),
              boxShadow: lit
                  ? [
                      BoxShadow(
                        color: AppColors.cyan.withOpacity(0.65),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}
