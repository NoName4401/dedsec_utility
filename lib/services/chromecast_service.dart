import 'dart:async';
import 'dart:convert';
import 'package:dart_cast/src/protocols/chromecast/castv2_channel.dart';
import 'package:dart_cast/src/protocols/chromecast/cast_receiver_channel.dart';
import 'package:dart_cast/src/protocols/chromecast/proto/cast_channel.dart';

class ChromecastService {
  static const _senderId = 'sender-0';
  static const _receiverId = 'receiver-0';

  CastV2Channel? _channel;
  StreamSubscription<CastMessage>? _msgSub;
  String? _connectedIp;
  Timer? _heartbeatTimer;
  bool _connected = false;

  bool get isConnected => _connected;
  String? get connectedIp => _connectedIp;

  Future<bool> connect(String ip) async {
    if (_connected && _connectedIp == ip) return true;
    await disconnect();

    try {
      _channel = CastV2Channel();
      await _channel!.connect(ip, port: 8009);

      _msgSub = _channel!.messageStream.listen(_onMessage);

      _channel!.sendMessage(
        namespace: CastReceiverChannel.connectionNamespace,
        sourceId: _senderId,
        destinationId: _receiverId,
        payload: CastReceiverChannel.buildConnect(),
      );

      _startHeartbeat();
      _connected = true;
      _connectedIp = ip;
      return true;
    } catch (_) {
      await _cleanup();
      return false;
    }
  }

  void _onMessage(CastMessage msg) {
    try {
      final payload = jsonDecode(msg.payloadUtf8) as Map<String, dynamic>;
      if (CastReceiverChannel.isPong(payload)) return;
    } catch (_) {}
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_channel == null) return;
      try {
        _channel!.sendMessage(
          namespace: CastReceiverChannel.heartbeatNamespace,
          sourceId: _senderId,
          destinationId: _receiverId,
          payload: CastReceiverChannel.buildPing(),
        );
      } catch (_) {}
    });
  }

  Future<Map<String, dynamic>> _getStatus() async {
    final completer = Completer<Map<String, dynamic>>();
    late StreamSubscription<CastMessage> sub;

    sub = _channel!.messageStream.listen((msg) {
      try {
        final payload = jsonDecode(msg.payloadUtf8) as Map<String, dynamic>;
        if (msg.namespace_ == CastReceiverChannel.receiverNamespace &&
            payload['type'] == 'RECEIVER_STATUS') {
          if (!completer.isCompleted) {
            completer.complete(payload);
            sub.cancel();
          }
        }
      } catch (_) {}
    });

    final rid = _nextRid();
    _channel!.sendMessage(
      namespace: CastReceiverChannel.receiverNamespace,
      sourceId: _senderId,
      destinationId: _receiverId,
      payload: jsonEncode({
        'type': 'GET_STATUS',
        'requestId': rid,
      }),
    );

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        sub.cancel();
        throw TimeoutException('GET_STATUS timed out');
      },
    );
  }

  int _ridCounter = 0;
  int _nextRid() => ++_ridCounter;

  void _sendSetVolume(double level) {
    _channel?.sendMessage(
      namespace: CastReceiverChannel.receiverNamespace,
      sourceId: _senderId,
      destinationId: _receiverId,
      payload: jsonEncode({
        'type': 'SET_VOLUME',
        'volume': {'level': level},
        'requestId': _nextRid(),
      }),
    );
  }

  Future<bool> sendVolumeUp() async {
    if (!_connected) return false;
    try {
      final status = await _getStatus();
      final vol = status['status']?['volume']?['level'] ?? 0.5;
      final newLevel = (vol as num).toDouble() + 0.05;
      _sendSetVolume(newLevel.clamp(0.0, 1.0));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendVolumeDown() async {
    if (!_connected) return false;
    try {
      final status = await _getStatus();
      final vol = status['status']?['volume']?['level'] ?? 0.5;
      final newLevel = (vol as num).toDouble() - 0.05;
      _sendSetVolume(newLevel.clamp(0.0, 1.0));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendMute() async {
    if (!_connected) return false;
    try {
      final status = await _getStatus();
      final muted = status['status']?['volume']?['muted'] ?? false;
      if (muted == true) {
        _channel?.sendMessage(
          namespace: CastReceiverChannel.receiverNamespace,
          sourceId: _senderId,
          destinationId: _receiverId,
          payload: jsonEncode({
            'type': 'SET_VOLUME',
            'volume': {'muted': false},
            'requestId': _nextRid(),
          }),
        );
      } else {
        _channel?.sendMessage(
          namespace: CastReceiverChannel.receiverNamespace,
          sourceId: _senderId,
          destinationId: _receiverId,
          payload: jsonEncode({
            'type': 'SET_VOLUME',
            'volume': {'muted': true},
            'requestId': _nextRid(),
          }),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendPlayPause() async => false;
  Future<bool> sendStop() async => false;

  // Chromecast (non-Google-TV) has no navigable UI
  Future<bool> sendDpadUp() async => false;
  Future<bool> sendDpadDown() async => false;
  Future<bool> sendDpadLeft() async => false;
  Future<bool> sendDpadRight() async => false;
  Future<bool> sendDpadSelect() async => false;

  Future<void> disconnect() async {
    await _cleanup();
  }

  Future<void> _cleanup() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _msgSub?.cancel();
    _msgSub = null;
    await _channel?.close();
    _channel = null;
    _connected = false;
    _connectedIp = null;
  }
}
