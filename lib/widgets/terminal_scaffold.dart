import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Full-screen "diagnostic terminal" chrome shared by every module screen.
/// Handles the optional background-image placeholder slot: if the asset
/// referenced by [backgroundAsset] isn't present in assets/images/, this
/// silently falls back to a plain gradient instead of crashing.
class TerminalScaffold extends StatelessWidget {
  final String title;
  final Color accent;
  final Widget child;
  final String? backgroundAsset;

  const TerminalScaffold({
    super.key,
    required this.title,
    required this.child,
    this.accent = AppColors.cyan,
    this.backgroundAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(title.toUpperCase(), style: AppText.title.copyWith(color: accent, fontSize: 16)),
        iconTheme: IconThemeData(color: accent),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: accent.withOpacity(0.6)),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _BackgroundSlot(assetPath: backgroundAsset),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class _BackgroundSlot extends StatelessWidget {
  final String? assetPath;
  const _BackgroundSlot({this.assetPath});

  @override
  Widget build(BuildContext context) {
    final gradient = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.background, Color(0xFF090909)],
        ),
      ),
    );
    if (assetPath == null) return gradient;
    return Image.asset(
      assetPath!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => gradient, // asset not dropped in yet
    );
  }
}

/// Scrolling monospace log panel used by every module's terminal output.
class TerminalLog extends StatelessWidget {
  final List<String> lines;
  final ScrollController controller;

  const TerminalLog({super.key, required this.lines, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: hudPanelDecoration(borderColor: AppColors.glitchGrey, glow: 0.1),
      padding: const EdgeInsets.all(10),
      child: ListView.builder(
        controller: controller,
        itemCount: lines.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Text(lines[i], style: AppText.body),
        ),
      ),
    );
  }
}

/// Angular action button styled like an in-terminal execute trigger.
class ExecuteButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color color;
  final bool busy;

  const ExecuteButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.cyan,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: busy
            ? SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Text('[ $label ]', style: AppText.label.copyWith(color: color)),
      ),
    );
  }
}
