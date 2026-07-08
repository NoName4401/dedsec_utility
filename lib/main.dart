import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/boot_screen.dart'; // Import the new boot screen

void main() {
  runApp(const ProjectMarcusApp());
}

class ProjectMarcusApp extends StatelessWidget {
  const ProjectMarcusApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject custom page transitions into your existing theme
    final baseTheme = buildAppTheme();
    final hackerTheme = baseTheme.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          // Kills the standard Android swipe-in, replacing it with an instant, fadeless cut
          // which perfectly mimics old terminal software routing.
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );

    return MaterialApp(
      title: 'DedSec HUD',
      debugShowCheckedModeBanner: false,
      theme: hackerTheme,
      // 🟢 Set the home screen to the Boot Sequence instead of the Dashboard
      home: const BootSequenceScreen(),
    );
  }
}