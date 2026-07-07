class PortResult {
  final int port;
  final String label;
  const PortResult({required this.port, required this.label});
}

class LanDevice {
  final String ip;
  final String? mac;
  final String vendor;
  final bool alive;
  List<PortResult> openPorts;
  bool scanningPorts;

  LanDevice({
    required this.ip,
    this.mac,
    this.vendor = 'UNKNOWN_VENDOR',
    this.alive = true,
    List<PortResult>? openPorts,
    this.scanningPorts = false,
  }) : openPorts = openPorts ?? [];
}
