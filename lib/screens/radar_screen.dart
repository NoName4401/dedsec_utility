import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/ble_radar_service.dart';
import '../widgets/terminal_scaffold.dart';

/// =======================================================================
/// FEATURE_SLOT_04 :: RadarScreen
/// =======================================================================
/// UI half of the 4th dashboard tile. Pairs with services/ble_radar_service.dart.
/// Deliberately shows RSSI-based blips only -- no MAC/name/identifier is
/// ever rendered here. Read the design-constraint comment in
/// ble_radar_service.dart before adding fields to this screen.
/// =======================================================================
class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  final _radarService = BleRadarService();
  List<RadarBlip> _blips = [];
  bool _active = false;
  String _status = 'RADAR_IDLE';

  Future<void> _start() async {
    final ready = await _radarService.ensureReady();
    if (!ready) {
      setState(() => _status = 'BLUETOOTH_UNAVAILABLE_OR_OFF');
      return;
    }
    setState(() {
      _active = true;
      _status = 'SCANNING_LOCAL_RF_SPACE...';
    });
    _radarService.radarStream().listen((blips) {
      if (mounted) setState(() => _blips = blips);
    });
  }

  Future<void> _stop() async {
    await _radarService.dispose();
    setState(() {
      _active = false;
      _blips = [];
      _status = 'RADAR_IDLE';
    });
  }

  @override
  void dispose() {
    _radarService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TerminalScaffold(
      title: 'Radar // BLE Signal Field',
      accent: AppColors.warningYellow,
      backgroundAsset: AppAssets.terminalBackground,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            ExecuteButton(
              label: _active ? 'STOP_RADAR' : 'INITIALIZE_RADAR',
              color: AppColors.warningYellow,
              onPressed: _active ? _stop : _start,
            ),
            const SizedBox(height: 8),
            Text(_status, style: AppText.dim),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CustomPaint(
                    painter: _RadarPainter(blips: _blips),
                    child: Container(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ANONYMOUS_RSSI_BLIPS :: ${_blips.length} IN_RANGE\n'
              'NO_IDENTIFIERS_CAPTURED_OR_STORED',
              textAlign: TextAlign.center,
              style: AppText.dim,
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<RadarBlip> blips;
  _RadarPainter({required this.blips});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;

    final ringPaint = Paint()
      ..color = AppColors.glitchGrey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxRadius * i / 4, ringPaint);
    }

    final crossPaint = Paint()
      ..color = AppColors.glitchGrey
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), crossPaint);

    for (final blip in blips) {
      // Closer (stronger RSSI, less negative) -> nearer to center.
      final normalizedDistance =
          (blip.distanceEstimate.clamp(0.2, 20) / 20).toDouble();
      final r = maxRadius * normalizedDistance;
      final dx = center.dx + r * cos(blip.angle);
      final dy = center.dy + r * sin(blip.angle);

      final strength = ((blip.rssi + 100) / 70).clamp(0.15, 1.0);
      final blipPaint = Paint()
        ..color = AppColors.warningYellow.withOpacity(strength)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(dx, dy), 6, blipPaint);
      canvas.drawCircle(
        Offset(dx, dy),
        10,
        Paint()
          ..color = AppColors.warningYellow.withOpacity(strength * 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Center node.
    canvas.drawCircle(
      center,
      5,
      Paint()..color = AppColors.cyan,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}
