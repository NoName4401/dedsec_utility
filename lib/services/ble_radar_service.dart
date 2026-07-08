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

  // Advanced Layer 7 Telemetry Fields
  final String vendor;
  final String deviceType;
  final String profileDesc;
  final String profileOccupation;
  final String profileFact;

  const RadarBlip({
    required this.deviceName,
    required this.hardwareId,
    required this.angle,
    required this.rssi,
    required this.distanceEstimate,
    required this.vendor,
    required this.deviceType,
    required this.profileDesc,
    required this.profileOccupation,
    required this.profileFact,
  });
}

class BleRadarService {
  final _rand = Random();
  final Map<String, double> _stableAngles = {};
  StreamSubscription<List<ScanResult>>? _sub;

  // Immersive DedSec Profile Database for Unknown Targets
  final List<String> _mockOccupations = [
    'Bio-Hacker', 'Core Systems Analyst', 'Undergraduate Student',
    'Network Penetration Tester', 'Hardware Engineer', 'Cryptocurrency Broker',
    'Security Consultant', 'Systems Architect', 'Data Broker'
  ];

  final List<String> _mockFacts = [
    'Searched \'How to wipe ctOS log tracks\' 8 times today.',
    'Currently running an unencrypted SSH terminal stream.',
    'Maintains a total reliance on smart wearables.',
    'Thinks HTML configuration files count as core cyberware.',
    'Local RF footprint flagged for unusual packet broadcasts.',
    'Device MAC cycling frequency exceeds standard OS parameters.'
  ];

  double _lastHeading = 0.0;

  /// Listens to the magnetometer and applies a low-pass filter to eliminate lag
  Stream<double> get compassStream {
    return magnetometerEventStream().map((MagnetometerEvent event) {
      double rawHeading = atan2(event.y, event.x);
      if (rawHeading < 0) rawHeading += 2 * pi;

      double diff = rawHeading - _lastHeading;

      if (diff < -pi) diff += 2 * pi;
      if (diff > pi) diff -= 2 * pi;

      _lastHeading += diff * 0.15;
      return _lastHeading;
    });
  }

  Future<bool> ensureReady() async {
    if (await FlutterBluePlus.isSupported == false) return false;
    final adapterState = await FlutterBluePlus.adapterState.first;
    return adapterState == BluetoothAdapterState.on;
  }

