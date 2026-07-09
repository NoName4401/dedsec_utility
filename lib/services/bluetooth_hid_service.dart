import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

enum HidConnectionState { disconnected, pairing, connected, unavailable }

class HidDevice {
  final String name;
  final String address;
  final int bondState;
  const HidDevice({required this.name, required this.address, this.bondState = 0});
}

class PayloadProgress {
  final double progress;
  final String step;
  const PayloadProgress(this.progress, this.step);
}

class HidPayload {
  final String id;
  final String name;
  final String description;
  final String scriptLabel;
  final Color accent;
  final List<String> injectionSteps;
  final String typedPayload;

  const HidPayload({
    required this.id,
    required this.name,
    required this.description,
    required this.scriptLabel,
    required this.accent,
    required this.injectionSteps,
    required this.typedPayload,
  });
}

class BluetoothHidService {
  static const _channel = MethodChannel('dedsec/bluetooth_hid');
  static const _eventChannel = EventChannel('dedsec/bluetooth_hid_events');

  final _connectionState =
      ValueNotifier<HidConnectionState>(HidConnectionState.disconnected);
  final _random = Random();
  final _devices = ValueNotifier<List<HidDevice>>([]);
  final _bondeDevices = ValueNotifier<List<HidDevice>>([]);
  final _connectedDevice = ValueNotifier<HidDevice?>(null);
  StreamSubscription? _eventSub;

  ValueNotifier<HidConnectionState> get connectionState => _connectionState;
  HidConnectionState get state => _connectionState.value;
  ValueNotifier<List<HidDevice>> get devices => _devices;
  ValueNotifier<List<HidDevice>> get bondedDevices => _bondeDevices;
  ValueNotifier<HidDevice?> get connectedDevice => _connectedDevice;

  BluetoothHidService() {
    _eventSub = _eventChannel.receiveBroadcastStream().listen(_handleEvent);
  }

  void _handleEvent(dynamic event) {
    final map = event as Map<String, dynamic>;
    final type = map['type'] as String;
    final data = map['data'];

    switch (type) {
      case 'connected':
        final d = data as Map<String, dynamic>;
        _connectedDevice.value = HidDevice(
          name: d['deviceName'] as String? ?? 'UNKNOWN',
          address: d['deviceAddress'] as String? ?? '',
        );
        _connectionState.value = HidConnectionState.connected;
        break;
      case 'disconnected':
        _connectedDevice.value = null;
        _connectionState.value = HidConnectionState.disconnected;
        break;
      case 'connecting':
        _connectionState.value = HidConnectionState.pairing;
        break;
      case 'deviceList':
        final list = (data as List).map((d) => HidDevice(
          name: d['name'] as String? ?? 'UNKNOWN',
          address: d['address'] as String? ?? '',
          bondState: d['bondState'] as int? ?? 0,
        )).toList();
        _devices.value = list;
        break;
      case 'appStatus':
        final registered = (data as Map<String, dynamic>)['registered'] as bool? ?? false;
        if (!registered) {
          _connectionState.value = HidConnectionState.unavailable;
        }
        break;
      case 'profileReady':
        break;
      case 'pairing':
        _connectionState.value = HidConnectionState.pairing;
        break;
      case 'scanComplete':
        break;
    }
  }

  Future<bool> initialize() async {
    try {
      _connectionState.value = HidConnectionState.pairing;
      final result = await _channel.invokeMethod<bool>('initialize');
      if (result == true) {
        await _loadBonded();
        return true;
      }
      _connectionState.value = HidConnectionState.unavailable;
      return false;
    } on MissingPluginException {
      _connectionState.value = HidConnectionState.unavailable;
      return false;
    } catch (e) {
      _connectionState.value = HidConnectionState.unavailable;
      return false;
    }
  }

