import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/wardrive_target.dart';
import '../services/wifi_scanner_service.dart';
import '../widgets/terminal_scaffold.dart';

class WardriveScreen extends StatefulWidget {
  const WardriveScreen({super.key});

  @override
  State<WardriveScreen> createState() => _WardriveScreenState();
}

class _WardriveScreenState extends State<WardriveScreen> {
  final _service = WifiScannerService();
  final _logLines = <String>[];
  final _logScroll = ScrollController();
  List<WardriveTarget> _targets = [];
  bool _scanning = false;
  bool _permissionsOk = false;
  int _sweepCount = 0;
  WardriveTarget? _selected;

  void _log(String line) {
    setState(() => _logLines.add(line));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _logLines.clear();
      _targets.clear();
      _selected = null;
      _sweepCount = 0;
    });

    _log('// INITIALIZING 802.11 RF_FRONTEND...');
    _permissionsOk = await _service.requestPermissions();

    if (!_permissionsOk) {
      _log('[!] ACCESS_FINE_LOCATION :: DENIED');
      _log('[!] WARDRIVE ABORTED :: PERMISSION_GATE BLOCKED');
      setState(() => _scanning = false);
      return;
    }

    _log('[OK] ACCESS_FINE_LOCATION :: GRANTED');

    final canScan = await _service.canScan();
    if (!canScan) {
      _log('[!] HARDWARE_RF :: UNAVAILABLE');
      _log('[!] Wi-Fi chipset does not support active scanning');
      setState(() => _scanning = false);
      return;
    }

    _log('[OK] HARDWARE_RF :: CHIPSET_READY');
    _log('// BEGINNING CONTINUOUS RF_SWEEP...');
    _log('');

    _service.startSweep(
      interval: const Duration(seconds: 4),
      onResults: (results) {
        _sweepCount++;
        results.sort((a, b) => b.rssi.compareTo(a.rssi));

        final newCount = results.length;
        final vulnCount = results.where((t) => t.isVulnerable).length;

        _log('[SWEEP::$_sweepCount] $newCount TARGETS MAPPED :: $vulnCount VULNERABLE');

        setState(() {
          _targets = results;
        });
      },
    );
  }

  void _stopScan() {
    _service.stopSweep();
    _log('');
    _log('// RF_SWEEP TERMINATED');
    _log('[STATS] TOTAL_SWEEPS=$_sweepCount :: TARGETS=${_targets.length}');
    setState(() => _scanning = false);
  }

  @override
  void dispose() {
    _service.stopSweep();
    _logScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vulnCount = _targets.where((t) => t.isVulnerable).length;
    final wepCount = _targets.where((t) => t.isWep).length;
    final openCount = _targets.where((t) => t.isOpen).length;

    return TerminalScaffold(
      title: 'Wardrive // 802.11 Spectrum',
      accent: AppColors.warningYellow,
      backgroundAsset: AppAssets.terminalBackground,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // ── EXECUTE BUTTON ──
            ExecuteButton(
              label: _scanning ? 'TERMINATE_RF_SWEEP' : 'INITIALIZE_WARDRIVE',
              color: _scanning ? AppColors.hazard : AppColors.warningYellow,
              busy: false,
              onPressed: _scanning ? _stopScan : _startScan,
            ),
            const SizedBox(height: 10),

            // ── SCAN STATS BAR ──
            if (_scanning || _targets.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: hudPanelDecoration(
                  borderColor: AppColors.warningYellow,
                  opacity: 0.15,
                  glitchOffset: 1.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statChip('TARGETS', '${_targets.length}', AppColors.cyan),
                    _statChip('OPEN', '$openCount', openCount > 0 ? AppColors.hazard : AppColors.glitchGrey),
                    _statChip('WEP', '$wepCount', wepCount > 0 ? AppColors.hazard : AppColors.glitchGrey),
                    _statChip('VULN', '$vulnCount', vulnCount > 0 ? AppColors.hazard : AppColors.glitchGrey),
                    _statChip('SWEEP', '$_sweepCount', AppColors.warningYellow),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // ── MAIN TARGET LIST ──
            Expanded(
              child: _targets.isEmpty
                  ? Center(
                      child: Text(
                        '// NO_RF_SIGNATURES_DETECTED\nINITIALIZE SWEEP TO MAP LOCAL SPECTRUM',
                        textAlign: TextAlign.center,
                        style: AppText.dim.copyWith(height: 1.6),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _targets.length,
                      itemBuilder: (context, i) => _buildTargetCard(_targets[i]),
                    ),
            ),
            const SizedBox(height: 10),

            // ── TERMINAL LOG ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: AppColors.glitchGrey.withOpacity(0.3),
              child: Text(
                '// LIVE_RF_CONSOLE',
                style: AppText.label.copyWith(fontSize: 10, color: AppColors.warningYellow, letterSpacing: 1.5),
              ),
            ),
            SizedBox(
              height: 80,
              child: TerminalLog(lines: _logLines, controller: _logScroll),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: AppText.label.copyWith(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: AppText.dim.copyWith(fontSize: 8, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildTargetCard(WardriveTarget t) {
    final isVuln = t.isVulnerable;
    final isSelected = _selected?.bssid == t.bssid;
    final borderColor = isVuln ? AppColors.hazard : (isSelected ? AppColors.warningYellow : AppColors.glitchGrey);

    return GestureDetector(
      onTap: () => setState(() => _selected = isSelected ? null : t),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: hudPanelDecoration(
          borderColor: borderColor,
          opacity: isVuln ? 0.2 : 0.1,
          glitchOffset: 1.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ROW: SSID + SIGNAL ──
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.ssid,
                    style: AppText.label.copyWith(
                      color: isVuln ? AppColors.hazard : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _rssiColor(t.rssi).withOpacity(0.15),
                    border: Border.all(color: _rssiColor(t.rssi), width: 1),
                  ),
                  child: Text(
                    '[ RSSI: ${t.rssi} dBm ]',
                    style: AppText.label.copyWith(
                      fontSize: 10,
                      color: _rssiColor(t.rssi),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── BSSID / HARDWARE ADDRESS ──
            Text(
              '[ BSSID: ${t.bssid} ]',
              style: AppText.dim.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 6),

            // ── FREQUENCY + CHANNEL ──
            Row(
              children: [
                _infoTag('FREQ', t.frequencyBand, AppColors.cyan),
                const SizedBox(width: 8),
                _infoTag('CH', '${t.channel}', AppColors.cyan),
                const SizedBox(width: 8),
                _infoTag('SIGNAL', '${t.signalQuality}%', _signalQualityColor(t.signalQuality)),
              ],
            ),
            const SizedBox(height: 8),

            // ── ENCRYPTION / CRYPTO LAYER ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isVuln ? AppColors.hazard.withOpacity(0.15) : AppColors.surface,
                    border: Border.all(
                      color: isVuln ? AppColors.hazard : AppColors.glitchGrey,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '[ CRYPTO_LAYER: ${t.cryptoLayer} ]',
                    style: AppText.label.copyWith(
                      fontSize: 11,
                      color: isVuln ? AppColors.hazard : AppColors.cyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            // ── THREAT CLASSIFICATION ──
            if (isVuln) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                color: AppColors.hazard.withOpacity(0.08),
                child: Text(
                  '[ THREAT: ${t.threatClassification} ]',
                  style: AppText.hazardLabel.copyWith(fontSize: 10),
                ),
              ),
            ],

            // ── EXPANDED DOSSIER ──
            if (isSelected) ...[
              const Divider(color: AppColors.glitchGrey, height: 16),
              _dossierRow('NETWORK_SSID', t.ssid),
              _dossierRow('BSSID_HARDWARE', t.bssid),
              _dossierRow('FREQUENCY_MHZ', '${t.frequency} MHz'),
              _dossierRow('CHANNEL_WIDTH', '${t.channel}'),
              _dossierRow('SIGNAL_RAW', '${t.rssi} dBm'),
              _dossierRow('SIGNAL_QUALITY', '${t.signalQuality}%'),
              _dossierRow('CRYPTO_STANDARD', t.cryptoLayer),
              _dossierRow('THREAT_LEVEL', t.threatClassification),
              _dossierRow('RAW_CAPABILITIES', t.capabilities),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoTag(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        '$label: $value',
        style: AppText.dim.copyWith(fontSize: 10, color: color),
      ),
    );
  }

  Widget _dossierRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: AppText.dim.copyWith(fontSize: 11)),
          ),
          Expanded(
            child: Text(value, style: AppText.label.copyWith(fontSize: 11, color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Color _rssiColor(int rssi) {
    if (rssi >= -50) return AppColors.cyan;
    if (rssi >= -65) return AppColors.warningYellow;
    if (rssi >= -75) return AppColors.hazard;
    return AppColors.chromaticRed;
  }

  Color _signalQualityColor(int quality) {
    if (quality >= 80) return AppColors.cyan;
    if (quality >= 50) return AppColors.warningYellow;
    if (quality >= 25) return AppColors.hazard;
    return AppColors.chromaticRed;
  }
}
