import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:asn1lib/asn1lib.dart' as asn1;
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AtvPairingState {
  checkingCache,
  generatingCerts,
  pairHandshake,
  requestingPin,
  pairing,
  paired,
  failed,
}

class AndroidTvPairingManager {
  final String ip;
  final FlutterSecureStorage secureStorage;

  AtvPairingState _state = AtvPairingState.checkingCache;
  final StreamController<AtvPairingState> _stateCtrl =
      StreamController<AtvPairingState>.broadcast();
  Stream<AtvPairingState> get stateStream => _stateCtrl.stream;
  AtvPairingState get state => _state;

  String? _failureDetail;
  String? get failureDetail => _failureDetail;

  String? _certPem;
  String? _keyPem;

  // Socket for pairing handshake — port 6467 only
  SecureSocket? _pairSocket;
  StreamSubscription? _pairSub;
  bool _pairReady = false;
  List<int>? _serverNonce;

  AndroidTvPairingManager(this.ip, this.secureStorage);

  static const _keyCodes = <String, int>{
    'PowerOff': 26, 'VolumeUp': 24, 'VolumeDown': 25,
    'Mute': 91, 'Home': 3, 'Back': 4,
    'Up': 19, 'Down': 20, 'Left': 21, 'Right': 22, 'Select': 23,
    'PlayPause': 85, 'Stop': 86,
  };

  void _updateState(AtvPairingState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  // ══════════════════════════════════════════════
  // PUBLIC API
  // ══════════════════════════════════════════════

  /// Loads/generates certs and runs the initial pairing state machine on
  /// port 6467.  Auto-pairs if a secret was saved from a previous session.
  Future<void> start() async {
    _serverNonce = null;
    _pairReady = false;
    _updateState(AtvPairingState.checkingCache);

    _certPem = await secureStorage.read(key: 'atv_cert_$ip');
    _keyPem = await secureStorage.read(key: 'atv_key_$ip');

    if (_keyPem == null || _certPem == null) {
      _updateState(AtvPairingState.generatingCerts);
      try {
        await _generateCerts();
      } catch (e) {
        _failureDetail = 'CERT_GEN_FAILED: $e';
        _updateState(AtvPairingState.failed);
        return;
      }
    }

    // Check for a saved pairing secret
    final prefs = await SharedPreferences.getInstance();
    final savedHex = prefs.getString('atv_secret_$ip');

    if (savedHex != null && savedHex.length >= 32) {
      // Already paired — no need to touch 6467
      _updateState(AtvPairingState.paired);
      return;
    }

    // Need to pair — connect to port 6467
    _updateState(AtvPairingState.pairHandshake);
    try {
      await _connectPair6467();
    } catch (e) {
      _failureDetail = 'PAIR_HANDSHAKE_FAILED: $e';
      _updateState(AtvPairingState.failed);
      return;
    }

    if (_pairReady) {
      _updateState(AtvPairingState.paired);
      return;
    }
    if (_serverNonce == null) {
      _failureDetail = 'NO_PAIRING_REQUEST';
      _updateState(AtvPairingState.failed);
      return;
    }

    _updateState(AtvPairingState.requestingPin);
  }

  /// Called by the UI after the user enters the 6-digit PIN.
  /// Sends the protobuf pairing response on port 6467, then closes it.
  Future<bool> pair(String pin) async {
    if (_pairSocket == null || _serverNonce == null) return false;
    _updateState(AtvPairingState.pairing);

    final pinHash = sha256.convert(pin.codeUnits).bytes.sublist(0, 16);
    final secretKey = Uint8List.fromList(pinHash);

    final ok = await _completePairing(_serverNonce!, secretKey);
    _closePairSocket();

    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('atv_secret_$ip', _hexEncode(pinHash));
      _updateState(AtvPairingState.paired);
      return true;
    }

    _failureDetail = 'PAIRING_ACK_TIMEOUT';
    _updateState(AtvPairingState.failed);
    return false;
  }

