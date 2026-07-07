class SatelliteTarget {
  final String name;
  final String noradId;
  final String classification;
  final double frequencyMhz;
  final double altitudeKm;
  final double velocityKmh;
  final double azimuth;
  final double elevation;
  final String downlinkStatus;

  const SatelliteTarget({
    required this.name,
    required this.noradId,
    required this.classification,
    required this.frequencyMhz,
    required this.altitudeKm,
    required this.velocityKmh,
    required this.azimuth,
    required this.elevation,
    required this.downlinkStatus,
  });
}

class UplinkData {
  final String publicIp;
  final String isp;
  final String city;
  final String region;
  final double latitude;
  final double longitude;
  final List<SatelliteTarget> overheadSatellites;

  const UplinkData({
    required this.publicIp,
    required this.isp,
    required this.city,
    required this.region,
    required this.latitude,
    required this.longitude,
    required this.overheadSatellites,
  });
}