  Stream<List<RadarBlip>> radarStream() {
    final controller = StreamController<List<RadarBlip>>.broadcast();

    FlutterBluePlus.startScan(
      continuousUpdates: true,
      androidScanMode: AndroidScanMode.lowLatency,
    );

    _sub = FlutterBluePlus.scanResults.listen((results) {
      final blips = <RadarBlip>[];
      for (final r in results) {
        final idString = r.device.remoteId.str;

        // Android 14+ uses advertisementData.advName cleanly
        final rawName = r.device.advName.isEmpty ? r.device.platformName : r.device.advName;
        final cleanName = rawName.isEmpty ? 'UNKNOWN_TARGET' : rawName.toUpperCase();

        // Pin an angle based on the hardware ID so targets stay locked in space
        final angle = _stableAngles.putIfAbsent(
          idString,
              () => _rand.nextDouble() * 2 * pi,
        );

        final rssi = r.rssi;
        final metricIndex = idString.hashCode.abs();

        // Deep Packet Dissection
        final packetIntel = _dissectBlePacket(r);

        blips.add(RadarBlip(
          deviceName: cleanName,
          hardwareId: idString,
          angle: angle,
          rssi: rssi,
          distanceEstimate: _estimateDistance(rssi),
          vendor: packetIntel['vendor']!,
          deviceType: packetIntel['type']!,
          profileDesc: packetIntel['desc']!,
          // Use advanced info if unmasked, fallback to database if anonymous
          profileOccupation: packetIntel['vendor'] == 'UNKNOWN_MANUFACTURER'
              ? _mockOccupations[metricIndex % _mockOccupations.length]
              : _assignClassification(packetIntel['vendor']!),
          profileFact: packetIntel['vendor'] == 'UNKNOWN_MANUFACTURER'
              ? _mockFacts[metricIndex % _mockFacts.length]
              : _assignDossier(packetIntel['vendor']!),
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

  /// THE LAYER 7 PIVOT: MANUFACTURER DATA MATRIX
  Map<String, String> _dissectBlePacket(ScanResult result) {
    final mData = result.advertisementData.manufacturerData;
    final sUuids = result.advertisementData.serviceUuids.map((e) => e.toString().toUpperCase()).toList();

    String vendor = 'UNKNOWN_MANUFACTURER';
    String type = 'GENERIC BLE BEACON // PERIPHERAL ASSET';
    String desc = 'Broadcasting routine low-energy advertisements to announce geographical presence.';

    // 1. HARDWARE MANUFACTURER REGISTRY (Hex Matching)
    if (mData.containsKey(0x004C)) {
      vendor = 'APPLE INC.';
      type = 'APPLE ECOSYSTEM NODE // IOS HARDWARE';
      desc = 'Broadcasting proprietary iBeacon/Continuity payload. High probability of iPhone, AirPods, or an AirTag tracking node.';
    }
    else if (mData.containsKey(0x0075)) {
      vendor = 'SAMSUNG ELECTRONICS';
      type = 'SAMSUNG WEARABLE // GALAXY NODE';
      desc = 'Transmitting SmartThings or Galaxy Wearable telemetry. Active modern handset or smartwatch cluster close by.';
    }
    else if (mData.containsKey(0x0006)) {
      vendor = 'MICROSOFT CORP';
      type = 'WINDOWS WORKSTATION // SURFACE NODE';
      desc = 'Microsoft Swift Pair broadcast detected. Active Windows laptop or convertible searching for rapid peripheral link.';
    }
    else if (mData.containsKey(0x012D)) {
      vendor = 'SONY CORPORATION';
      type = 'ACOUSTIC TRANSDUCER // AUDIO NODE';
      desc = 'Sony high-fidelity wireless audio framework. Likely WH-1000XM series or WF audio node.';
    }
    else if (mData.containsKey(0x009E)) {
      vendor = 'BOSE CORPORATION';
      type = 'ACOUSTIC TRANSDUCER // AUDIO NODE';
      desc = 'Bose QuietComfort connection protocol detected. Active wireless noise-canceling accessory nearby.';
    }
    else if (mData.containsKey(0x015D)) {
      vendor = 'GARMIN INTERNATIONAL';
      type = 'BIOMETRIC SENSOR // FITNESS TRACKER';
      desc = 'Transmitting real-time health metrics, active GPS session fragments, and accelerometer vector matrices.';
    }
    else if (mData.containsKey(0x0312)) {
      vendor = 'TILE INC.';
      type = 'GEOLOCATION TRACKER // MESH NODE';
      desc = 'Tile tracking beacon actively pinging the surrounding environment to update its hardware grid context.';
    }

    // 2. PROTOCOL-BASED OVERRIDES (Service UUIDs)
    else if (sUuids.contains('0000FE9F-0000-1000-8000-00805F9B34FB') || mData.containsKey(0x00E0)) {
      vendor = 'GOOGLE / ALPHABET INC.';
      type = 'ANDROID FAST PAIR // PIXEL ECOSYSTEM';
      desc = 'Pinging Google Fast Pair Framework. High likelihood of a Pixel handset, Pixel Buds, or high-end Android wearable.';
    }
    else if (sUuids.contains('0000FE03-0000-1000-8000-00805F9B34FB')) {
      vendor = 'AMAZON.COM SERVICES LLC';
      type = 'ALEXA SMART NODE // SMART HOME HUB';
      desc = 'Amazon Sidewalk architecture beacon or active Echo peripheral looking for local setup mesh synchronization.';
    }

    // 3. FALLBACK CONTEXT-AWARE PARSING
    final cleanName = (result.advertisementData.advName.isEmpty ? result.device.platformName : result.advertisementData.advName).toUpperCase();
    if (vendor == 'UNKNOWN_MANUFACTURER' && cleanName.isNotEmpty) {
      if (cleanName.contains('TV') || cleanName.contains('CHROMECAST') || cleanName.contains('ROKU') || cleanName.contains('FIRE_STICK')) {
        vendor = 'SMART MEDIA VENDOR';
        type = 'MULTIMEDIA RENDERING NODE // SMART TV';
        desc = 'Open smart television pairing system broadcasting visibility metrics to accommodate discovery layers.';
      } else if (cleanName.contains('WATCH') || cleanName.contains('BAND') || cleanName.contains('FITBIT')) {
        vendor = 'WEARABLE VENDOR';
        type = 'SMARTWEARABLE // FITNESS TRACKER';
        desc = 'Exchanging structural notification push relays or telemetry data packets with a parent cell node.';
      }
    }

    return {'vendor': vendor, 'type': type, 'desc': desc};
  }

  String _assignClassification(String vendor) {
    if (vendor == 'APPLE INC.' || vendor == 'SAMSUNG ELECTRONICS' || vendor == 'GOOGLE / ALPHABET INC.') return 'CIVILIAN HANDSET / WEARABLE';
    if (vendor == 'MICROSOFT CORP') return 'ENTERPRISE WORKSTATION';
    if (vendor == 'GARMIN INTERNATIONAL') return 'ATHLETIC TRACKING NODE';
    if (vendor == 'SONY CORPORATION' || vendor == 'BOSE CORPORATION') return 'PERSONAL AUDIO ASSET';
    return 'UNIDENTIFIED COMMERCIAL HARDWARE';
  }

  String _assignDossier(String vendor) {
    if (vendor == 'APPLE INC.') return 'Heavy usage profile within locked proprietary software environments.';
    if (vendor == 'SAMSUNG ELECTRONICS') return 'Device telemetry shows persistent syncing updates with Android Wear infrastructure.';
    if (vendor == 'GOOGLE / ALPHABET INC.') return 'High-frequency location indexing and account validation handshakes observed.';
    if (vendor == 'GARMIN INTERNATIONAL') return 'Compiling high-resolution telemetry, altitude tracks, and biometrics.';
    if (vendor == 'MICROSOFT CORP') return 'Active corporate environment profile. Running structural OS execution lanes.';
    return 'Encrypted proprietary beacon payload. Underlying user data layer obfuscated.';
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