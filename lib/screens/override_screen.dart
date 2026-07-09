import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/bluetooth_hid_service.dart';
import '../widgets/terminal_scaffold.dart';

class OverrideScreen extends StatefulWidget {
  const OverrideScreen({super.key});

  @override
  State<OverrideScreen> createState() => _OverrideScreenState();
}

class _OverrideScreenState extends State<OverrideScreen> {
  final _service = BluetoothHidService();
  final _random = Random();
  bool _initializing = false;
  bool _injecting = false;
  bool _discovering = false;
  double _injectionProgress = 0;
  String _currentStep = '';
  StreamSubscription<PayloadProgress>? _injectionSub;
  Timer? _hexTimer;
  final _hexLines = <String>[];
  final _hexScroll = ScrollController();
  bool _injectionComplete = false;
  List<HidDevice> _discovered = [];

  @override
  void initState() {
    super.initState();
    _service.connectionState.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.connectionState.removeListener(_onStateChanged);
    _service.dispose();
    _injectionSub?.cancel();
    _hexTimer?.cancel();
    _hexScroll.dispose();
    super.dispose();
  }

  String _genHexLine() =>
      List.generate(50, (_) => '0123456789ABCDEF'[_random.nextInt(16)]).join(' ');

  void _startHexRain() {
    _hexLines.clear();
    _hexTimer = Timer.periodic(const Duration(milliseconds: 35), (_) {
      if (!mounted) return;
      setState(() {
        _hexLines.insert(0, _genHexLine());
        if (_hexLines.length > 80) _hexLines.removeLast();
      });
    });
  }

  Future<void> _initHid() async {
    setState(() => _initializing = true);
    await _service.initialize();
    if (mounted) setState(() => _initializing = false);
  }

