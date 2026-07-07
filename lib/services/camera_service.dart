import 'dart:async';
import 'package:http/http.dart' as http;

class CameraService {
  /// Master registry of standard RTSP channel pathways used across the market
  final List<String> commonCameraPaths = const [
    '/live.sdp',
    '/h264Preview_01_main',
    '/Streaming/Channels/101',
    '/live/ch0',
    '/cam/realmonitor?channel=1&subtype=0',
    '/videoMain',
    '', // Some hardware streams straight to root
  ];

  /// Brute-forces the stream path of an identified local IP asset
  /// to locate the correct video gateway string.
  Future<String?> identifyStreamPath(String cameraIp) async {
    // Standard local cameras use Port 554 for RTSP, but often run
    // a basic web server on Port 80 for administrative coordination.
    for (String path in commonCameraPaths) {
      try {
        final testUri = Uri.parse('http://$cameraIp:80$path');
        final response = await http.head(testUri).timeout(const Duration(milliseconds: 200));

        // If the web server returns a valid handshake status or an auth challenge (401),
        // it indicates a functional endpoint path is active.
        if (response.statusCode == 200 || response.statusCode == 401) {
          return 'rtsp://$cameraIp:554$path';
        }
      } catch (_) {
        // Suppress connection rejections; move to next validation check
      }
    }

    // Default fallback if the web administration gate is locked completely stealth
    return 'rtsp://$cameraIp:554/live.sdp';
  }
}