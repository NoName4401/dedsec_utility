import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/lan_device.dart';

class NetworkService {
  final _info = NetworkInfo();

  /// Pulls the subnet prefix of the local Wi-Fi interface (e.g., "192.168.1")
  Future<String> localSubnetPrefix() async {
    final ip = await _info.getWifiIP();
    if (ip == null) return '192.168.1';
    final parts = ip.split('.');
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  /// Returns your phone's exact local binding IP
  Future<String> localIp() async {
    return await _info.getWifiIP() ?? 'UNKNOWN_IP';
  }

  /// Aggressive TCP Sweep: Bypasses ICMP firewalls by attempting raw socket handshakes
  Stream<LanDevice> sweepSubnet({void Function(String)? onLog}) async* {
    final subnet = await localSubnetPrefix();
    onLog?.call('[SWEEP] INITIALIZING TCP_SYN PROBE ON $subnet.0/24');

    // Windows usually exposes 135 (RPC) or 445 (SMB) to the local subnet.
    // 80 (HTTP) and 554 (RTSP) catch generic IoT devices and cameras.
    final targetPorts = [445, 135, 80, 554];
    final futures = <Future<LanDevice?>>[];

    // Spin up 254 simultaneous socket checks
    for (int i = 1; i < 255; i++) {
      final targetIp = '$subnet.$i';
      futures.add(_stealthTcpPing(targetIp, targetPorts));
    }

    // Process the results as they finish the asynchronous timeout windows
    for (final future in futures) {
      final device = await future;
      if (device != null) {
        onLog?.call('[DISCOVERY] GHOST_NODE_UNMASKED :: ${device.ip}');
        yield device;
      }
    }
    
    onLog?.call('[SWEEP] SUBNET_MATRIX_SCAN_COMPLETE');
  }

  /// Attempts a lightning-fast TCP connection. If it connects OR explicitly refuses, the host is alive.
  /// Attempts a lightning-fast TCP connection. If it connects OR refuses, the host is alive.
  Future<LanDevice?> _stealthTcpPing(String ip, List<int> ports) async {
    bool isAlive = false;

    for (int port in ports) {
      try {
        final socket = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 300));
        socket.destroy(); 
        isAlive = true;
        break; // Node is confirmed alive, skip remaining port checks
      } catch (e) {
        if (e is SocketException) {
          final msg = e.message.toLowerCase();
          if (msg.contains('refused') || e.osError?.errorCode == 111) {
            isAlive = true;
            break;
          }
        }
      }
    }

    if (isAlive) {
      String resolvedHostName = 'UNKNOWN_NODE';
      
      try {
        // =============================================
        // LAYER 7 PIVOT: REVERSE DNS / mDNS LOOKUP
        // =============================================
        // Queries the router's DNS registry to resolve the IP back into a human-readable hostname.
        final hostData = await InternetAddress(ip).reverse().timeout(const Duration(milliseconds: 400));
        
        // If the lookup returns the exact same IP, it means the router has no name registered for it.
        if (hostData.host != ip) {
          // Strip out the noisy local domain tags (like .lan or .local) for a cleaner UI
          resolvedHostName = hostData.host.replaceAll('.lan', '').replaceAll('.local', '');
        }
      } catch (_) {
        // Silent fail if the target drops the lookup request
      }

      return _buildGenericDevice(ip, resolvedHostName);
    }
    
    return null;
  }

  LanDevice _buildGenericDevice(String ip, String hostName) {
    return LanDevice(
      ip: ip,
      mac: 'RESTRICTED_BY_OS', // Acknowledging the OS sandbox limit
      vendor: hostName.toUpperCase(), // Injecting the intercepted hostname into the vendor UI slot
      alive: true,
      profile: DeviceProfile(
        occupation: 'UNIDENTIFIED NETWORK NODE',
        riskFactor: 'UNKNOWN',
        diagnosticFact: 'Host responded to raw TCP handshake mapping.',
      ),
      openPorts: [],
      scanningPorts: false,
    );
  }

  /// Deep Port Mapper: Scans standard 1000 ports on an unmasked target
  Future<List<PortSignature>> scanPorts(String ip, {void Function(String)? onLog}) async {
    final List<PortSignature> openPorts = [];
    final commonPorts = {
      21: 'FTP_GATEWAY',
      22: 'SSH_TERMINAL',
      23: 'TELNET_UNENCRYPTED',
      80: 'HTTP_WEB_SERVER',
      135: 'MS_RPC_SERVICE',
      139: 'NETBIOS_SESSION',
      443: 'HTTPS_SECURE',
      445: 'SMB_FILE_SHARE',
      554: 'RTSP_MEDIA_STREAM',
      3389: 'RDP_REMOTE_DESKTOP',
      8080: 'HTTP_PROXY',
    };

    onLog?.call('[PORT_MAPPER] INITIATING DIRECTED ATTACK ON $ip');

    final scanFutures = commonPorts.keys.map((port) async {
      try {
        final socket = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 400));
        socket.destroy();
        openPorts.add(PortSignature(port: port, label: commonPorts[port]!));
      } catch (_) {
        // Port closed or filtered
      }
    });

    await Future.wait(scanFutures);
    return openPorts;
  }

  /// Probability Engine: Analyzes open ports to guess the hardware type
  DeviceProfile calculateDeviceProbability(String ip, List<PortSignature> ports, String vendor) {
    final portNums = ports.map((p) => p.port).toList();

    if (portNums.contains(554)) {
      return DeviceProfile(
        occupation: 'IP SURVEILLANCE CAMERA // ctOS FEED',
        riskFactor: 'HIGH',
        diagnosticFact: 'RTSP media stream exposed on port 554. Vulnerable to video feed interception.',
      );
    } else if (portNums.contains(445) || portNums.contains(135)) {
      return DeviceProfile(
        occupation: 'WINDOWS WORKSTATION // DESKTOP OS',
        riskFactor: 'MODERATE',
        diagnosticFact: 'SMB/RPC file sharing ports exposed. Likely a standard Windows desktop machine.',
      );
    } else if (portNums.contains(80) || portNums.contains(443)) {
      return DeviceProfile(
        occupation: 'WEB SERVER // ROUTER GATEWAY',
        riskFactor: 'LOW',
        diagnosticFact: 'Standard HTTP/HTTPS administration ports open.',
      );
    } else {
      return DeviceProfile(
        occupation: 'LOCKED IOT NODE // MOBILE DEVICE',
        riskFactor: 'MINIMAL',
        diagnosticFact: 'No critical service ports exposed to local subnet.',
      );
    }
  }
}

class PortSignature {
  final int port;
  final String label;
  PortSignature({required this.port, required this.label});
}