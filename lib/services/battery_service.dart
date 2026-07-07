import 'dart:async';
import 'package:battery_plus/battery_plus.dart';

class BatteryService {
  final _battery = Battery();

  /// Streams the phone's true physical hardware battery percentage (0.0 to 1.0)
  Stream<double> batteryLevelStream() {
    return Stream.periodic(const Duration(seconds: 2)).asyncMap((_) async {
      final level = await _battery.batteryLevel;
      return level / 100.0; // Converts integer percent (e.g. 84) to double fraction (0.84)
    });
  }
}