  void _discover() {
    setState(() => _discovering = true);
    _discovered.clear();
    _service.discoverDevices();
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _discovered = List.from(_service.devices.value);
        _discovering = false;
      });
      _service.stopDiscovery();
    });
  }

  void _pairAndConnect(HidDevice device) {
    _service.pairDevice(device.address);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _service.connectToDevice(device.address);
    });
  }

  void _disconnectHid() {
    _service.disconnect();
  }

  void _inject(HidPayload payload) {
    _injectionComplete = false;
    _injectionProgress = 0;
    _currentStep = 'INITIALIZING_HID_STREAM...';
    _injecting = true;
    _startHexRain();

    _injectionSub = _service.inject(payload).listen(
      (p) {
        if (!mounted) return;
        setState(() {
          _injectionProgress = p.progress;
          _currentStep = p.step;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _injectionProgress = 1.0;
          _currentStep = 'PAYLOAD_COMMITTED';
          _injectionComplete = true;
        });
        _hexTimer?.cancel();
      },
    );
  }

  void _dismissInjection() {
    _injectionSub?.cancel();
    _hexTimer?.cancel();
    setState(() {
      _injecting = false;
      _injectionProgress = 0;
      _currentStep = '';
      _hexLines.clear();
      _injectionComplete = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TerminalScaffold(
      title: 'Override // HID Injector',
      accent: AppColors.cyan,
      child: Stack(
        children: [
          _buildContent(),
          if (_injecting) _buildInjectionOverlay(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final connState = _service.state;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _buildHidStatusPanel(connState),
          if (connState == HidConnectionState.disconnected) ...[
            const SizedBox(height: 12),
            _buildDiscoverySection(),
          ],
          if (connState == HidConnectionState.connected && _service.connectedDevice.value != null) ...[
            const SizedBox(height: 10),
            _buildConnectedDeviceCard(),
          ],
          const SizedBox(height: 12),
          Expanded(child: _buildPayloadGrid()),
          const SizedBox(height: 10),
          _buildTerminalFooter(),
        ],
      ),
    );
  }

  Widget _buildHidStatusPanel(HidConnectionState state) {
    final (label, color) = switch (state) {
      HidConnectionState.disconnected => ('AWAITING PAIRING', AppColors.glitchGrey),
      HidConnectionState.pairing => ('ESTABLISHING LINK...', AppColors.warningYellow),
      HidConnectionState.connected => ('LINK ESTABLISHED', AppColors.cyan),
      HidConnectionState.unavailable => ('HID UNAVAILABLE (API < 28)', AppColors.chromaticRed),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: hudPanelDecoration(borderColor: color, opacity: 0.2, glitchOffset: 1.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)],
                ),
              ),
              const SizedBox(width: 10),
              Text('[ BLUETOOTH HID STATUS ]',
                  style: AppText.label.copyWith(color: AppColors.cyan, fontSize: 11, letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('STATUS:: ', style: AppText.dim.copyWith(fontSize: 12)),
              Text(label, style: AppText.label.copyWith(color: color, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          ExecuteButton(
            label: state == HidConnectionState.connected
                ? 'HID_LINK_ACTIVE'
                : state == HidConnectionState.unavailable
                    ? 'HID_NOT_SUPPORTED'
                    : 'INITIALIZE_BLUETOOTH_SPOOF',
            busy: _initializing || state == HidConnectionState.pairing,
            color: color,
            onPressed: state == HidConnectionState.disconnected ? _initHid : () {},
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverySection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: hudPanelDecoration(borderColor: AppColors.warningYellow, opacity: 0.15, glitchOffset: 1.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('// NEARBY_DEVICES', style: AppText.dim.copyWith(fontSize: 10, letterSpacing: 1.5)),
              const Spacer(),
              if (_discovered.isNotEmpty)
                Text('${_discovered.length} FOUND', style: AppText.dim.copyWith(fontSize: 9)),
            ],
          ),
          const SizedBox(height: 10),
          ExecuteButton(
            label: _discovering ? 'SCANNING...' : 'SCAN_FOR_DEVICES',
            busy: _discovering,
            color: AppColors.warningYellow,
            onPressed: _discovering ? () {} : _discover,
          ),
          if (_discovered.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView.builder(
                itemCount: _discovered.length,
                itemBuilder: (_, i) {
                  final d = _discovered[i];
                  return GestureDetector(
                    onTap: () => _pairAndConnect(d),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.glitchGrey, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.bluetooth, color: AppColors.cyan, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(d.name, style: AppText.label.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis),
                          ),
                          Text(d.address, style: AppText.dim.copyWith(fontSize: 9)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectedDeviceCard() {
    final dev = _service.connectedDevice.value!;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.cyan, width: 1.5),
        color: AppColors.cyan.withValues(alpha: 0.05),
      ),
      child: Row(
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cyan,
              boxShadow: [BoxShadow(color: AppColors.cyan.withValues(alpha: 0.8), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CONNECTED TO:', style: AppText.dim.copyWith(fontSize: 9)),
                Text(dev.name, style: AppText.label.copyWith(fontSize: 13, color: AppColors.cyan)),
                Text(dev.address, style: AppText.dim.copyWith(fontSize: 9)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _disconnectHid,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.hazard, width: 1),
              ),
              child: Text('DISCONNECT', style: AppText.hazardLabel.copyWith(fontSize: 9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayloadGrid() {
    return ListView.separated(
      itemCount: BluetoothHidService.availablePayloads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final payload = BluetoothHidService.availablePayloads[i];
        return _PayloadCard(
          payload: payload,
          onInject: () => _inject(payload),
        );
      },
    );
  }

  Widget _buildTerminalFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: AppColors.glitchGrey.withValues(alpha: 0.3),
      child: Text(
        '// HID_KEYSTREAM_MONITOR :: STANDBY',
        style: AppText.label.copyWith(fontSize: 10, color: AppColors.cyan, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildInjectionOverlay() {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (_hexLines.isNotEmpty)
                  ListView.builder(
                    controller: _hexScroll,
                    itemCount: _hexLines.length,
                    itemBuilder: (_, i) {
                      final opacity = (1.0 - i / _hexLines.length).clamp(0.1, 1.0);
                      return Text(
                        _hexLines[i],
                        style: TextStyle(
                          fontFamily: 'monospace', fontSize: 10,
                          color: AppColors.cyan.withValues(alpha: opacity * 0.5), height: 1.0,
                        ),
                      );
                    },
                  ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [AppColors.background.withValues(alpha: 0.0), AppColors.background],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildInjectionProgressPanel(),
        ],
      ),
    );
  }

  Widget _buildInjectionProgressPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: _injectionComplete ? AppColors.cyan : AppColors.hazard,
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '> $_currentStep',
            style: AppText.label.copyWith(
              color: _injectionComplete ? AppColors.cyan : AppColors.hazard,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _injectionProgress),
            duration: const Duration(milliseconds: 200),
            builder: (_, value, __) => ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: AppColors.nodeEmpty,
                valueColor: AlwaysStoppedAnimation(
                  _injectionComplete ? AppColors.cyan : AppColors.hazard,
                ),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('${(_injectionProgress * 100).toStringAsFixed(0)}%', style: AppText.dim.copyWith(fontSize: 11)),
          const SizedBox(height: 12),
          if (_injectionComplete)
            ExecuteButton(label: 'DISMISS', color: AppColors.cyan, onPressed: _dismissInjection),
        ],
      ),
    );
  }
}

class _PayloadCard extends StatelessWidget {
  final HidPayload payload;
  final VoidCallback onInject;

  const _PayloadCard({required this.payload, required this.onInject});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: hudPanelDecoration(borderColor: payload.accent, opacity: 0.15, glitchOffset: 1.5),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('> EXECUTE ', style: AppText.dim.copyWith(fontSize: 12)),
              Text(payload.scriptLabel,
                  style: AppText.label.copyWith(color: payload.accent, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(payload.description, style: AppText.dim.copyWith(fontSize: 11, height: 1.3)),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: payload.accent.withValues(alpha: 0.4), width: 1),
                  color: payload.accent.withValues(alpha: 0.05),
                ),
                child: Text(payload.id,
                    style: AppText.label.copyWith(color: payload.accent, fontSize: 9, letterSpacing: 1)),
              ),
              const Spacer(),
              SizedBox(
                width: 180,
                child: ExecuteButton(label: 'INJECT_PAYLOAD', color: payload.accent, onPressed: onInject),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
