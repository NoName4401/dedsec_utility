import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart'; // Make sure this points to your dashboard

class BootSequenceScreen extends StatefulWidget {
  const BootSequenceScreen({super.key});

  @override
  State<BootSequenceScreen> createState() => _BootSequenceScreenState();
}

class _BootSequenceScreenState extends State<BootSequenceScreen> with SingleTickerProviderStateMixin {
  late AnimationController _wipeController;
  final List<String> _bootLogs = [];
  final ScrollController _scrollController = ScrollController();

  final List<String> _systemChecks = [
    "INIT SYSTEM // OS_VERSION 2.4.1",
    "MOUNTING SECURE VOLUMES...",
    "SUCCESS : /dev/sda1 MOUNTED",
    "LOADING KERNEL MODULES...",
    "BYPASSING ROOTSEC...",
    "OVERRIDING LOCAL TCP/IP STACK...",
    "INITIALIZING BLE RADAR ARRAYS...",
    "SECURE UPLINK ESTABLISHED.",
    " ",
    "WELCOME, GABRIEL."
  ];

  @override
  void initState() {
    super.initState();

    // Controls the diagonal skull wipe speed
    _wipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _runBootSequence();
  }

  Future<void> _runBootSequence() async {
    // 1. Trigger the skull swarm wipe
    _wipeController.forward();

    // 2. Rapid-fire the boot logs
    for (String log in _systemChecks) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) {
        setState(() {
          _bootLogs.add(log);
        });
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent + 50);
      }
    }

    // 3. Hold on the final screen for half a second, then route to Dashboard
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const DashboardScreen(),
          // Glitch fade transition to the dashboard
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeInCirc).animate(animation),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  void dispose() {
    _wipeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The background boot text
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _bootLogs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      _bootLogs[index],
                      style: AppText.label.copyWith(
                        color: index == _systemChecks.length - 1
                            ? AppColors.hazard // Highlights "WELCOME"
                            : AppColors.cyan,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // The animated ASCII Skull swarm
          AnimatedBuilder(
            animation: _wipeController,
            builder: (context, child) {
              return CustomPaint(
                painter: _AsciiSkullWipePainter(progress: _wipeController.value),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Custom GPU-accelerated painter that draws a massive grid of ASCII skulls
/// and translates them diagonally across the screen based on the animation progress.
class _AsciiSkullWipePainter extends CustomPainter {
  final double progress;
  _AsciiSkullWipePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0 || progress == 1) return; // Hide when not animating

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // The ASCII skull string
    const skull = " [☠] ";

    // Set the styling for the swarm
    textPainter.text = TextSpan(
      text: skull,
      style: TextStyle(
        color: AppColors.cyan.withOpacity(0.15),
        fontFamily: 'monospace',
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();

    final skullWidth = textPainter.width;
    final skullHeight = textPainter.height;

    // Calculate total movement distance (bottom right to top left)
    final startOffset = Offset(size.width, size.height);
    final endOffset = Offset(-size.width, -size.height);

    final currentTranslation = Offset.lerp(startOffset, endOffset, progress)!;

    canvas.save();
    // Move the entire canvas diagonally
    canvas.translate(currentTranslation.dx, currentTranslation.dy);

    // Draw a massive 3x3 screen-sized grid of skulls to ensure it covers the wipe
    for (double y = -size.height; y < size.height * 2; y += skullHeight) {
      for (double x = -size.width; x < size.width * 2; x += skullWidth) {
        textPainter.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AsciiSkullWipePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}