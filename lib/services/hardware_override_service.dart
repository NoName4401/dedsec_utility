import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';
import '../models/iot_target.dart';
import 'chromecast_service.dart';
import 'lg_webos_service.dart';
import 'samsung_service.dart';
import 'sony_service.dart';
import 'android_tv_pairing_manager.dart';

class ProbeEntry {
  final int port;
  final bool open;
  final String? banner;
  const ProbeEntry(this.port, this.open, this.banner);
}

class OverrideCommandResult {
  final String action;
  final String vendor;
  final String endpoint;
  final bool success;
  final String detail;
  const OverrideCommandResult(this.action, this.vendor, this.endpoint, this.success, this.detail);
}

class HardwareOverrideService {
  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;
  void _log(String msg) => _logController.add(msg);

  final _chromecast = ChromecastService();
  final _lgWebos = LgWebosService();
  final _samsung = SamsungService();
  final _sony = SonyService();
  final _secureStorage = FlutterSecureStorage();
  final _atvManagers = <String, AndroidTvPairingManager>{};

  static const vendorActions = {
    'Roku': ['PowerOff', 'VolumeUp', 'VolumeDown', 'Mute', 'Home', 'Back', 'Play', 'Search', 'Up', 'Down', 'Left', 'Right', 'Select'],
    'Chromecast': ['PowerOff', 'PlayPause', 'VolumeUp', 'VolumeDown', 'Mute', 'Stop', 'Up', 'Down', 'Left', 'Right', 'Select'],
    'Samsung': ['PowerOff', 'VolumeUp', 'VolumeDown', 'Mute', 'Source', 'Home', 'Up', 'Down', 'Left', 'Right', 'Select'],
    'LG': ['PowerOff', 'VolumeUp', 'VolumeDown', 'Mute', 'Home', 'Back', 'Up', 'Down', 'Left', 'Right', 'Select'],
    'Sony': ['PowerOff', 'VolumeUp', 'VolumeDown', 'Mute', 'Home'],
    'Android TV': ['PowerOff', 'VolumeUp', 'VolumeDown', 'Mute', 'Home', 'Back', 'Up', 'Down', 'Left', 'Right', 'Select'],
  };

  static const _vendorPorts = {
    'Roku': [8060],
    'Chromecast': [8008, 8009, 6466],
    'Samsung': [9197, 8001, 8002],
    'LG': [3000, 8080, 80],
    'Sony': [10080, 50252],
    'Android TV': [6466, 6467, 5555],
  };

  List<String> availableActions(String vendor) =>
      vendorActions[vendor] ?? ['PowerOff', 'VolumeUp', 'VolumeDown'];

  bool isDpadSupported(String vendor) => true;

  Future<List<ProbeEntry>> probeTarget(String ip, String vendor) async {
    final ports = _vendorPorts[vendor] ?? [80, 443, 8060, 8080, 8008, 9197, 10080, 3000];
    final results = <ProbeEntry>[];

    for (final port in ports) {
      try {
        final socket = await Socket.connect(ip, port,
            timeout: const Duration(seconds: 2));
        await socket.close();
        results.add(ProbeEntry(port, true, null));
      } on SocketException {
        results.add(ProbeEntry(port, false, null));
      } on TimeoutException {
        results.add(ProbeEntry(port, false, 'timeout'));
      }
    }
    return results;
  }

  Stream<IotTarget> discoverLanTargets() async* {
    final mdns = MDnsClient();
    await mdns.start();

    final serviceTypes = [
      '_roku-ecp._tcp.local',
      '_googlecast._tcp.local',
      '_samsung-http._tcp.local',
      '_webos-conn._tcp.local',
      '_sony-http._tcp.local',
      '_androidtv-remote._tcp.local',
      '_http._tcp.local',
    ];

    for (final type in serviceTypes) {
      try {
        await for (final ptr in mdns.lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer(type),
        )) {
          try {
            final srv = await mdns
                .lookup<SrvResourceRecord>(
                    ResourceRecordQuery.service(ptr.domainName))
                .first;
            final a = await mdns
                .lookup<IPAddressResourceRecord>(
                    ResourceRecordQuery.addressIPv4(srv.target))
                .first;

            final name = ptr.domainName.replaceAll('.$type', '');
            final vendor = _vendorFromServiceType(type);

            _log('[mDNS] $vendor :: $name @ ${a.address.address}:${srv.port}');

            yield IotTarget(
              id: 'lan_${a.address.address}_$vendor',
              name: name,
              type: ExploitType.lan,
              ipAddress: a.address.address,
              port: srv.port,
              vendor: vendor,
            );
          } catch (_) {}
        }
      } catch (_) {}
    }

