import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SonyService {
  Future<bool> sendVolumeUp(String ip) async {
    return _sendAudio(ip, {
      'method': 'setAudioVolume',
      'params': [{'target': 'speaker', 'volume': 20}],
      'id': 1,
      'version': '1.0',
    });
  }

  Future<bool> sendVolumeDown(String ip) async {
    return _sendAudio(ip, {
      'method': 'setAudioVolume',
      'params': [{'target': 'speaker', 'volume': 5}],
      'id': 1,
      'version': '1.0',
    });
  }

  Future<bool> sendMute(String ip) async {
    return _sendAudio(ip, {
      'method': 'setAudioMute',
      'params': [{'status': true}],
      'id': 1,
      'version': '1.0',
    });
  }

  Future<bool> sendPowerOff(String ip) async {
    return _sendSystem(ip, {
      'method': 'setPowerStatus',
      'params': [{'status': false}],
      'id': 1,
      'version': '1.0',
    });
  }

  Future<bool> sendHome(String ip) async {
    return _sendAppControl(ip, {
      'method': 'setActiveApp',
      'params': [{'uri': 'home'}],
      'id': 1,
      'version': '1.0',
    });
  }

  Future<bool> _sendAudio(String ip, Map<String, dynamic> body) async {
    return _post(ip, 10080, '/sony/audio', body);
  }

  Future<bool> _sendSystem(String ip, Map<String, dynamic> body) async {
    return _post(ip, 10080, '/sony/system', body);
  }

  Future<bool> _sendAppControl(String ip, Map<String, dynamic> body) async {
    return _post(ip, 10080, '/sony/appControl', body);
  }

  Future<bool> _post(String ip, int port, String path, Map<String, dynamic> body) async {
    try {
      final url = Uri.parse('http://$ip:$port$path');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void dispose() {}
}