  /// Sends a key event over a **fresh** TLS connection to port 6466 using
  /// the same authorized client certificate.  Connection is closed after
  /// sending the DOWN/UP pair.
  Future<bool> sendKey(String action) async {
    final code = _keyCodes[action];
    if (code == null) return false;
    if (_certPem == null || _keyPem == null) return false;

    try {
      final ctx = SecurityContext();
      ctx.useCertificateChainBytes(utf8.encode(_certPem!));
      ctx.usePrivateKeyBytes(utf8.encode(_keyPem!));

      final cmdSock = await SecureSocket.connect(
        ip, 6466,
        context: ctx,
        onBadCertificate: (_) => true,
        timeout: const Duration(seconds: 5),
      );
      try {
        cmdSock.add(_buildKeyEventBytes(code, true));
        await Future.delayed(const Duration(milliseconds: 50));
        cmdSock.add(_buildKeyEventBytes(code, false));
        await Future.delayed(const Duration(milliseconds: 100));
        return true;
      } finally {
        cmdSock.destroy();
      }
    } catch (e) {
      return false;
    }
  }

  // ══════════════════════════════════════════════
  // PAIRING ON PORT 6467
  // ══════════════════════════════════════════════

  Future<void> _connectPair6467() async {
    final ctx = SecurityContext();
    ctx.useCertificateChainBytes(utf8.encode(_certPem!));
    ctx.usePrivateKeyBytes(utf8.encode(_keyPem!));

    _pairSocket = await SecureSocket.connect(
      ip, 6467,
      context: ctx,
      onBadCertificate: (_) => true,
      timeout: const Duration(seconds: 5),
    );

    final completer = Completer<void>();
    final buffer = BytesBuilder();
    _pairSub = _pairSocket!.listen((chunk) {
      buffer.add(chunk);
      _processPairBuffer(buffer, completer);
    }, onError: (_) {
      if (!completer.isCompleted) completer.complete();
    }, onDone: () {
      if (!completer.isCompleted) completer.complete();
    });
    await completer.future.timeout(const Duration(seconds: 10));
  }

  void _processPairBuffer(BytesBuilder buffer, Completer<void> completer) {
    final data = buffer.takeBytes();
    var pos = 0;
    while (data.length - pos >= 4) {
      final len = ByteData.sublistView(
              Uint8List.fromList(data.sublist(pos, pos + 4)))
          .getUint32(0, Endian.big);
      if (data.length - pos < 4 + len) break;
      _parsePairMessage(data.sublist(pos + 4, pos + 4 + len));
      pos += 4 + len;
    }
    if (pos < data.length) buffer.add(data.sublist(pos));
    if (!completer.isCompleted) completer.complete();
  }

  void _parsePairMessage(List<int> data) {
    try {
      final r = _readProtoVarint(data, 0);
      if (r == null) return;
      if (r.value == 1) {
        _serverNonce = _extractBytes(data, 2);
      } else if (r.value == 2) {
        _pairReady = true;
      }
    } catch (_) {}
  }

  Future<bool> _completePairing(List<int> serverNonce, Uint8List secretKey) async {
    try {
      final clientNonce =
          List<int>.generate(16, (_) => math.Random().nextInt(256));
      final hmacInput = Uint8List.fromList([...serverNonce, ...clientNonce]);
      final signature = Hmac(sha256, secretKey).convert(hmacInput).bytes;

      final aesKey = sha256.convert(serverNonce).bytes.sublist(0, 16);
      final encryptedSecret =
          _aesEcbEncrypt(secretKey, Uint8List.fromList(aesKey));

      final body = <int>[];
      _writeProtoVarint(body, (1 << 3) | 0);
      _writeProtoVarint(body, 2);

      _writeProtoVarint(body, (2 << 3) | 2);
      _writeProtoVarint(body, clientNonce.length);
      body.addAll(clientNonce);

      _writeProtoVarint(body, (3 << 3) | 2);
      _writeProtoVarint(body, signature.length);
      body.addAll(signature);

      _writeProtoVarint(body, (4 << 3) | 2);
      _writeProtoVarint(body, encryptedSecret.length);
      body.addAll(encryptedSecret);

      final frame = Uint8List(4 + body.length);
      frame.buffer.asByteData().setUint32(0, body.length, Endian.big);
      frame.setRange(4, frame.length, body);

      _pairSocket!.add(frame);
      await Future.delayed(const Duration(seconds: 3));
      return _pairReady;
    } catch (_) {
      return false;
    }
  }

  void _closePairSocket() {
    _pairSub?.cancel();
    _pairSocket?.close();
    _pairSocket = null;
    _pairSub = null;
  }