    mdns.stop();
  }

  Stream<IotTarget> discoverBleTargets() async* {
    if (!await FlutterBluePlus.isSupported) {
      _log('[!] BLE NOT SUPPORTED ON THIS DEVICE');
      return;
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _log('[!] BLUETOOTH ADAPTER OFF');
      return;
    }

    final ctl = StreamController<IotTarget>();
    final seen = <String>{};

    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final id = r.device.remoteId.str;
        if (seen.contains(id)) continue;
        seen.add(id);
        final name = r.device.advName.isNotEmpty
            ? r.device.advName
            : r.device.platformName;
        if (name.isEmpty) continue;
        _log('[BLE] FOUND: $name ($id) RSSI: ${r.rssi}');
        ctl.add(IotTarget(
          id: 'ble_$id',
          name: name.toUpperCase(),
          type: ExploitType.ble,
          bleDeviceId: id,
          vendor: _guessBleVendor(name, r),
        ));
      }
    });

    _log('[BLE] SCANNING FOR DEVICES...');
    await FlutterBluePlus.startScan(
      withServices: [],
      androidScanMode: AndroidScanMode.lowLatency,
    );

    Future.delayed(const Duration(seconds: 8), () {
      sub.cancel();
      FlutterBluePlus.stopScan();
      if (!ctl.isClosed) ctl.close();
    });

    await for (final t in ctl.stream) {
      yield t;
    }
  }

  Future<OverrideCommandResult> sendCommand(IotTarget target, String action) async {
    if (target.type == ExploitType.ble) {
      return writeBleCharacteristic(
        target.bleDeviceId!,
        target.serviceUuid ?? '0000FFE0-0000-1000-8000-00805F9B34FB',
        target.characteristicUuid ?? '0000FFE1-0000-1000-8000-00805F9B34FB',
        [0x01, 0x00],
      );
    }

    final ip = target.ipAddress!;
    final vendor = target.vendor;

    _log('[>] SENDING $action -> $vendor @ $ip');
    OverrideCommandResult result;

    switch (vendor) {
      case 'Roku':
        result = await _sendRoku(ip, action);
        break;
      case 'Chromecast':
        result = await _sendChromecast(ip, action);
        break;
      case 'Samsung':
        result = await _sendSamsung(ip, action);
        break;
      case 'LG':
        result = await _sendLg(ip, action);
        break;
      case 'Sony':
        result = await _sendSony(ip, action);
        break;
      case 'Android TV':
        result = await _sendAndroidTv(ip, action);
        break;
      default:
        result = await _sendGeneric(ip, action);
    }

    _log(result.success
        ? '[+] ${result.endpoint} :: ${result.detail}'
        : '[!] ${result.endpoint} :: ${result.detail}');
    return result;
  }

  Future<OverrideCommandResult> _sendRoku(String ip, String action) async {
    final keyMap = {
      'PowerOff': 'PowerOff', 'VolumeUp': 'VolumeUp', 'VolumeDown': 'VolumeDown',
      'Mute': 'VolumeMute', 'Home': 'Home', 'Back': 'Back', 'Play': 'Play',
      'Search': 'Search', 'Up': 'Up', 'Down': 'Down', 'Left': 'Left',
      'Right': 'Right', 'Select': 'Select',
    };
    final key = keyMap[action] ?? action;

    try {
      final socket = await Socket.connect(ip, 8060, timeout: const Duration(seconds: 2));
      socket.destroy();

      final url = Uri.parse('http://$ip:8060/keypress/$key');
      final response = await http.post(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        return OverrideCommandResult(action, 'Roku', 'Roku:8060', true, '/keypress/$key -> HTTP 200');
      }
      return OverrideCommandResult(action, 'Roku', 'Roku:8060', false,
          '/keypress/$key -> HTTP ${response.statusCode}');
    } on SocketException {
      return OverrideCommandResult(action, 'Roku', 'Roku:8060', false, 'Port 8060 unreachable');
    } catch (e) {
      return OverrideCommandResult(action, 'Roku', 'Roku:8060', false,
          _trunc(e));
    }
  }

  Future<OverrideCommandResult> _sendChromecast(String ip, String action) async {
    // D-Pad and PowerOff route through ATVRP (port 6466) for Google TV / Android TV
    if (action == 'PowerOff' ||
        ['Up', 'Down', 'Left', 'Right', 'Select'].contains(action)) {
      try {
        final sock = await Socket.connect(ip, 6466, timeout: const Duration(seconds: 2));
        sock.destroy();
        _log('  [*] ATVRP PORT 6466 OPEN — ROUTING $action VIA ANDROID TV REMOTE PROTOCOL');
        return _sendAndroidTv(ip, action);
      } on SocketException {
        if (['Up', 'Down', 'Left', 'Right', 'Select'].contains(action)) {
          return OverrideCommandResult(action, 'Chromecast', 'ATVRP:6466', false,
              'TARGET_HAS_NO_NAVIGABLE_UI');
        }
        return OverrideCommandResult(action, 'Chromecast', 'ATVRP:6466', false,
            'POWER_OFF_UNSUPPORTED — Chromecast has no power-off via CastV2');
      }
    }

    // Volume / Media commands use CastV2 (receiver-0)
    _log('  [*] CASTV2 TLS SESSION $ip:8009...');

    try {
      final socket = await Socket.connect(ip, 8009, timeout: const Duration(seconds: 3));
      socket.destroy();
    } on SocketException {
      return OverrideCommandResult(action, 'Chromecast', 'CastV2:8009', false,
          'Port 8009 unreachable');
    }

    if (!_chromecast.isConnected || _chromecast.connectedIp != ip) {
      _log('  [*] INITIAL CONNECT receiver-0');
      final ok = await _chromecast.connect(ip);
      if (!ok) {
        return OverrideCommandResult(action, 'Chromecast', 'CastV2:8009', false,
            'TLS handshake failed');
      }
    }

    bool result;
    switch (action) {
      case 'VolumeUp':
        result = await _chromecast.sendVolumeUp();
        break;
      case 'VolumeDown':
        result = await _chromecast.sendVolumeDown();
        break;
      case 'Mute':
        result = await _chromecast.sendMute();
        break;
      case 'PlayPause':
        result = await _chromecast.sendPlayPause();
        break;
      case 'Stop':
        result = await _chromecast.sendStop();
        break;
      default:
        result = false;
    }

    if (!result && ['PlayPause', 'Stop'].contains(action)) {
      return OverrideCommandResult(action, 'Chromecast', 'CastV2:8009', false,
          'NO_ACTIVE_MEDIA_SESSION');
    }

    return OverrideCommandResult(action, 'Chromecast', 'CastV2:8009', result,
        result ? '$action via CastV2' : 'CastV2: $action failed');
  }

  Future<OverrideCommandResult> _sendSamsung(String ip, String action) async {
    try {
      final socket = await Socket.connect(ip, 8002, timeout: const Duration(seconds: 2));
      socket.destroy();
    } on SocketException {
      return OverrideCommandResult(action, 'Samsung', 'Samsung:8002', false,
          'Port 8002 unreachable (WebSocket remote control)');
    }

    try {
      final connected = await _samsung.connect(ip);
      if (!connected) {
        return OverrideCommandResult(action, 'Samsung', 'Samsung:8002', false,
            'WebSocket handshake failed');
      }

      final ok = await _samsung.sendKey(action);
      _samsung.disconnect();
      return OverrideCommandResult(action, 'Samsung', 'Samsung:8002', ok,
          ok ? '$action via Tizen WS' : 'Unknown key: $action');
    } catch (e) {
      _samsung.disconnect();
      return OverrideCommandResult(action, 'Samsung', 'Samsung:8002', false,
          'Samsung WS error: ${_trunc(e)}');
    }
  }

  Future<OverrideCommandResult> _sendLg(String ip, String action) async {
    _log('  [*] CONNECTING TO LG WEBOS WEBSOCKET @ $ip:3000...');

    try {
      final socket = await Socket.connect(ip, 3000, timeout: const Duration(seconds: 2));
      socket.destroy();
    } on SocketException {
      return OverrideCommandResult(action, 'LG', 'WebOS:3000', false,
          'Port 3000 unreachable');
    }

    try {
      final connected = await _lgWebos.connect(ip);
      if (!connected) {
        return OverrideCommandResult(action, 'LG', 'WebOS:3000', false,
            'Pairing failed — accept the prompt on your LG TV');
      }

      await _lgWebos.sendAction(action);
      _lgWebos.disconnect();
      return OverrideCommandResult(action, 'LG', 'WebOS:3000', true,
          '$action via WebSocket SSAP');
    } catch (e) {
      _lgWebos.disconnect();
      return OverrideCommandResult(action, 'LG', 'WebOS:3000', false,
          'WebOS error: ${_trunc(e)}');
    }
  }

  Future<OverrideCommandResult> _sendSony(String ip, String action) async {
    try {
      final socket = await Socket.connect(ip, 10080, timeout: const Duration(seconds: 2));
      socket.destroy();
    } on SocketException {
      return OverrideCommandResult(action, 'Sony', 'Sony:10080', false,
          'Port 10080 unreachable');
    }

    bool ok;
    switch (action) {
      case 'VolumeUp':
        ok = await _sony.sendVolumeUp(ip);
        break;
      case 'VolumeDown':
        ok = await _sony.sendVolumeDown(ip);
        break;
      case 'Mute':
        ok = await _sony.sendMute(ip);
        break;
      case 'PowerOff':
        ok = await _sony.sendPowerOff(ip);
        break;
      case 'Home':
        ok = await _sony.sendHome(ip);
        break;
      default:
        ok = false;
    }

    return OverrideCommandResult(action, 'Sony', 'Sony:10080', ok,
        ok ? '$action via Sony REST' : 'Action not mapped');
  }

  Future<OverrideCommandResult> _sendAndroidTv(String ip, String action) async {
    AndroidTvPairingManager? mgr = _atvManagers[ip];
    if (mgr == null) {
      mgr = AndroidTvPairingManager(ip, _secureStorage);
      _atvManagers[ip] = mgr;
      await mgr.start();
    } else if (mgr.state == AtvPairingState.failed ||
        mgr.state == AtvPairingState.checkingCache) {
      mgr.dispose();
      mgr = AndroidTvPairingManager(ip, _secureStorage);
      _atvManagers[ip] = mgr;
      await mgr.start();
    }

    if (mgr.state == AtvPairingState.failed) {
      return OverrideCommandResult(action, 'Android TV', 'ATV:6466', false,
          'ATVRP: ${mgr.failureDetail ?? "Unknown error"}');
    }
    if (mgr.state == AtvPairingState.requestingPin) {
      return OverrideCommandResult(action, 'Android TV', 'ATV:6467', false,
          'ANDROID_TV_PAIRING_REQUIRED');
    }
    if (mgr.state == AtvPairingState.paired) {
      final ok = await mgr.sendKey(action);
      return OverrideCommandResult(action, 'Android TV', 'ATV:6466', ok,
          ok ? '$action via ATVRP' : 'ATVRP: key $action failed');
    }
    return OverrideCommandResult(action, 'Android TV', 'ATV:6466', false,
        'ATVRP: unexpected state ${mgr.state}');
  }

  Future<bool> pairAndroidTv(String pin) async {
    for (final m in _atvManagers.values) {
      if (m.state == AtvPairingState.requestingPin) return m.pair(pin);
    }
    return false;
  }

  Future<OverrideCommandResult> _sendGeneric(String ip, String action) async {
    _log('[!] UNKNOWN VENDOR, PROBING ALL PORTS...');
    final attempts = [
      () => _sendRoku(ip, action),
      () => _sendSamsung(ip, action),
      () => _sendLg(ip, action),
      () => _sendSony(ip, action),
    ];
    for (final attempt in attempts) {
      final result = await attempt();
      if (result.endpoint.contains('unreachable')) continue;
      return result;
    }
    return OverrideCommandResult(action, 'UNKNOWN', 'generic', false, 'All vendor ports unreachable');
  }

  Future<Map<String, OverrideCommandResult>> carpetBomb(String ip) async {
    _log('[!] CARPET_BOMB INITIATED @ $ip');
    final results = <String, OverrideCommandResult>{};

    final commands = <String, Future<http.Response> Function()>{
      'ROKU:8060': () => http
          .post(Uri.parse('http://$ip:8060/keypress/PowerOff'))
          .timeout(const Duration(seconds: 2)),
      'LG:8080': () => http
          .post(Uri.parse('http://$ip:8080/roap/api/command'),
              body: '<?xml version="1.0" encoding="utf-8"?>'
                  '<command><name>PowerOff</name></command>')
          .timeout(const Duration(seconds: 2)),
      'SAMSUNG:8001': () => http
          .post(Uri.parse('http://$ip:8001/api/v2/apps/com.samsung.tv.poweroff'),
              body: '{"method":"ms.webapplication.poweroff","params":{}}')
          .timeout(const Duration(seconds: 2)),
      'SONY:10080': () => http
          .post(Uri.parse('http://$ip:10080/sony/system'),
              body: '{"method":"setPowerStatus","params":[{"status":false}]}')
          .timeout(const Duration(seconds: 2)),
    };

    final futures = <Future<OverrideCommandResult>>[];
    for (final entry in commands.entries) {
      futures.add(_fireCarpet(entry.key, entry.value));
    }

    final allResults = await Future.wait(futures);
    for (final r in allResults) {
      results[r.endpoint] = r;
    }

    _log('[!] CARPET_BOMB COMPLETE');
    for (final r in results.values) {
      _log('    ${r.success ? "[+]" : "[!]"} ${r.endpoint}: ${r.detail}');
    }
    return results;
  }

  Future<OverrideCommandResult> _fireCarpet(
      String label, Future<http.Response> Function() fn) async {
    try {
      final response = await fn();
      return OverrideCommandResult(
          label, label, label, response.statusCode == 200, 'HTTP ${response.statusCode}');
    } catch (e) {
      return OverrideCommandResult(label, label, label, false, e.toString());
    }
  }

  Future<OverrideCommandResult> writeBleCharacteristic(
    String deviceId, String serviceUuid, String characteristicUuid, List<int> bytes,
  ) async {
    BluetoothDevice? device;
    try {
      device = BluetoothDevice.fromId(deviceId);
      _log('[BLE] CONNECTING TO $deviceId...');
      await device.connect().timeout(const Duration(seconds: 10));
      _log('[BLE] DISCOVERING SERVICES...');
      final services = await device.discoverServices();

      for (final svc in services) {
        if (!svc.uuid.toString().toUpperCase().contains(
            serviceUuid.toUpperCase().replaceAll('-', ''))) { continue; }
        for (final chr in svc.characteristics) {
          if (!chr.uuid.toString().toUpperCase().contains(
              characteristicUuid.toUpperCase().replaceAll('-', ''))) { continue; }
          await chr.write(bytes);
          final msg = '[+] BLE WRITE OK: ${chr.uuid} <- 0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
          _log(msg);
          await device.disconnect();
          return OverrideCommandResult('bleWrite', 'BLE', chr.uuid.toString(), true, msg);
        }
      }

      await device.disconnect();
      const msg = '[!] BLE CHARACTERISTIC NOT FOUND';
      _log(msg);
      return OverrideCommandResult('bleWrite', 'BLE', 'scan', false, msg);
    } catch (e) {
      await device?.disconnect();
      return OverrideCommandResult('bleWrite', 'BLE', 'connect', false, '[!] BLE WRITE FAILED: $e');
    }
  }

  String _vendorFromServiceType(String type) {
    if (type.contains('roku')) return 'Roku';
    if (type.contains('googlecast')) return 'Chromecast';
    if (type.contains('samsung')) return 'Samsung';
    if (type.contains('webos')) return 'LG';
    if (type.contains('sony')) return 'Sony';
    if (type.contains('androidtv')) return 'Android TV';
    return 'Generic HTTP';
  }

  String _guessBleVendor(String name, ScanResult result) {
    if (name.contains('TV') || name.contains('TV ')) return 'Smart TV';
    if (name.contains('DRONE') || name.contains('UAV')) return 'Drone';
    if (name.contains('LIGHT') || name.contains('BULB')) return 'Lighting';
    if (name.contains('LOCK') || name.contains('DOOR')) return 'Smart Lock';
    if (name.contains('SENSOR') || name.contains('TAG')) return 'Sensor';
    if (result.advertisementData.manufacturerData.containsKey(0x004C)) {
      return 'Apple Peripheral';
    }
    return 'Generic BLE';
  }

  String _trunc(dynamic e) {
    final s = e.toString();
    return s.length > 80 ? s.substring(0, 80) : s;
  }

  void dispose() {
    _chromecast.disconnect();
    _lgWebos.dispose();
    _samsung.dispose();
    _sony.dispose();
    for (final m in _atvManagers.values) {
      m.dispose();
    }
    _atvManagers.clear();
    _logController.close();
  }
}
