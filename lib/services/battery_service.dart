import 'dart:async';
import 'package:battery_plus/battery_plus.dart';

/// CORE_MODULE_01 - "BOTNET" BATTERY SYNC
/// Maps the real hardware battery level to a 0-10 node index.
class BatteryService {
  final Battery _battery = Battery();

  Stream<int> nodeLevelStream() async* {
    final level = await _battery.batteryLevel;
    yield _toNodes(level);
    yield* _battery.onBatteryStateChanged.asyncMap((_) async {
      final lvl = await _battery.batteryLevel;
      return _toNodes(lvl);
    });
  }

  Future<int> currentNodes() async {
    final level = await _battery.batteryLevel;
    return _toNodes(level);
  }

  int _toNodes(int percent) {
    // 0-100% -> 0-10 nodes, rounded to nearest node.
    return (percent / 10).round().clamp(0, 10);
  }
}
