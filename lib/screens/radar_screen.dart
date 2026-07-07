import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/ble_radar_service.dart';
import '../widgets/terminal_scaffold.dart';

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
  RadarBlip? _selectedBlip;
  double _currentHeading = 0.0;

  @override
  void initState() {
    super.initState();
  }

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

    _radarService.compassStream.listen((heading) {
      if (mounted) {
        setState(() => _currentHeading = heading);
      }
    });

    _radarService.radarStream().listen((blips) {
      if (mounted) {
        setState(() {
          _blips = List.from(blips)..sort((a, b) => b.rssi.compareTo(a.rssi));
          if (_selectedBlip != null) {
            final match = _blips.indexWhere((b) => b.hardwareId == _selectedBlip!.hardwareId);
            if (match != -1) _selectedBlip = _blips[match];
          }
        });
      }
    });
  }

  Future<void> _stop() async {
    await _radarService.dispose();
    setState(() {
      _active = false;
      _blips = [];
      _selectedBlip = null;
      _status = 'RADAR_IDLE';
    });
  }

  @override
  void dispose() {
    _radarService.dispose();
    super.dispose();
  }

  /// Real-world device analytics mapper
  Map<String, String> _resolveDeviceMetrics(String name, String hardwareId) {
    final cleanName = name.toUpperCase();
    if (cleanName.contains('WATCH') || cleanName.contains('LE_')) {
      return {
        'type': 'SMARTWEARABLE // FITNESS TRACKER',
        'desc': 'Exchanges real-time biometric telemetry, notification relays, and motion data matrices with a parent handset.',
      };
    } else if (cleanName.contains('TV') || cleanName.contains('CHROMECAST') || cleanName.contains('ROKU')) {
      return {
        'type': 'MULTIMEDIA RENDERING NODE // SMART TV',
        'desc': 'Constantly broadcasts open Bluetooth pairing beacons to handle remote control inputs and media casting requests.',
      };
    } else if (cleanName.contains('AUDIO') || cleanName.contains('BUDS') || cleanName.contains('BOSE') || cleanName.contains('SONOS')) {
      return {
        'type': 'ACOUSTIC TRANSDUCER // WIRELESS AUDIO',
        'desc': 'Utilizes high-bandwidth audio protocols to stream synchronized sound streams. Susceptible to ambient signal capture.',
      };
    } else {
      return {
        'type': 'GENERIC BLE BEACON // PERIPHERAL ASSET',
        'desc': 'Broadcasting routine low-energy advertisements to announce geographical presence and connection availability checkpoints.',
      };
    }
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
            const SizedBox(height: 12),

            // ISOLATED, HIGH-PERFORMANCE RADAR CANVAS
            SizedBox(
              height: 220,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _RadarVisualizer(
                    blips: _blips,
                    heading: _currentHeading,
                    selectedBlip: _selectedBlip,
                    onBlipSelected: (blip) {
                      setState(() => _selectedBlip = blip);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // TARGET PROFILE CARDS DECK (Now completely uncoupled from compass lag)
            Expanded(
              child: _blips.isEmpty
                  ? Center(child: Text('NO_BEACONS_DETECTED', style: AppText.dim))
                  : ListView.builder(
                itemCount: _blips.length,
                itemBuilder: (context, index) {
                  final blip = _blips[index];
                  final isSelected = _selectedBlip?.hardwareId == blip.hardwareId;
                  final specs = _resolveDeviceMetrics(blip.deviceName, blip.hardwareId);

                  return GestureDetector(
                    onTap: () => setState(() => _selectedBlip = blip),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: hudPanelDecoration(
                          borderColor: isSelected ? AppColors.hazard : AppColors.warningYellow,
                          opacity: isSelected ? 0.35 : 0.10,
                          glitchOffset: isSelected ? 3.0 : 1.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  blip.deviceName == 'UNKNOWN_TARGET' ? 'UNIDENTIFIED BEACON' : blip.deviceName,
                                  style: AppText.label.copyWith(color: AppColors.warningYellow, overflow: TextOverflow.ellipsis),
                                ),
                              ),
                              Text('PROXIMITY: ~${blip.distanceEstimate.toStringAsFixed(1)}M',
                                  style: AppText.label.copyWith(fontSize: 11, color: AppColors.cyan)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('HARDWARE ID: ${blip.hardwareId} [${blip.rssi} dBm]', style: AppText.dim.copyWith(fontSize: 10)),
                          const SizedBox(height: 4),

                          // Real Tech Specs Readouts
                          Text('DEVICE TYPE: ${specs['type']}', style: AppText.label.copyWith(fontSize: 11, color: Colors.white70)),
                          const SizedBox(height: 2),
                          Text('OPERATIONAL PROFILE: ${specs['desc']}', style: AppText.dim.copyWith(fontSize: 11, height: 1.2)),

                          if (isSelected) ...[
                            const Divider(color: AppColors.glitchGrey, height: 16),
                            Text('CLASSIFICATION: ${blip.profileOccupation.toUpperCase()}', style: AppText.label),
                            const SizedBox(height: 2),
                            Text('DOSSIER INTERCEPT: ${blip.profileFact}', style: AppText.dim.copyWith(color: AppColors.cyan)),
                          ]
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Isolated widget separating heavy rendering trees from rapid hardware updates
class _RadarVisualizer extends StatelessWidget {
  final List<RadarBlip> blips;
  final double heading;
  final RadarBlip? selectedBlip;
  final ValueChanged<RadarBlip?> onBlipSelected;

  const _RadarVisualizer({
    required this.blips,
    required this.heading,
    required this.selectedBlip,
    required this.onBlipSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxRadius = constraints.maxWidth / 2;
        final Offset center = Offset(maxRadius, maxRadius);

        return GestureDetector(
          onTapDown: (details) => _processRadarTap(details.localPosition, center, maxRadius),
          child: Stack(
            children: [
              // 1. Static Layer
              Positioned.fill(
                child: CustomPaint(painter: _StaticRadarScopePainter()),
              ),
              // 2. Rotating Target Layer (Isolated and hardware accelerated)
              Positioned.fill(
                child: RepaintBoundary(
                  child: Transform.rotate(
                    angle: -heading,
                    alignment: Alignment.center,
                    child: CustomPaint(
                      painter: _RotatingTargetPainter(
                        blips: blips,
                        selected: selectedBlip,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _processRadarTap(Offset tapPos, Offset center, double maxRadius) {
    if (blips.isEmpty) return;

    RadarBlip? closestBlip;
    double closestDistance = 24.0; // Responsive touch targeting window

    for (final blip in blips) {
      // Correct for rotation offset dynamically to make canvas coordinates match screenspace
      final adjustedAngle = blip.angle - heading;
      final normalizedDistance = (blip.distanceEstimate.clamp(0.2, 20) / 20).toDouble();
      final r = maxRadius * normalizedDistance;

      final bx = center.dx + r * cos(adjustedAngle);
      final by = center.dy + r * sin(adjustedAngle);

      final distance = sqrt(pow(tapPos.dx - bx, 2) + pow(tapPos.dy - by, 2));
      if (distance < closestDistance) {
        closestDistance = distance;
        closestBlip = blip;
      }
    }

    if (closestBlip != null) {
      onBlipSelected(closestBlip);
    }
  }
}

class _StaticRadarScopePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;

    final ringPaint = Paint()
      ..color = AppColors.glitchGrey.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxRadius * i / 4, ringPaint);
    }

    final crossPaint = Paint()
      ..color = AppColors.glitchGrey.withOpacity(0.25)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), crossPaint);
    canvas.drawLine(center, Offset(center.dx, 0), Paint()..color = AppColors.cyan.withOpacity(0.2)..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _StaticRadarScopePainter oldDelegate) => false;
}

class _RotatingTargetPainter extends CustomPainter {
  final List<RadarBlip> blips;
  final RadarBlip? selected;

  _RotatingTargetPainter({required this.blips, this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;

    // Draw a prominent North Node marker on the rotating outer edge
    final northPaint = Paint()..color = AppColors.cyan..style = PaintingStyle.fill;
    const double northAngle = -pi / 2;
    final Offset northTip = Offset(center.dx + maxRadius * cos(northAngle), center.dy + maxRadius * sin(northAngle));

    canvas.drawCircle(northTip, 4, northPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(color: AppColors.cyan, fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(northTip.dx - 3, northTip.dy + 4));

    // Plot target blips using stable angles
    for (final blip in blips) {
      final normalizedDistance = (blip.distanceEstimate.clamp(0.2, 20) / 20).toDouble();
      final r = maxRadius * normalizedDistance;
      final dx = center.dx + r * cos(blip.angle);
      final dy = center.dy + r * sin(blip.angle);

      final isSelected = selected?.hardwareId == blip.hardwareId;
      final strength = ((blip.rssi + 100) / 70).clamp(0.15, 1.0);

      final blipPaint = Paint()
        ..color = (isSelected ? AppColors.hazard : AppColors.warningYellow).withOpacity(strength)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(dx, dy), isSelected ? 7 : 5, blipPaint);

      if (isSelected) {
        canvas.drawCircle(
          Offset(dx, dy),
          12,
          Paint()
            ..color = AppColors.hazard.withOpacity(0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RotatingTargetPainter oldDelegate) => true;
}