import '../services/network_service.dart'; // Imports the PortSignature class

/// Holds the tactical DedSec classification data for an unmasked target
class DeviceProfile {
  final String occupation;
  final String riskFactor;
  final String diagnosticFact;

  DeviceProfile({
    required this.occupation,
    required this.riskFactor,
    required this.diagnosticFact,
  });
}

/// The master network node object representing a physical piece of hardware
class LanDevice {
  final String ip;
  final String? mac;
  final String vendor;
  final bool alive;
  final DeviceProfile profile;
  
  // Mutable state variables for the UI scanning actions
  List<PortSignature> openPorts;
  bool scanningPorts;

  LanDevice({
    required this.ip,
    this.mac,
    required this.vendor,
    required this.alive,
    required this.profile,
    this.openPorts = const [],
    this.scanningPorts = false,
  });
}