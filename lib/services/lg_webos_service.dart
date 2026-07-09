import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class LgWebosService {
  WebSocketChannel? _channel;
  int _reqId = 0;
  final _responseController = StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription? _sub;
  String? _clientKey;
  Completer<bool>? _pairCompleter;

  Future<bool> connect(String ip) async {
    await _loadClientKey();

    try {
      _channel = WebSocketChannel.connect(Uri.parse('ws://$ip:3000'));

      _sub = _channel!.stream.listen(
        (raw) {
          if (raw is! String) return;
          try {
            final msg = jsonDecode(raw) as Map<String, dynamic>;
            _handleMessage(msg);
          } catch (_) {}
        },
        onError: (_) => _pairCompleter?.complete(false),
        onDone: () => _pairCompleter?.complete(false),
      );

      final completer = Completer<bool>();
      _pairCompleter = completer;

      _send({
        'id': 'register_0',
        'type': 'register',
        'payload': {
          'forcePairing': false,
          'pairingType': 'PROMPT',
          'manifest': {
            'appVersion': '1.0',
            'manifestVersion': 1,
            'permissions': [
              'CONTROL_AUDIO', 'CONTROL_POWER', 'CONTROL_INPUT_MEDIA_PLAYBACK',
              'CONTROL_MOUSE_AND_KEYBOARD', 'READ_SETTINGS', 'READ_INSTALLED_APPS',
              'READ_RUNNING_APPS', 'CONTROL_INPUT_TEXT',
            ],
          },
          if (_clientKey != null) 'client-key': _clientKey,
        },
      });

      return completer.future.timeout(const Duration(seconds: 15));
    } catch (_) {
      return false;
    }
  }

  void _handleMessage(Map<String, dynamic> msg) {
    if (msg['type'] == 'registered') {
      final newKey = msg['payload']?['client-key'] as String?;
      if (newKey != null) {
        _clientKey = newKey;
        _saveClientKey(newKey);
      }
      _pairCompleter?.complete(true);
    } else if (msg['type'] == 'error') {
      _pairCompleter?.complete(false);
    } else if (msg['type'] == 'response') {
      _responseController.add(msg);
    }
  }

  Future<bool> sendAction(String action) async {
    if (_channel == null) return false;

    try {
      switch (action) {
        case 'PowerOff':
          _sendRequest('ssap://system/turnOff');
          return true;
        case 'VolumeUp':
          _sendRequest('ssap://audio/volumeUp');
          return true;
        case 'VolumeDown':
          _sendRequest('ssap://audio/volumeDown');
          return true;
        case 'Mute':
          _sendRequest('ssap://audio/setMute', {'mute': true});
          return true;
        case 'Home':
          _sendRequest('ssap://system.launcher/open', {'id': 'com.webos.app.home'});
          return true;
        case 'Back':
          _sendRequest('ssap://system/input', {'key': 'BACK'});
          return true;
        case 'Up':
          _sendRequest('ssap://system/input', {'key': 'UP'});
          return true;
        case 'Down':
          _sendRequest('ssap://system/input', {'key': 'DOWN'});
          return true;
        case 'Left':
          _sendRequest('ssap://system/input', {'key': 'LEFT'});
          return true;
        case 'Right':
          _sendRequest('ssap://system/input', {'key': 'RIGHT'});
          return true;
        case 'Select':
          _sendRequest('ssap://system/input', {'key': 'ENTER'});
          return true;
        default:
          return false;
      }
    } catch (_) {
      return false;
    }
  }

  void _sendRequest(String uri, [Map<String, dynamic>? payload]) {
    _send({
      'id': 'req_${++_reqId}',
      'type': 'request',
      'uri': uri,
      'payload': payload ?? {},
    });
  }

  void _send(Map<String, dynamic> msg) {
    try {
      _channel?.sink.add(jsonEncode(msg));
    } catch (_) {}
  }

  Future<void> _loadClientKey() async {
    final prefs = await SharedPreferences.getInstance();
    _clientKey = prefs.getString('lg_webos_client_key');
  }

  Future<void> _saveClientKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lg_webos_client_key', key);
  }

  void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _responseController.close();
  }
}
