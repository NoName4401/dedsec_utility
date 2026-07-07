class UplinkData {
  final String publicIp;
  final String isp;
  final String city;
  final String region;
  final double? latitude;
  final double? longitude;
  final double? pressureHpa;
  final double? humidityPct;
  final double? windSpeedKph;
  final double? tempC;

  const UplinkData({
    required this.publicIp,
    required this.isp,
    required this.city,
    required this.region,
    this.latitude,
    this.longitude,
    this.pressureHpa,
    this.humidityPct,
    this.windSpeedKph,
    this.tempC,
  });
}
