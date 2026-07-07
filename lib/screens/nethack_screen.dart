import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/lan_device.dart';
import '../services/network_service.dart';
import '../widgets/terminal_scaffold.dart';

class NetHackScreen extends StatefulWidget {
  const NetHackScreen({super.key});

  @override
  State<NetHackScreen> createState() => _NetHackScreenState();
}

class _NetHackScreenState extends State<NetHackScreen> {
  final _service = NetworkService();
  final _logLines = <String>[];
  final _logScroll = ScrollController();
  final _devices = <String, LanDevice>{}; // keyed by ip
  bool _scanning = false;

  void _log(String line) {
    setState(() => _logLines.add(line));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _runSweep() async {
    setState(() {
      _scanning = true;
      _logLines.clear();
      _devices.clear();
    });

    await for (final device in _service.sweepSubnet(onLog: _log)) {
      setState(() => _devices[device.ip] = device);
    }

    setState(() => _scanning = false);
  }

  Future<void> _scanHostPorts(String ip) async {
    setState(() => _devices[ip]!.scanningPorts = true);
    _log('[EXECUTE_PORT_SCAN] TARGET=$ip');
    final ports = await _service.scanPorts(ip, onLog: _log);
    setState(() {
      _devices[ip]!.openPorts = ports;
      _devices[ip]!.scanningPorts = false;
    });
    _log('[PORT_SCAN_COMPLETE] $ip :: ${ports.length} OPEN');
  }

  @override
  void dispose() {
    _logScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final devices = _devices.values.toList();
    return TerminalScaffold(
      title: 'NetHack // Diagnostic Scanner',
      accent: AppColors.cyan,
      backgroundAsset: AppAssets.terminalBackground,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            ExecuteButton(
              label: 'EXECUTE_NETWORK_SWEEP',
              busy: _scanning,
              onPressed: _runSweep,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 120,
              child: TerminalLog(lines: _logLines, controller: _logScroll),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: devices.isEmpty
                  ? Center(child: Text('NO_TARGETS_YET', style: AppText.dim))
                  : ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (context, i) {
                        final d = devices[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: hudPanelDecoration(
                              borderColor: AppColors.cyan, glow: 0.15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('IP: ${d.ip}', style: AppText.label),
                              const SizedBox(height: 4),
                              Text('VENDOR: ${d.vendor}', style: AppText.dim),
                              const SizedBox(height: 8),
                              if (d.openPorts.isNotEmpty)
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: d.openPorts
                                      .map((p) => Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: AppColors.hazard),
                                            ),
                                            child: Text(
                                              '${p.port}/${p.label}',
                                              style: AppText.hazardLabel
                                                  .copyWith(fontSize: 11),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              const SizedBox(height: 8),
                              ExecuteButton(
                                label: d.scanningPorts
                                    ? 'SCANNING...'
                                    : 'SCAN_PORTS',
                                color: AppColors.warningYellow,
                                busy: d.scanningPorts,
                                onPressed: () => _scanHostPorts(d.ip),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
