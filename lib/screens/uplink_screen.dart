import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/weather_data.dart';
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
    });
    try {
      final data = await _service.fetchUplinkData(onLog: _log);
      setState(() => _data = data);
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

  Widget _readout(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.dim),
          Text(value, style: AppText.label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return TerminalScaffold(
      title: 'Uplink // OSINT Intelligence',
      accent: AppColors.hazard,
      backgroundAsset: AppAssets.terminalBackground,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            ExecuteButton(
              label: 'INITIALIZE_SATELLITE_UPLINK',
              color: AppColors.hazard,
              busy: _loading,
              onPressed: _run,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 130,
              child: TerminalLog(lines: _logLines, controller: _logScroll),
            ),
            const SizedBox(height: 10),
            if (d != null)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: hudPanelDecoration(borderColor: AppColors.hazard, glow: 0.2),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NETWORK_IDENTITY', style: AppText.hazardLabel),
                        _readout('WAN_IP', d.publicIp),
                        _readout('ISP_ASN', d.isp),
                        _readout('CITY', d.city.toUpperCase()),
                        _readout('REGION', d.region.toUpperCase()),
                        const SizedBox(height: 14),
                        Text('ATMOSPHERIC_GRID', style: AppText.hazardLabel),
                        _readout('LAT/LON',
                            '${d.latitude?.toStringAsFixed(4) ?? '--'}, ${d.longitude?.toStringAsFixed(4) ?? '--'}'),
                        _readout('TEMP_C', d.tempC?.toStringAsFixed(1) ?? '--'),
                        _readout('HUMIDITY_PCT', d.humidityPct?.toStringAsFixed(0) ?? '--'),
                        _readout('PRESSURE_HPA', d.pressureHpa?.toStringAsFixed(1) ?? '--'),
                        _readout('WIND_KPH', d.windSpeedKph?.toStringAsFixed(1) ?? '--'),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
