import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';
import '../models/wardrive_target.dart';

/// 802.11 spectrum reconnaissance engine.
/// Performs active RF sweeps of the local Wi-Fi environment and yields
/// raw access-point signatures for the wardriving display layer.
class WifiScannerService {
  static const _channel = MethodChannel('dedsec/wifi_permissions');
  Timer? _sweepTimer;

  /// Request fine-location permission required for Wi-Fi scanning on Android 10+.
  /// Returns true if permission was granted or already held.
  Future<bool> requestPermissions() async {
    var status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      status = await Permission.locationWhenInUse.request();
    }
    if (status.isGranted) return true;

    try {
      final result = await _channel.invokeMethod<bool>('requestFineLocation');
      return result ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Check if the device Wi-Fi hardware supports scanning.
  Future<bool> canScan() async {
    return await WiFiScan.instance.canStartScan() == CanStartScan.yes;
  }

  /// Get the most recent scan results and convert to WardriveTarget objects.
  Future<List<WardriveTarget>> getScanResults() async {
    final results = await WiFiScan.instance.getScannedResults();
    return results.map(_convertAccessPoint).toList();
  }

  /// Start a continuous RF sweep. Calls [onResults] each time new data arrives.
  void startSweep({
    required void Function(List<WardriveTarget> targets) onResults,
    Duration interval = const Duration(seconds: 4),
  }) {
    _sweepTimer?.cancel();

    // Trigger immediate first sweep
    getScanResults().then(onResults).catchError((_) {});

    _sweepTimer = Timer.periodic(interval, (_) async {
      try {
        final targets = await getScanResults();
        onResults(targets);
      } catch (_) {}
    });
  }

  /// Stop the continuous RF sweep.
  void stopSweep() {
    _sweepTimer?.cancel();
    _sweepTimer = null;
  }

  /// Convert raw WiFiScan access point into our tactical model.
  WardriveTarget _convertAccessPoint(WiFiAccessPoint ap) {
    return WardriveTarget(
      ssid: ap.ssid.isEmpty ? '[HIDDEN SSID]' : ap.ssid,
      bssid: ap.bssid,
      rssi: ap.level,
      frequency: ap.frequency,
      channel: _frequencyToChannel(ap.frequency),
      capabilities: ap.capabilities,
    );
  }

  /// Convert raw 802.11 frequency in MHz to channel number.
  int _frequencyToChannel(int freqMhz) {
    if (freqMhz >= 2412 && freqMhz <= 2484) {
      if (freqMhz == 2484) return 14;
      return ((freqMhz - 2412) / 5).round() + 1;
    }
    if (freqMhz >= 5170 && freqMhz <= 5825) {
      return ((freqMhz - 5035) / 5).round();
    }
    if (freqMhz >= 5955 && freqMhz <= 7115) {
      return ((freqMhz - 5955) / 5).round() + 1;
    }
    return 0;
  }
}
