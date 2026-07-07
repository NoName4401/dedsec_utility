import 'dart:async';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';

class RadarBlip {
  final String deviceName;
  final String hardwareId;
  final double angle;
  final int rssi;
  final double distanceEstimate;
  final String profileOccupation;
  final String profileFact;

  const RadarBlip({
    required this.deviceName,
    required this.hardwareId,
    required this.angle,
    required this.rssi,
    required this.distanceEstimate,
    required this.profileOccupation,
    required this.profileFact,
  });
}

class BleRadarService {
  final _rand = Random();
  final Map<String, double> _stableAngles = {};
  StreamSubscription<List<ScanResult>>? _sub;

  // Fictional databases to profile real passing signals
  final List<String> _mockOccupations = [
    'Bio-Hacker', 'Core Systems Analyst', 'Undergraduate Student',
    'Network Penetration Tester', 'Hardware Engineer', 'Cryptocurrency Broker'
  ];

  /// Listens to the raw magnetometer sensor and calculates heading direction in radians
  double _lastHeading = 0.0;

  /// Listens to the magnetometer and applies a low-pass filter to eliminate lag
  Stream<double> get compassStream {
    return magnetometerEventStream().map((MagnetometerEvent event) {
      double rawHeading = atan2(event.y, event.x);
      if (rawHeading < 0) rawHeading += 2 * pi;

      // Low-Pass Filter: Blends 15% of the new angle with 85% of the previous position
      // This eliminates rapid sensor jitter while keeping tracking completely active
      double diff = rawHeading - _lastHeading;

      // Handle the 0 -> 2*pi boundary wrap-around mathematically
      if (diff < -pi) diff += 2 * pi;
      if (diff > pi) diff -= 2 * pi;

      _lastHeading += diff * 0.15;
      return _lastHeading;
    });
  }

  final List<String> _mockFacts = [
    'Searched \'How to wipe ctOS log tracks\' 8 times today.',
    'Currently running an unencrypted SSH terminal stream.',
    'Maintains a total reliance on smart wearables.',
    'Thinks HTML configuration files count as core cyberware.',
  ];

  Future<bool> ensureReady() async {
    if (await FlutterBluePlus.isSupported == false) return false;
    final adapterState = await FlutterBluePlus.adapterState.first;
    return adapterState == BluetoothAdapterState.on;
  }

  Stream<List<RadarBlip>> radarStream() {
    final controller = StreamController<List<RadarBlip>>.broadcast();

    FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 45),
      androidScanMode: AndroidScanMode.lowLatency,
    );

    _sub = FlutterBluePlus.scanResults.listen((results) {
      final blips = <RadarBlip>[];
      for (final r in results) {
        final idString = r.device.remoteId.str;
        final rawName = r.device.platformName;
        final cleanName = rawName.isEmpty ? 'UNKNOWN_TARGET' : rawName.toUpperCase();

        // Pin an angle based on the identifier so it doesn't spin wildly
        final angle = _stableAngles.putIfAbsent(
          idString,
              () => _rand.nextDouble() * 2 * pi,
        );

        final rssi = r.rssi;
        final metricIndex = idString.hashCode.abs();

        blips.add(RadarBlip(
          deviceName: cleanName,
          hardwareId: idString,
          angle: angle,
          rssi: rssi,
          distanceEstimate: _estimateDistance(rssi),
          profileOccupation: _mockOccupations[metricIndex % _mockOccupations.length],
          profileFact: _mockFacts[metricIndex % _mockFacts.length],
        ));
      }
      controller.add(blips);
    });

    controller.onCancel = () {
      _sub?.cancel();
      FlutterBluePlus.stopScan();
      _stableAngles.clear();
    };

    return controller.stream;
  }

  double _estimateDistance(int rssi) {
    const txPower = -59;
    if (rssi == 0) return -1.0;
    final ratio = (txPower - rssi) / (10 * 2.0);
    return pow(10, ratio).toDouble();
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await FlutterBluePlus.stopScan();
    _stableAngles.clear();
  }
}