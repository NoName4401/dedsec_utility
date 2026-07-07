import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/lan_device.dart';
import '../services/network_service.dart';
import '../widgets/terminal_scaffold.dart';
import 'camera_screen.dart'; // 🟢 INJECTED CAMERA INTERFACE LINK

class NetHackScreen extends StatefulWidget {
  const NetHackScreen({super.key});

  @override
  State<NetHackScreen> createState() => _NetHackScreenState();
}

class _NetHackScreenState extends State<NetHackScreen> {
  final _service = NetworkService();
  final _logLines = <String>[];
  final _logScroll = ScrollController();
  final _devices = <String, LanDevice>{};
  bool _scanning = false;
  LanDevice? _selectedDevice;

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
      _selectedDevice = null;
    });

    final targetedSubnet = await _service.localSubnetPrefix();
    final localBindingIp = await _service.localIp();
    _log('[DIAGNOSTIC] LOCAL_BINDING_IP=$localBindingIp');
    _log('[DIAGNOSTIC] TARGETING_RANGE=$targetedSubnet.0/24');

    await for (final device in _service.sweepSubnet(onLog: _log)) {
      setState(() {
        _devices[device.ip] = device;
        _selectedDevice ??= device;
      });
    }

    setState(() => _scanning = false);
  }

  Future<void> _scanHostPorts(String ip) async {
    setState(() => _devices[ip]!.scanningPorts = true);
    _log('[EXECUTE_PORT_SCAN] TARGET=$ip');

    final ports = await _service.scanPorts(ip, onLog: _log);

    setState(() {
      final currentDevice = _devices[ip]!;
      currentDevice.openPorts = ports;

      final updatedProfile = _service.calculateDeviceProbability(
          ip,
          ports,
          currentDevice.vendor
      );

      _devices[ip] = LanDevice(
        ip: currentDevice.ip,
        mac: currentDevice.mac,
        vendor: currentDevice.vendor,
        alive: currentDevice.alive,
        profile: updatedProfile,
        openPorts: ports,
        scanningPorts: false,
      );

      if (_selectedDevice?.ip == ip) {
        _selectedDevice = _devices[ip];
      }
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
            const SizedBox(height: 14),

            Expanded(
              child: devices.isEmpty
                  ? Center(
                child: Text(
                  '// NO_ACTIVE_TARGETS_IN_SUBNET\nINITIALIZE SWEEP TO MONITOR TRAFFIC',
                  textAlign: TextAlign.center,
                  style: AppText.dim.copyWith(height: 1.4),
                ),
              )
                  : Column(
                children: [
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: devices.length,
                      itemBuilder: (context, i) {
                        final d = devices[i];
                        final isTarget = _selectedDevice?.ip == d.ip;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedDevice = d),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8, bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isTarget ? AppColors.cyan.withOpacity(0.1) : Colors.transparent,
                              border: Border.all(
                                  color: isTarget ? AppColors.cyan : AppColors.glitchGrey,
                                  width: 1.5
                              ),
                            ),
                            child: Center(
                              child: Text(
                                d.ip.split('.').last,
                                style: AppText.label.copyWith(
                                    color: isTarget ? AppColors.cyan : Colors.white
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_selectedDevice != null) ...[
                    _buildFocusedDossierCard(_selectedDevice!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: AppColors.glitchGrey.withOpacity(0.3),
              child: Text(
                '// LIVE_NETWORK_STREAMS_CONSOLE',
                style: AppText.label.copyWith(fontSize: 10, color: AppColors.cyan, letterSpacing: 1.5),
              ),
            ),
            SizedBox(
              height: 90,
              child: TerminalLog(lines: _logLines, controller: _logScroll),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusedDossierCard(LanDevice d) {
    // Check if device matches unmasked surveillance signature
    final bool isCameraTarget = d.profile.occupation.contains('SURVEILLANCE CAMERA');

    return Expanded(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: hudPanelDecoration(borderColor: AppColors.cyan, glow: 0.15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text('TARGET_HOST: ${d.ip}', style: AppText.label.copyWith(fontSize: 16, color: Colors.white)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: d.ip.endsWith('.1') ? AppColors.hazard.withOpacity(0.2) : Colors.transparent,
                      border: Border.all(
                        color: d.ip.endsWith('.1') ? AppColors.hazard : AppColors.glitchGrey,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      d.profile.riskFactor,
                      style: AppText.label.copyWith(fontSize: 10, color: d.ip.endsWith('.1') ? AppColors.hazard : AppColors.glitchGrey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(2.5),
                },
                children: [
                  TableRow(children: [
                    Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('HARDWARE_ID:', style: AppText.dim)),
                    Text(d.mac ?? "FF:FF:FF:FF:FF:FF", style: AppText.label.copyWith(fontSize: 13)),
                  ]),
                  TableRow(children: [
                    Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('OUI_VENDOR:', style: AppText.dim)),
                    Text(d.vendor, style: AppText.label.copyWith(color: AppColors.cyan, fontSize: 13)),
                  ]),
                  TableRow(children: [
                    Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('CLASSIFY:', style: AppText.dim)),
                    Text(d.profile.occupation, style: AppText.label.copyWith(fontSize: 13)),
                  ]),
                ],
              ),
              const Divider(color: AppColors.glitchGrey, height: 20),

              Text('// INTERCEPTED_DIAGNOSTICS', style: AppText.dim.copyWith(fontSize: 10, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text(d.profile.diagnosticFact, style: AppText.label.copyWith(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 20),

              if (d.openPorts.isNotEmpty) ...[
                Text('OPEN_PORT_LISTENERS:', style: AppText.label.copyWith(fontSize: 11, color: AppColors.hazard)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: d.openPorts
                      .map((p) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.hazard.withOpacity(0.05),
                      border: Border.all(color: AppColors.hazard, width: 1.5),
                    ),
                    child: Text(
                      '${p.port} // ${p.label}',
                      style: AppText.hazardLabel.copyWith(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ))
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],

              // Dynamic Tactical Actions Row
              Column(
                children: [
                  ExecuteButton(
                    label: d.scanningPorts ? 'MAPPING_PORT_SOCKETS...' : 'SCAN_CORE_PORTS',
                    color: AppColors.warningYellow,
                    busy: d.scanningPorts,
                    onPressed: () => _scanHostPorts(d.ip),
                  ),

                  // =============================================
                  // DYNAMIC INTERCEPT NODE: CAMERA FEED ENTRYWAY
                  // =============================================
                  if (isCameraTarget) ...[
                    const SizedBox(height: 10),
                    ExecuteButton(
                      label: 'OVERRIDE_CAMERA_FEED',
                      color: AppColors.hazard,
                      onPressed: () {
                        _log('[EXECUTE_OVERRIDE] RE-ROUTING TO TARGET VIEWPORT COORD...');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CameraScreen(cameraIp: d.ip),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}