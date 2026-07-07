import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/battery_service.dart';
import '../widgets/battery_node_row.dart';
import '../widgets/dashboard_tile.dart';
import 'nethack_screen.dart';
import 'radar_screen.dart';
import 'uplink_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _batteryService = BatteryService();
  int _nodes = 0;

  @override
  void initState() {
    super.initState();
    _batteryService.nodeLevelStream().listen((n) {
      if (mounted) setState(() => _nodes = n);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // PLACEHOLDER SLOT: drop assets/images/dashboard_bg.png to skin
          // the dashboard with your own art. See AppAssets + README.
          Image.asset(
            AppAssets.dashboardBackground,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: AppColors.background),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('PROJECT_MARCUS // HOME_TERMINAL', style: AppText.title),
                  const SizedBox(height: 24),
                  BatteryNodeRow(litNodes: _nodes),
                  const SizedBox(height: 6),
                  Text('BOTNET_POWER_ARRAY', style: AppText.dim),
                  const SizedBox(height: 40),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        DashboardTile(
                          label: 'NetHack',
                          icon: Icons.wifi_tethering,
                          accent: AppColors.cyan,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const NetHackScreen())),
                        ),
                        // ---------------------------------------------
                        // FEATURE_SLOT_04 -- swap this tile to change
                        // what the 4th app launches. Currently wired to
                        // the BLE signal radar (RadarScreen). See
                        // services/ble_radar_service.dart for the design
                        // constraints before extending it.
                        // ---------------------------------------------
                        DashboardTile(
                          label: 'Radar',
                          icon: Icons.sensors,
                          accent: AppColors.warningYellow,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const RadarScreen())),
                        ),
                        DashboardTile(
                          label: 'Uplink',
                          icon: Icons.satellite_alt,
                          accent: AppColors.hazard,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const UplinkScreen())),
                        ),
                        DashboardTile(
                          label: 'System',
                          icon: Icons.terminal,
                          accent: AppColors.glitchGrey,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
