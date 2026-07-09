import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class SamsungService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  static const _keyCodes = {
    'PowerOff': 'KEY_POWEROFF',
    'Power': 'KEY_POWER',
    'VolumeUp': 'KEY_VOLUP',
    'VolumeDown': 'KEY_VOLDOWN',
    'Mute': 'KEY_MUTE',
    'Home': 'KEY_HOME',
    'Source': 'KEY_SOURCE',
    'Back': 'KEY_BACK',
    'Up': 'KEY_UP',
    'Down': 'KEY_DOWN',
    'Left': 'KEY_LEFT',
    'Right': 'KEY_RIGHT',
    'Select': 'KEY_ENTER',
  };

  Future<bool> connect(String ip) async {
    disconnect();

    try {
      final wsUrl = 'ws://$ip:8002/api/v2/channels/'
          'samsung.remote.control?name=${Uri.encodeComponent('DedSec Utility')}';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      final completer = Completer<bool>();

      _sub = _channel!.stream.listen(
        (raw) {
          if (raw is! String) return;
          try {
            final msg = jsonDecode(raw) as Map<String, dynamic>;
            if (msg['event'] == 'ms.channel.connect') {
              completer.complete(true);
            }
          } catch (_) {}
        },
        onError: (_) => completer.complete(false),
        onDone: () => completer.complete(false),
      );

      return completer.future.timeout(const Duration(seconds: 8));
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendKey(String action) async {
    if (_channel == null) return false;
    final keyCode = _keyCodes[action];
    if (keyCode == null) return false;

    try {
      _channel!.sink.add(jsonEncode({
        'method': 'ms.remote.control',
        'params': {
          'Cmd': 'Click',
          'DataOfCmd': keyCode,
          'Option': 'false',
          'TypeOfRemote': 'SendRemoteKey',
        },
      }));
      return true;
    } catch (_) {
      return false;
    }
  }

  void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
  }
}
