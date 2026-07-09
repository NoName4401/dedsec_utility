import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AndroidTvService {
  SecureSocket? _socket;
  StreamSubscription? _sub;
  List<int>? _serverNonce;
  Uint8List? _savedSecret; // ignore: unused_field
  String? _connectedIp;
  bool _connectionReady = false;

  static const _keyCodes = {
    'PowerOff': 26,
    'VolumeUp': 24,
    'VolumeDown': 25,
    'Mute': 91,
    'Home': 3,
    'Back': 4,
    'Up': 19,
    'Down': 20,
    'Left': 21,
    'Right': 22,
    'Select': 23,
    'PlayPause': 85,
    'Stop': 86,
  };

  bool get needsPairing => _serverNonce != null && !_connectionReady;
  bool get isConnected => _connectionReady;
  String? get connectedIp => _connectedIp;

  Future<bool> connect(String ip) async {
    disconnect();

    final prefs = await SharedPreferences.getInstance();
    final hex = prefs.getString('atv_secret_$ip');
    if (hex != null && hex.length >= 32) {
      _savedSecret = Uint8List.fromList(_hexDecode(hex));
    }

    try {
      _socket = await SecureSocket.connect(ip, 6466,
          onBadCertificate: (_) => true, timeout: const Duration(seconds: 5));
      _connectedIp = ip;
      _serverNonce = null;
      _connectionReady = false;

      final completer = Completer<bool>();
      final buffer = BytesBuilder();

      _sub = _socket!.listen(
        (chunk) {
          buffer.add(chunk);
          _processBuffer(buffer, completer);
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete(false);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(false);
        },
      );

      return completer.future.timeout(const Duration(seconds: 10));
    } catch (_) {
      return false;
    }
  }

  void _processBuffer(BytesBuilder buffer, Completer<bool> completer) {
    final data = buffer.takeBytes();
    while (data.length >= 4) {
      final msgLen =
          ByteData.sublistView(Uint8List.fromList(data.sublist(0, 4)))
              .getUint32(0, Endian.big);
      if (data.length < 4 + msgLen) break;
      final msg = data.sublist(4, 4 + msgLen);
      _parseMessage(msg, completer);
      data.removeRange(0, 4 + msgLen);
      if (data.isEmpty) return;
    }
    if (data.isNotEmpty) buffer.add(data);
  }

  void _parseMessage(List<int> data, Completer<bool> completer) {
    try {
      final type = _readProtoVarint(data, 0);
      if (type == null) return;
      final msgType = type.value;

      if (msgType == 1) {
        // PAIRING_REQUEST — field 2 = server_nonce
        _serverNonce = _extractBytes(data, 2);
        if (!completer.isCompleted) completer.complete(false);
      } else if (msgType == 2) {
        _connectionReady = true;
        if (!completer.isCompleted) completer.complete(true);
      }
    } catch (_) {}
  }

  Future<bool> pair(String pin) async {
    if (_socket == null || _serverNonce == null) return false;

    try {
      final serverNonce = _serverNonce!;
      final clientNonce = List<int>.generate(16, (_) => Random().nextInt(256));
      final pinHash = sha256.convert(pin.codeUnits).bytes.sublist(0, 16);
      final secretKey = Uint8List.fromList(pinHash);

      // HMAC-SHA256(serverNonce || clientNonce, secretKey)
      final hmacInput = Uint8List.fromList([...serverNonce, ...clientNonce]);
      final signature = Hmac(sha256, secretKey).convert(hmacInput).bytes;

      // AES-128-ECB encrypt secretKey with key = SHA256(serverNonce)[:16]
      final aesKey = sha256.convert(serverNonce).bytes.sublist(0, 16);
      final encryptedSecret =
          _aesEcbEncrypt(secretKey, Uint8List.fromList(aesKey));

      // Build PAIRING_RESPONSE protobuf
      final body = <int>[];
      _writeProtoVarint(body, (1 << 3) | 0); // tag field 1 (varint)
      _writeProtoVarint(body, 2); // type = PAIRING_RESPONSE

      // client_nonce, field 2 (bytes = length-delimited)
      _writeProtoVarint(body, (2 << 3) | 2);
      _writeProtoVarint(body, clientNonce.length);
      body.addAll(clientNonce);

      // signature, field 3 (bytes)
      _writeProtoVarint(body, (3 << 3) | 2);
      _writeProtoVarint(body, signature.length);
      body.addAll(signature);

      // secret, field 4 (bytes)
      _writeProtoVarint(body, (4 << 3) | 2);
      _writeProtoVarint(body, encryptedSecret.length);
      body.addAll(encryptedSecret);

      // Frame: 4-byte big-endian length
      final frame = [0, 0, 0, 0];
      frame[0] = (body.length >> 24) & 0xFF;
      frame[1] = (body.length >> 16) & 0xFF;
      frame[2] = (body.length >> 8) & 0xFF;
      frame[3] = body.length & 0xFF;
      frame.addAll(body);

      _socket!.add(frame);

      // Wait for server to accept pairing
      await Future.delayed(const Duration(seconds: 3));

      if (_connectionReady) {
        _savedSecret = secretKey;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('atv_secret_$_connectedIp', _hexEncode(pinHash));
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Uint8List _aesEcbEncrypt(Uint8List plaintext, Uint8List key) {
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      ECBBlockCipher(AESEngine()),
    );
    cipher.init(
      true,
      PaddedBlockCipherParameters(
        KeyParameter(key),
        null,
      ),
    );
    return Uint8List.fromList(cipher.process(plaintext));
  }

  Future<bool> sendKey(String action) async {
    if (_socket == null || !_connectionReady) return false;
    final code = _keyCodes[action];
    if (code == null) return false;
    try {
      _socket!.add(_buildKeyEventBytes(code, true));
      await Future.delayed(const Duration(milliseconds: 50));
      _socket!.add(_buildKeyEventBytes(code, false));
      return true;
    } catch (_) {
      return false;
    }
  }

  Uint8List _buildKeyEventBytes(int keyCode, bool down) {
    // Build a KEY_EVENT protobuf (type = 3)
    final payload = <int>[];
    _writeProtoVarint(payload, (1 << 3) | 0); // tag field 1 (varint)
    _writeProtoVarint(payload, 3); // type = KEY_EVENT

    // key_event, field 4 (length-delimited)
    final ke = <int>[];
    // key_code, field 1 (varint)
    _writeProtoVarint(ke, (1 << 3) | 0);
    _writeProtoVarint(ke, keyCode);
    // action, field 2 (varint): 0 = DOWN, 1 = UP
    _writeProtoVarint(ke, (2 << 3) | 0);
    _writeProtoVarint(ke, down ? 0 : 1);

    _writeProtoVarint(payload, (4 << 3) | 2);
    _writeProtoVarint(payload, ke.length);
    payload.addAll(ke);

    // Frame
    final frame = Uint8List(4 + payload.length);
    frame.buffer.asByteData().setUint32(0, payload.length, Endian.big);
    frame.setRange(4, frame.length, payload);
    return frame;
  }

  // ── Protobuf helpers ──

  ({int value, int pos})? _readProtoVarint(List<int> data, int pos) {
    int value = 0;
    int shift = 0;
    while (pos < data.length) {
      final byte = data[pos++];
      value |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) return (value: value, pos: pos);
      shift += 7;
      if (shift > 63) return null;
    }
    return null;
  }

  /// Extract bytes content from a protobuf field by field number.
  /// Assumes fields appear in order (typical for these small messages).
  List<int>? _extractBytes(List<int> data, int targetField) {
    int pos = 0;
    while (pos < data.length) {
      final r = _readProtoVarint(data, pos);
      if (r == null) return null;
      final tag = r.value;
      pos = r.pos;
      final fn = tag >> 3;
      final wt = tag & 0x07;
      if (fn == targetField && wt == 2) {
        final lenR = _readProtoVarint(data, pos);
        if (lenR == null) return null;
        pos = lenR.pos;
        return data.sublist(pos, pos + lenR.value);
      }
      if (wt == 0) {
        final vr = _readProtoVarint(data, pos);
        if (vr == null) return null;
        pos = vr.pos;
      } else if (wt == 2) {
        final lr = _readProtoVarint(data, pos);
        if (lr == null) return null;
        pos = lr.pos + lr.value;
      } else {
        return null;
      }
    }
    return null;
  }

  void _writeProtoVarint(List<int> buf, int value) {
    while (value > 0x7F) {
      buf.add((value & 0x7F) | 0x80);
      value >>= 7;
    }
    buf.add(value);
  }

  String _hexEncode(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  List<int> _hexDecode(String hex) {
    final result = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }

  void disconnect() {
    _sub?.cancel();
    _socket?.close();
    _socket = null;
    _serverNonce = null;
    _connectionReady = false;
  }

  void dispose() => disconnect();
}
