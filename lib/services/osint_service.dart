import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/weather_data.dart';

/// CORE_MODULE_04 - "SATELLITE UPLINK" OSINT INTELLIGENCE
/// Uses only free, credential-free public APIs:
///   - ip-api.com for public IP / ISP / rough geo
///   - open-meteo.com for live weather metrics
class OsintService {
  Future<UplinkData> fetchUplinkData({void Function(String log)? onLog}) async {
    onLog?.call('[UPLINK] QUERYING_WAN_IDENTITY...');
    final ipRes = await http.get(Uri.parse('http://ip-api.com/json/'));
    final ipJson = jsonDecode(ipRes.body) as Map<String, dynamic>;

    onLog?.call('[UPLINK] WAN_IP=${ipJson['query']}');

    double? lat = (ipJson['lat'] as num?)?.toDouble();
    double? lon = (ipJson['lon'] as num?)?.toDouble();

    // Prefer high-precision device GPS if permission is granted.
    try {
      onLog?.call('[UPLINK] REQUESTING_GPS_LOCK...');
      final permission = await _ensureLocationPermission();
      if (permission) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        lat = pos.latitude;
        lon = pos.longitude;
        onLog?.call('[UPLINK] GPS_LOCK_OK');
      } else {
        onLog?.call('[UPLINK] GPS_PERMISSION_DENIED - FALLING_BACK_TO_IP_GEO');
      }
    } catch (_) {
      onLog?.call('[UPLINK] GPS_UNAVAILABLE - FALLING_BACK_TO_IP_GEO');
    }

    double? pressure, humidity, wind, temp;
    if (lat != null && lon != null) {
      onLog?.call('[UPLINK] QUERYING_ATMOSPHERIC_GRID...');
      final weatherUri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,relative_humidity_2m,pressure_msl,wind_speed_10m',
      );
      final wRes = await http.get(weatherUri);
      final wJson = jsonDecode(wRes.body) as Map<String, dynamic>;
      final current = wJson['current'] as Map<String, dynamic>?;
      if (current != null) {
        temp = (current['temperature_2m'] as num?)?.toDouble();
        humidity = (current['relative_humidity_2m'] as num?)?.toDouble();
        pressure = (current['pressure_msl'] as num?)?.toDouble();
        wind = (current['wind_speed_10m'] as num?)?.toDouble();
      }
      onLog?.call('[UPLINK] ATMOSPHERIC_GRID_OK');
    }

    return UplinkData(
      publicIp: ipJson['query'] ?? 'UNKNOWN',
      isp: ipJson['isp'] ?? 'UNKNOWN_ASN',
      city: ipJson['city'] ?? 'UNKNOWN_CITY',
      region: ipJson['regionName'] ?? 'UNKNOWN_REGION',
      latitude: lat,
      longitude: lon,
      pressureHpa: pressure,
      humidityPct: humidity,
      windSpeedKph: wind,
      tempC: temp,
    );
  }

  Future<bool> _ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
