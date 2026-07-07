import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:lan_scanner/lan_scanner.dart';
import '../models/lan_device.dart';
import 'mac_vendor_lookup.dart';

/// CORE_MODULE_02 - "NETHACK" NETWORK DIAGNOSTIC SCANNER
/// Sweeps the *local* subnet only. This talks to devices already on your
/// own network -- the same thing any router admin page or a tool like
/// Fing/nmap does. It never leaves your LAN.
class NetworkService {
  final _info = NetworkInfo();

  /// Common ports worth flagging on a home network. Extend freely.
  static const Map<int, String> commonPorts = {
    21: 'FTP',
    22: 'SSH',
    23: 'TELNET',
    80: 'HTTP',
    443: 'HTTPS',
    445: 'SMB',
    554: 'RTSP_CAMERA',
    631: 'IPP_PRINTER',
    3389: 'RDP',
    5000: 'UPNP_SVC',
    8080: 'HTTP_ALT',
    8443: 'HTTPS_ALT',
    8554: 'RTSP_ALT',
    9100: 'PRINTER_RAW',
  };

  Future<String?> localSubnetPrefix() async {
    final ip = await _info.getWifiIP();
    if (ip == null) return null;
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  Future<String?> localIp() => _info.getWifiIP();

  /// Sweeps .1 - .255 on the local subnet and streams discovered hosts.
  Stream<LanDevice> sweepSubnet({void Function(String log)? onLog}) async* {
    final prefix = await localSubnetPrefix();
    if (prefix == null) {
      onLog?.call('[ERROR] NO_WIFI_INTERFACE_DETECTED');
      return;
    }
    onLog?.call('[INIT] SUBNET_ROOT=$prefix.0/24');

    final scanner = LanScanner(debugLogging: false);
    final stream = scanner.icmpScan(prefix, progressCallback: (progress) {});

    await for (final host in stream) {
      final ip = host.internetAddress.address;
      onLog?.call('[TARGET_DISCOVERED] IP:$ip');
      yield LanDevice(
        ip: ip,
        mac: null, // MAC resolution requires an ARP table read; see README.
        vendor: MacVendorLookup.lookup(null),
        alive: true,
      );
    }
    onLog?.call('[DONE] SWEEP_COMPLETE');
  }

  /// Scans a fixed list of common ports on a single host with a short
  /// per-port timeout. Returns the ports that accepted a TCP connection.
  Future<List<PortResult>> scanPorts(String ip,
      {void Function(String log)? onLog}) async {
    final results = <PortResult>[];
    final futures = commonPorts.entries.map((entry) async {
      try {
        final socket = await Socket.connect(
          ip,
          entry.key,
          timeout: const Duration(milliseconds: 400),
        );
        socket.destroy();
        onLog?.call('[PORT_OPEN] $ip:${entry.key} (${entry.value})');
        return PortResult(port: entry.key, label: entry.value);
      } catch (_) {
        return null;
      }
    });
    final resolved = await Future.wait(futures);
    for (final r in resolved) {
      if (r != null) results.add(r);
    }
    results.sort((a, b) => a.port.compareTo(b.port));
    return results;
  }
}
