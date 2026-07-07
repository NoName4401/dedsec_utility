import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/satellite_target.dart';
import '../services/osint_service.dart';
import '../widgets/terminal_scaffold.dart';

class UplinkScreen extends StatefulWidget {
  const UplinkScreen({super.key});

  @override
  State<UplinkScreen> createState() => _UplinkScreenState();
}

class _UplinkScreenState extends State<UplinkScreen> {
  final _service = OsintService();
  final _logLines = <String>[];
  final _logScroll = ScrollController();
  UplinkData? _data;
  bool _loading = false;
  SatelliteTarget? _selectedSatellite;

  void _log(String line) {
    setState(() => _logLines.add(line));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _logLines.clear();
      _data = null;
      _selectedSatellite = null;
    });
    try {
      final data = await _service.fetchUplinkData(onLog: _log);
      setState(() {
        _data = data;
        if (data.overheadSatellites.isNotEmpty) {
          _selectedSatellite = data.overheadSatellites.first;
        }
      });
    } catch (e) {
      _log('[ERROR] UPLINK_FAILED: $e');
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _logScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return TerminalScaffold(
      title: 'Uplink // Orbital Reconnaissance',
      accent: AppColors.hazard,
      backgroundAsset: AppAssets.terminalBackground,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            ExecuteButton(
              label: 'ESTABLISH_ORBITAL_LINK',
              color: AppColors.hazard,
              busy: _loading,
              onPressed: _run,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: TerminalLog(lines: _logLines, controller: _logScroll),
            ),
            const SizedBox(height: 12),

            if (d != null) ...[
              // BASE LOCATION STATUS STRIP
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                color: AppColors.glitchGrey.withOpacity(0.2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STATION_ORIGIN: ${d.city.toUpperCase()}, ${d.region.toUpperCase()} (IP: ${d.publicIp})',
                        style: AppText.label.copyWith(fontSize: 11, color: AppColors.cyan)),
                    const SizedBox(height: 2),
                    Text('MATRIX_LOCK: LAT ${d.latitude.toStringAsFixed(4)} // LON ${d.longitude.toStringAsFixed(4)}',
                        style: AppText.dim.copyWith(fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // EXPANDED AEROSPACE TRACKER PANEL
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT SIDE: SATELLITE PICKER COLUMN
                    SizedBox(
                      width: 130,
                      child: ListView.builder(
                        itemCount: d.overheadSatellites.length,
                        itemBuilder: (context, idx) {
                          final sat = d.overheadSatellites[idx];
                          final isTarget = _selectedSatellite?.noradId == sat.noradId;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedSatellite = sat),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isTarget ? AppColors.hazard.withOpacity(0.08) : Colors.transparent,
                                border: Border.all(color: isTarget ? AppColors.hazard : AppColors.glitchGrey, width: 1.5),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sat.name, style: AppText.label.copyWith(fontSize: 11, color: isTarget ? AppColors.hazard : Colors.white)),
                                  Text('ID: ${sat.noradId}', style: AppText.dim.copyWith(fontSize: 9)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),

                    // RIGHT SIDE: DYNAMIC TELEMETRY DISPLAY PANEL
                    if (_selectedSatellite != null) ...[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: hudPanelDecoration(borderColor: AppColors.hazard, glow: 0.15),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_selectedSatellite!.name, style: AppText.label.copyWith(fontSize: 15, color: Colors.white)),
                                Text(_selectedSatellite!.classification, style: AppText.dim.copyWith(fontSize: 10, color: AppColors.hazard)),
                                const Divider(color: AppColors.glitchGrey, height: 16),

                                _specRow('NORAD_ID', _selectedSatellite!.noradId),
                                _specRow('DOWN_FREQ', '${_selectedSatellite!.frequencyMhz.toStringAsFixed(3)} MHz'),
                                _specRow('ALTITUDE', '${_selectedSatellite!.altitudeKm.toStringAsFixed(1)} KM'),
                                _specRow('VELOCITY', '${_selectedSatellite!.velocityKmh.toStringAsFixed(0)} KM/H'),
                                const Divider(color: AppColors.glitchGrey, height: 16),

                                Text('// ANTENNA_TARGET_VECTORS', style: AppText.dim.copyWith(fontSize: 9, color: AppColors.cyan)),
                                const SizedBox(height: 6),
                                _specRow('AZIMUTH', '${_selectedSatellite!.azimuth.toStringAsFixed(1)}°'),
                                _specRow('ELEVATION', '${_selectedSatellite!.elevation.toStringAsFixed(1)}°'),
                                const SizedBox(height: 10),

                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  color: _selectedSatellite!.downlinkStatus == 'LOCK_STABLE'
                                      ? Colors.green.withOpacity(0.15)
                                      : AppColors.warningYellow.withOpacity(0.15),
                                  child: Center(
                                    child: Text(
                                      _selectedSatellite!.downlinkStatus,
                                      style: AppText.label.copyWith(
                                          fontSize: 10,
                                          color: _selectedSatellite!.downlinkStatus == 'LOCK_STABLE' ? Colors.greenAccent : AppColors.warningYellow
                                      ),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      )
                    ]
                  ],
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _specRow(String key, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$key:', style: AppText.dim.copyWith(fontSize: 11)),
          Text(val, style: AppText.label.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}