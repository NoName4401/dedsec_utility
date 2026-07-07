class PortResult {
  final int port;
  final String label;
  const PortResult({required this.port, required this.label});
}

class LanDeviceProfile {
  final String occupation;
  final String diagnosticFact;
  final String riskFactor;

  const LanDeviceProfile({
    required this.occupation,
    required this.diagnosticFact,
    required this.riskFactor,
  });
}

class LanDevice {
  final String ip;
  final String? mac;
  final String vendor;
  final bool alive;
  final LanDeviceProfile profile; // DedSec Profile Dossier
  List<PortResult> openPorts;
  bool scanningPorts;

  LanDevice({
    required this.ip,
    this.mac,
    this.vendor = 'UNKNOWN_VENDOR',
    this.alive = true,
    required this.profile,
    List<PortResult>? openPorts,
    this.scanningPorts = false,
  }) : openPorts = openPorts ?? [];
}