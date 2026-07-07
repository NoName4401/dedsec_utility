import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/satellite_target.dart';

class OsintService {
  final _rand = Random();

  Future<UplinkData> fetchUplinkData({void Function(String log)? onLog}) async {
    onLog?.call('[UPLINK] QUERYING_WAN_IDENTITY...');
    final ipRes = await http.get(Uri.parse('http://ip-api.com/json/'));
    final ipJson = jsonDecode(ipRes.body) as Map<String, dynamic>;

    onLog?.call('[UPLINK] WAN_IP=${ipJson['query']}');

    // Default fallbacks to Kent Main Campus area coordinates if GPS fails
    double lat = (ipJson['lat'] as num?)?.toDouble() ?? 41.1498;
    double lon = (ipJson['lon'] as num?)?.toDouble() ?? -81.3415;

    try {
      onLog?.call('[UPLINK] REQUESTING_GPS_LOCK...');
      final permission = await _ensureLocationPermission();
      if (permission) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        lat = pos.latitude;
        lon = pos.longitude;
        onLog?.call('[UPLINK] GPS_LOCK_OK :: LAT:${lat.toStringAsFixed(4)}, LON:${lon.toStringAsFixed(4)}');
      } else {
        onLog?.call('[UPLINK] GPS_PERMISSION_DENIED - FALLING_BACK_TO_IP_GEO');
      }
    } catch (_) {
      onLog?.call('[UPLINK] GPS_UNAVAILABLE - FALLING_BACK_TO_IP_GEO');
    }

    onLog?.call('[UPLINK] SCANNING_LOCAL_SKY_CELL_VECTOR...');

    // Core structural profiles of real operational spacecraft overheading the US
    final baseSatellites = [
      {'name': 'ISS (ZARYA)', 'id': '25544', 'class': 'LEO // HABITATION_PLATFORM', 'freq': 145.800, 'baseAlt': 418.0, 'baseVel': 27560.0},
      {'name': 'NOAA-19', 'id': '33591', 'class': 'METEOROLOGICAL // APT_FEED', 'freq': 137.100, 'baseAlt': 846.0, 'baseVel': 26640.0},
      {'name': 'STARLINK-30421', 'id': '58742', 'class': 'COMM_MATRIX // DIRECT_CELL', 'freq': 12.200, 'baseAlt': 550.0, 'baseVel': 27000.0},
      {'name': 'COSMOS 2560', 'id': '54048', 'class': 'RECONNAISSANCE // OPTICAL_IMAGING', 'freq': 435.225, 'baseAlt': 295.0, 'baseVel': 28100.0},
      {'name': 'GPS BIIR-11', 'id': '28190', 'class': 'NAV_BEACON // M-CODE_MIL', 'freq': 1575.42, 'baseAlt': 20180.0, 'baseVel': 14000.0},
    ];

    final satellitePayloads = baseSatellites.map((sat) {
      // Build location-tied orbital drift variances
      final double siteSeed = sin(lat + lon + sat['name'].hashCode);
      final double currentElev = (25 + (siteSeed * 45)).clamp(5.0, 89.0);
      final double currentAzimuth = (180 + (siteSeed * 170)).clamp(0.0, 359.9);

      onLog?.call('[INTERCEPT] ORBITAL_NODE_FOUND :: NORAD:${sat['id']} (${sat['name']})');

      return SatelliteTarget(
        name: sat['name'] as String,
        noradId: sat['id'] as String,
        classification: sat['class'] as String,
        frequencyMhz: sat['freq'] as double,
        altitudeKm: (sat['baseAlt'] as double) + (siteSeed * 3.5),
        velocityKmh: (sat['baseVel'] as double) + (siteSeed * 11.2),
        azimuth: currentAzimuth,
        elevation: currentElev,
        downlinkStatus: currentElev > 20.0 ? 'LOCK_STABLE' : 'SIGNAL_DEGRADED',
      );
    }).toList();

    onLog?.call('[UPLINK] STRATEGIC_AIRSPACE_CAPTURE_COMPLETE');

    return UplinkData(
      publicIp: ipJson['query'] ?? 'UNKNOWN',
      isp: ipJson['isp'] ?? 'UNKNOWN_ASN',
      city: ipJson['city'] ?? 'UNKNOWN_CITY',
      region: ipJson['regionName'] ?? 'UNKNOWN_REGION',
      latitude: lat,
      longitude: lon,
      overheadSatellites: satellitePayloads,
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