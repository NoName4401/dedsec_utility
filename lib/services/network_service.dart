import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:lan_scanner/lan_scanner.dart';
import '../models/lan_device.dart';
import 'mac_vendor_lookup.dart';

class NetworkService {
  final _info = NetworkInfo();
  final _rand = Random();

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

  /// Advanced Connect Sweep: Discovers stealth targets by knocking directly
  /// on common HTTP/HTTPS/RDP web and infrastructure channels.
  /// High-Speed Parallel Connect Sweep
  Stream<LanDevice> sweepSubnet({void Function(String log)? onLog}) async* {
    final prefix = await localSubnetPrefix();
    if (prefix == null) {
      onLog?.call('[ERROR] NO_WIFI_INTERFACE_DETECTED');
      return;
    }
    onLog?.call('[INIT] LAUNCHING_HYBRID_MATRIX_PROBE...');

    final portsToCheck = [80, 443, 22, 3389];
    const int batchSize = 15; // Balanced concurrent thread tracking pool

    for (int i = 1; i < 255; i += batchSize) {
      final List<Future<LanDevice?>> batchFutures = [];

      for (int j = i; j < i + batchSize && j < 255; j++) {
        final targetIp = '$prefix.$j';

        batchFutures.add(() async {
          bool isAlive = false;

          // Check 1: Fast TCP Service Knock
          for (int port in portsToCheck) {
            try {
              final socket = await Socket.connect(targetIp, port, timeout: const Duration(milliseconds: 120));
              socket.destroy();
              isAlive = true;
              break;
            } catch (_) {}
          }

          // Check 2: System Fallback (Knock on Port 53 DNS or basic socket lookup)
          if (!isAlive) {
            try {
              final socket = await Socket.connect(targetIp, 53, timeout: const Duration(milliseconds: 100));
              socket.destroy();
              isAlive = true;
            } catch (_) {}
          }

          if (isAlive) {
            final mockMac = _generateStableMacForIp(targetIp);
            final vendorName = MacVendorLookup.lookup(mockMac);
            final profileDossier = _generateDossierForVendor(vendorName, targetIp);

            return LanDevice(
              ip: targetIp,
              mac: mockMac,
              vendor: vendorName,
              alive: true,
              profile: profileDossier,
            );
          }
          return null;
        }());
      }

      final List<LanDevice?> results = await Future.wait(batchFutures);
      for (final device in results) {
        if (device != null) {
          onLog?.call('[TARGET_UNMASKED] IP:${device.ip}');
          yield device;
        }
      }
    }
    onLog?.call('[DONE] STEALTH_SWEEP_COMPLETE');
  }

  String _generateStableMacForIp(String ip) {
    final lastOctet = int.tryParse(ip.split('.').last) ?? 15;
    // Map host indices to your OUI lookup prefix tables
    final prefixes = [
      'A4:83:E7', '64:16:66', 'FC:A1:83', 'F4:F5:D8',
      '00:1D:C9', 'B8:27:EB', '18:B4:30', '00:17:AB'
    ];
    final prefix = prefixes[lastOctet % prefixes.length];
    final suffix = (lastOctet * 3).toRadixString(16).padLeft(2, '0').toUpperCase();
    return '$prefix:A1:B2:$suffix';
  }

  LanDeviceProfile _generateDossierForVendor(String vendor, String ip) {
    final List<String> occupations = ['Network Eng', 'SysAdmin', 'Undergrad', 'Smart Node', 'DevOps Tech'];
    final List<String> facts = [
      'Running a local IXL coordination override module.',
      'Siphoning home bandwidth for 4K video streams.',
      'Storing master passwords inside unencrypted .txt arrays.',
      'Monitoring internal smart home sensor matrices.',
    ];

    return LanDeviceProfile(
      occupation: '$vendor INVENTORY',
      diagnosticFact: facts[_rand.nextInt(facts.length)],
      riskFactor: ip.endsWith('.1') ? 'RISK: SEVERE // CORE_GATEWAY' : 'RISK: MINIMAL // STABLE',
    );
  }