  Future<bool> discoverDevices() async {
    try {
      return await _channel.invokeMethod<bool>('discoverDevices') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopDiscovery() async {
    try {
      return await _channel.invokeMethod<bool>('stopDiscovery') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> pairDevice(String address) async {
    try {
      return await _channel.invokeMethod<bool>('pairDevice', {'address': address}) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> connectToDevice(String address) async {
    try {
      return await _channel.invokeMethod<bool>('connectToDevice', {'address': address}) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> disconnect() async {
    try {
      _connectedDevice.value = null;
      _connectionState.value = HidConnectionState.disconnected;
      return await _channel.invokeMethod<bool>('disconnect') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<int> sendKeys(String text) async {
    try {
      return await _channel.invokeMethod<int>('sendKeys', {'text': text}) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> release() async {
    try {
      return await _channel.invokeMethod<bool>('release') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadBonded() async {
    try {
      final list = await _channel.invokeMethod<List>('getBondedDevices');
      if (list != null) {
        _bondeDevices.value = list.map((d) => HidDevice(
          name: (d as Map)['name'] as String? ?? 'UNKNOWN',
          address: d['address'] as String? ?? '',
        )).toList();
      }
    } catch (_) {}
  }

  Stream<PayloadProgress> inject(HidPayload payload) async* {
    final steps = payload.injectionSteps;
    final text = payload.typedPayload;

    for (int i = 0; i < steps.length; i++) {
      await Future.delayed(
        Duration(milliseconds: 200 + _random.nextInt(300)),
      );
      yield PayloadProgress((i + 1) / steps.length, steps[i]);
    }

    if (text.isNotEmpty && _connectionState.value == HidConnectionState.connected) {
      await sendKeys(text);
    }
  }

  void dispose() {
    _eventSub?.cancel();
    _connectionState.dispose();
    _devices.dispose();
    _bondeDevices.dispose();
    _connectedDevice.dispose();
    release();
  }

  static const availablePayloads = [
    HidPayload(
      id: 'PAYLOAD_01',
      name: 'GHOST_TYPER',
      description:
          'Opens notepad and renders a DedSec ASCII signature via HID keystream.',
      scriptLabel: './ghost_typer.sh',
      accent: AppColors.cyan,
      typedPayload: 'notepad\n'
          ' _   _ _       _         ___ _ _            _   ___     _            _     _          _   _     _     _     _ \n'
          '| \\ | (_)     | |       /_\\ | (_)_ _   ___| |_/ __| __(_)___ _ _  __| |___| |_  ___ _| |_(_)___| |_  | |_  _ _ __ _ \n'
          '|  \\| | | _  _| |_____ / _ \\| | | \' \\ / -_)  _\\__ \\/ _| / -_) \' \\/ _` / -_)  _|/ _ \'|  _| / -_)  _| |  _| || | \'  \\ |\n'
          '|_|\\__|_||_|(_)_|     /_/ \\_\\_|_|_||_|\\___|\\__|___/\\__|_\\___|_||_\\__,_\\___|\\__|\\___/_|\\__|_\\___|\\__|  \\__|\\_,_|_|_|_|\n'
          '                                                                              \n'
          '                         NIGHT OF THE LIVING DEDSEC                           \n'
          '                    ��  ��  ��  SYSTEM COMPROMISED  ��  ��  ��                    \n',
      injectionSteps: [
        'INITIALIZING_HID_STACK...',
        'REGISTERING_KEYBOARD_DESCRIPTOR...',
        'SENDING_MODIFIER: WIN_KEY',
        'KEYSTROKE: n-o-t-e-p-a-d',
        'KEYSTROKE: RETURN',
        'WAITING_500ms_FOR_BUFFER_FLUSH',
        'INJECTING_ASCII_PAYLOAD...',
        'RENDERING: NIGHT_OF_THE_LIVING_DEDSEC',
        'FLUSHING_KEYSTREAM_BUFFER',
        'PAYLOAD_COMMITTED',
      ],
    ),
    HidPayload(
      id: 'PAYLOAD_02',
      name: 'RICKROLL_OVERRIDE',
      description:
          'Fires Win+R, injects a YouTube URL into the run dialog and executes.',
      scriptLabel: './rickroll_override.sh',
      accent: AppColors.hazard,
      typedPayload: 'https://youtu.be/dQw4w9WgXcQ\n',
      injectionSteps: [
        'HOOKING_WIN_R_HOTKEY...',
        'SENDING_MODIFIER: WIN_KEY + R_KEY',
        'WAITING_RUN_DIALOG_OPEN',
        'INJECTING_URL: youtu.be/dQw4w9WgXcQ',
        'KEYSTROKE: RETURN',
        'BROWSER_LAUNCH_CONFIRMED',
        'HID_STREAM_CLOSED',
      ],
    ),
    HidPayload(
      id: 'PAYLOAD_03',
      name: 'PHANTOM_NOTE',
      description:
          'Simulated credential exfiltration demo — no data actually collected.',
      scriptLabel: './phantom_note.sh',
      accent: AppColors.warningYellow,
      typedPayload: '',
      injectionSteps: [
        'SCANNING_MOUNTED_VOLUMES...',
        'IDENTIFYING_TARGET_FILES: *.kdbx, *.txt, *.cfg',
        'BYPASSING_USER_ACCESS_CONTROL...',
        'CREATING_HIDDEN_DIR: /dev/null/.sys/.cache/',
        'DEPLOYING_KEYSTROKE_LOGGER...',
        'ESTABLISHING_SESSION_HOOK: chrome.exe',
        'INTERCEPTING_FORM_SUBMISSIONS...',
        'EXFILTRATING_TO_REMOTE_NODE...',
        'WIPING_LOCAL_ACCESS_LOGS',
        'PAYLOAD_ACTIVE_AT_BOOT',
      ],
    ),
    HidPayload(
      id: 'PAYLOAD_04',
      name: 'THE_DESTROYER',
      description:
          'Simulated system file erasure — no actual destruction performed.',
      scriptLabel: './the_destroyer.sh',
      accent: AppColors.chromaticRed,
      typedPayload: '',
      injectionSteps: [
        'ELEVATING_PRIVILEGES...',
        'MAPPING_SYSTEM_DIRECTORIES...',
        'BYPASSING_WINDOWS_DEFENDER...',
        'TARGETING: C:\\Windows\\System32\\config\\SAM',
        'EXECUTING_FILE_DELETION...',
        'DISABLING_SYSTEM_RESTORE...',
        'CORRUPTING_BOOT_CONFIGURATION...',
        'PURGING_EVENT_LOGS...',
        'system_INTEGRITY_COMPROMISED',
        'SHUTDOWN_SEQUENCE_INITIATED',
      ],
    ),
  ];
}
