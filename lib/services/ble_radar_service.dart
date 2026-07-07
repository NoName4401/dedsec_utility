import 'dart:async';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// =======================================================================
/// FEATURE_SLOT_04 :: BLE SIGNAL RADAR
/// =======================================================================
/// This is the code behind the 4th dashboard tile. If you want to swap in
/// a different feature later, this file + radar_screen.dart + the tile
/// entry in dashboard_screen.dart (search "FEATURE_SLOT_04") are the only
/// three places you need to touch.
///
/// DESIGN CONSTRAINT -- READ BEFORE MODIFYING:
/// This module intentionally does NOT capture, display, log, or persist
/// any device identity (no MAC/remoteId, no device name, no manufacturer
/// data, no historical location trail). It only ever surfaces an
/// anonymous, ephemeral RSSI blip that disappears once the device is out
/// of range. A per-frame in-memory key is used purely to keep a blip's
/// on-screen angle from jumping around between scan callbacks in the same
/// session -- that key is never written to disk, never shown in the UI,
/// and is discarded the moment the radar screen closes. Do not extend
/// this module to surface identifiers, RSSI history, or profiles tied to
/// a device -- that turns it back into the tracking tool this project
/// deliberately avoids.
/// =======================================================================

class RadarBlip {
  final double angle; // radians, stable for the session only
  final int rssi;
  final double distanceEstimate; // rough meters, for display only
  const RadarBlip({required this.angle, required this.rssi, required this.distanceEstimate});
}

class BleRadarService {
  final _rand = Random();
  // Session-only, in-memory angle assignment. Cleared in dispose().
  // Keyed by a transient scan-local hash, never persisted or displayed.
  final Map<int, double> _sessionAngles = {};
  StreamSubscription<List<ScanResult>>? _sub;

  Future<bool> ensureReady() async {
    if (await FlutterBluePlus.isSupported == false) return false;
    final adapterState = await FlutterBluePlus.adapterState.first;
    return adapterState == BluetoothAdapterState.on;
  }

  Stream<List<RadarBlip>> radarStream() {
    final controller = StreamController<List<RadarBlip>>.broadcast();

    FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 30),
      androidScanMode: AndroidScanMode.lowLatency,
    );

    _sub = FlutterBluePlus.scanResults.listen((results) {
      final blips = <RadarBlip>[];
      for (final r in results) {
        // Ephemeral session key only -- NOT the real remoteId, NOT stored,
        // NOT surfaced. Just enough entropy to keep a blip's angle stable
        // while it's on screen this session.
        final sessionKey = r.device.remoteId.hashCode ^ DateTime.now().day;
        final angle = _sessionAngles.putIfAbsent(
          sessionKey,
          () => _rand.nextDouble() * 2 * pi,
        );
        final rssi = r.rssi;
        blips.add(RadarBlip(
          angle: angle,
          rssi: rssi,
          distanceEstimate: _estimateDistance(rssi),
        ));
      }
      controller.add(blips);
    });

    controller.onCancel = () {
      _sub?.cancel();
      FlutterBluePlus.stopScan();
      _sessionAngles.clear();
    };

    return controller.stream;
  }

  double _estimateDistance(int rssi) {
    // Rough free-space log-distance approximation for display flavor only.
    const txPower = -59; // assumed RSSI at 1m
    if (rssi == 0) return -1.0;
    final ratio = (txPower - rssi) / (10 * 2.0);
    return pow(10, ratio).toDouble();
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await FlutterBluePlus.stopScan();
    _sessionAngles.clear();
  }
}