  /// Updated Port Scanner that returns open channels and calculates device probability
  Future<List<PortResult>> scanPorts(String ip, {void Function(String log)? onLog}) async {
    final results = <PortResult>[];
    final futures = commonPorts.entries.map((entry) async {
      try {
        final socket = await Socket.connect(ip, entry.key, timeout: const Duration(milliseconds: 350));
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

  /// DedSec Probability Engine: Infers device type based on open ports and network layer metrics
  LanDeviceProfile calculateDeviceProbability(String ip, List<PortResult> openPorts, String currentVendor) {
    String inferredOccupation = '$currentVendor NODE';
    String inferredRisk = 'RISK: MINIMAL // STABLE';
    String inferredFact = 'Passive network footprint detected. Host routing standard data packets.';

    // Extract port integers for fast containment checks
    final openPortNums = openPorts.map((p) => p.port).toSet();

    // Case 1: Core Network Infrastructure
    if (ip.endsWith('.1')) {
      return const LanDeviceProfile(
        occupation: 'CORE NETWORK GATEWAY // ctOS ROUTER',
        diagnosticFact: 'Manages all internal traffic, DNS routing tables, and external WAN handshakes. High priority pivot point.',
        riskFactor: 'RISK: CRITICAL // SYSTEM_ROOT',
      );
    }

    // Case 2: Security & Surveillance Footprint
    if (openPortNums.contains(554) || openPortNums.contains(8554)) {
      return const LanDeviceProfile(
        occupation: 'IP SURVEILLANCE CAMERA // ctOS FEED',
        diagnosticFact: 'Active RTSP video streaming channel detected. Capturing environmental visual data arrays in real-time.',
        riskFactor: 'RISK: MODERATE // EXPOSED_STREAM',
      );
    }

    // Case 3: Network Printing Hubs
    if (openPortNums.contains(631) || openPortNums.contains(9100)) {
      return LanDeviceProfile(
        occupation: 'NETWORK PRINTER // DOCUMENT_HUB',
        diagnosticFact: 'Active print spooler listeners open. Intercepted system logs indicate routine document processing pipelines.',
        riskFactor: inferredRisk,
      );
    }

    // Case 4: Windows Operating System Environment
    if (openPortNums.contains(3389) || openPortNums.contains(445)) {
      return const LanDeviceProfile(
        occupation: 'WINDOWS WORKSTATION // TARGET_HOST',
        diagnosticFact: 'Remote Desktop Protocol (RDP) or SMB file-sharing gateways exposed. Potential access vectors available via terminal analysis.',
        riskFactor: 'RISK: HIGH // FILE_SYSTEM_EXPOSED',
      );
    }

    // Case 5: Linux Systems / Telnet / SSH Listeners
    if (openPortNums.contains(22) || openPortNums.contains(23)) {
      return const LanDeviceProfile(
        occupation: 'LINUX SERVER // TERMINAL_NODE',
        diagnosticFact: 'Active remote command line shell listening for handshakes. Requires secure cryptographic authentication tokens.',
        riskFactor: 'RISK: HIGH // REMOTE_SHELL_ACTIVE',
      );
    }

    // Fallback: If no ports are open, calculate based on corporate vendor strings
    if (currentVendor.contains('APPLE')) {
      inferredOccupation = 'APPLE HARDWARE ENVIRONMENT';
      inferredFact = 'Device belongs to an Apple mobile or macOS hardware loop. Strict sandboxed operating frameworks active.';
    } else if (currentVendor.contains('SAMSUNG') || currentVendor.contains('GOOGLE')) {
      inferredOccupation = 'ANDROID MOBILE ASSET';
      inferredFact = 'Mobile operating terminal detected. Actively syncing location telemetry coordinates and background cloud data arrays.';
    } else if (currentVendor.contains('AMAZON')) {
      inferredOccupation = 'SMART MEDIA APPLIANCE';
      inferredFact = 'IoT media streaming platform or smart assistant hub verified. Actively monitoring wireless audio channels.';
    }

    return LanDeviceProfile(
      occupation: inferredOccupation,
      diagnosticFact: inferredFact,
      riskFactor: inferredRisk,
    );
  }
}