  // ══════════════════════════════════════════════
  // RSA-2048 + SELF-SIGNED CERT (unchanged)
  // ══════════════════════════════════════════════

  SecureRandom _createSecureRandom() {
    final rng = FortunaRandom();
    rng.seed(KeyParameter(Uint8List.fromList(
        List<int>.generate(32, (_) => math.Random().nextInt(256)))));
    return rng;
  }

  Future<void> _generateCerts() async {
    final rng = _createSecureRandom();
    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        rng,
      ));
    final pair = keyGen.generateKeyPair();
    final publicKey = pair.publicKey as RSAPublicKey;
    final privateKey = pair.privateKey as RSAPrivateKey;

    final certDer = _buildSelfSignedCert(publicKey, privateKey, rng);
    final keyDer = _encodeRsaPrivateKeyDer(privateKey);

    _certPem = _toPem('CERTIFICATE', certDer);
    _keyPem = _toPem('PRIVATE KEY', keyDer);

    await secureStorage.write(key: 'atv_cert_$ip', value: _certPem!);
    await secureStorage.write(key: 'atv_key_$ip', value: _keyPem!);
  }

  Uint8List _buildSelfSignedCert(
      RSAPublicKey pub, RSAPrivateKey priv, SecureRandom rng) {
    final serial = BigInt.from(DateTime.now().millisecondsSinceEpoch);
    final notBefore = DateTime.now().subtract(const Duration(days: 1));
    final notAfter = notBefore.add(const Duration(days: 3650));
    final tbs = _encodeTbsCert(serial, notBefore, notAfter, pub);
    final sig = _signSha256WithRsa(tbs, priv, rng);
    final seq = asn1.ASN1Sequence()
      ..add(asn1.ASN1Sequence.fromBytes(tbs))
      ..add(_sha256WithRsaAlgoId())
      ..add(asn1.ASN1BitString(sig));
    return seq.encodedBytes;
  }

  Uint8List _encodeTbsCert(
      BigInt serial, DateTime nb, DateTime na, RSAPublicKey pub) {
    final tbs = asn1.ASN1Sequence();
    tbs.add(asn1.ASN1Sequence(tag: 0xA0)
      ..add(asn1.ASN1Integer(BigInt.from(2))));
    tbs.add(asn1.ASN1Integer(serial));
    tbs.add(_sha256WithRsaAlgoId());
    tbs.add(_makeDn('DedSec_ATVRP'));
    tbs.add(asn1.ASN1Sequence()
      ..add(asn1.ASN1UtcTime(nb))
      ..add(asn1.ASN1UtcTime(na)));
    tbs.add(_makeDn('DedSec_ATVRP'));
    tbs.add(_encodeSpki(pub));
    final ext = asn1.ASN1Sequence()
      ..add(asn1.ASN1Sequence()
        ..add(asn1.ASN1ObjectIdentifier.fromComponentString('2.5.29.19'))
        ..add(asn1.ASN1OctetString(
            (asn1.ASN1Sequence()..add(asn1.ASN1Boolean(false)))
                .encodedBytes)));
    tbs.add(asn1.ASN1Sequence(tag: 0xA3)..add(ext));
    return tbs.encodedBytes;
  }

  asn1.ASN1Sequence _encodeSpki(RSAPublicKey key) {
    return asn1.ASN1Sequence()
      ..add(asn1.ASN1Sequence()
        ..add(asn1.ASN1ObjectIdentifier.fromComponentString('1.2.840.113549.1.1.1'))
        ..add(asn1.ASN1Null()))
      ..add(asn1.ASN1BitString(
        (asn1.ASN1Sequence()
              ..add(asn1.ASN1Integer(key.modulus!))
              ..add(asn1.ASN1Integer(key.publicExponent!)))
            .encodedBytes));
  }

  asn1.ASN1Sequence _makeDn(String cn) {
    return asn1.ASN1Sequence()
      ..add(asn1.ASN1Set()
        ..add(asn1.ASN1Sequence()
          ..add(asn1.ASN1ObjectIdentifier.fromComponentString('2.5.4.3'))
          ..add(asn1.ASN1PrintableString(cn))));
  }

  asn1.ASN1Sequence _sha256WithRsaAlgoId() {
    return asn1.ASN1Sequence()
      ..add(
          asn1.ASN1ObjectIdentifier.fromComponentString('1.2.840.113549.1.1.11'))
      ..add(asn1.ASN1Null());
  }

  Uint8List _signSha256WithRsa(
      Uint8List data, RSAPrivateKey priv, SecureRandom rng) {
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(priv));
    return signer.generateSignature(data).bytes;
  }

  Uint8List _encodeRsaPrivateKeyDer(RSAPrivateKey key) {
    final inner = asn1.ASN1Sequence()
      ..add(asn1.ASN1Integer(BigInt.zero))
      ..add(asn1.ASN1Integer(key.modulus!))
      ..add(asn1.ASN1Integer(key.publicExponent!))
      ..add(asn1.ASN1Integer(key.privateExponent!))
      ..add(asn1.ASN1Integer(key.p!))
      ..add(asn1.ASN1Integer(key.q!))
      ..add(asn1.ASN1Integer(key.privateExponent! % (key.p! - BigInt.one)))
      ..add(asn1.ASN1Integer(key.privateExponent! % (key.q! - BigInt.one)))
      ..add(asn1.ASN1Integer(key.q!.modInverse(key.p!)));
    final pkcs8 = asn1.ASN1Sequence()
      ..add(asn1.ASN1Integer(BigInt.zero))
      ..add(asn1.ASN1Sequence()
        ..add(asn1.ASN1ObjectIdentifier.fromComponentString('1.2.840.113549.1.1.1'))
        ..add(asn1.ASN1Null()))
      ..add(asn1.ASN1OctetString(inner.encodedBytes));
    return pkcs8.encodedBytes;
  }

  String _toPem(String label, Uint8List der) {
    final b64 = base64Encode(der);
    final buf = StringBuffer()..writeln('-----BEGIN $label-----');
    for (int i = 0; i < b64.length; i += 64) {
      buf.writeln(
          b64.substring(i, (i + 64 > b64.length) ? b64.length : i + 64));
    }
    buf.writeln('-----END $label-----');
    return buf.toString();
  }

  // ══════════════════════════════════════════════
  // PROTOBUF HELPERS
  // ══════════════════════════════════════════════

  Uint8List _buildKeyEventBytes(int keyCode, bool down) {
    final payload = <int>[];
    _writeProtoVarint(payload, (1 << 3) | 0);
    _writeProtoVarint(payload, 3);
    final ke = <int>[];
    _writeProtoVarint(ke, (1 << 3) | 0);
    _writeProtoVarint(ke, keyCode);
    _writeProtoVarint(ke, (2 << 3) | 0);
    _writeProtoVarint(ke, down ? 0 : 1);
    _writeProtoVarint(payload, (4 << 3) | 2);
    _writeProtoVarint(payload, ke.length);
    payload.addAll(ke);
    final frame = Uint8List(4 + payload.length);
    frame.buffer.asByteData().setUint32(0, payload.length, Endian.big);
    frame.setRange(4, frame.length, payload);
    return frame;
  }

  ({int value, int pos})? _readProtoVarint(List<int> data, int pos) {
    int value = 0, shift = 0;
    while (pos < data.length) {
      final b = data[pos++];
      value |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) return (value: value, pos: pos);
      shift += 7;
      if (shift > 63) return null;
    }
    return null;
  }

  List<int>? _extractBytes(List<int> data, int targetField) {
    int pos = 0;
    while (pos < data.length) {
      final r = _readProtoVarint(data, pos);
      if (r == null) return null;
      final tag = r.value;
      pos = r.pos;
      final fn = tag >> 3, wt = tag & 0x07;
      if (fn == targetField && wt == 2) {
        final lr = _readProtoVarint(data, pos);
        if (lr == null) return null;
        pos = lr.pos;
        return data.sublist(pos, pos + lr.value);
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
    buf.add(value & 0xFF);
  }

  Uint8List _aesEcbEncrypt(Uint8List pt, Uint8List key) {
    final c = PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()));
    c.init(true, PaddedBlockCipherParameters(KeyParameter(key), null));
    return c.process(pt);
  }

  String _hexEncode(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

  void disconnect() {
    _closePairSocket();
    _serverNonce = null;
    _pairReady = false;
  }

  void dispose() {
    disconnect();
    _stateCtrl.close();
  }
}
