import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/battery_service.dart';
import '../widgets/battery_node_circle.dart'; // IMPORT NEW CIRCULAR WIDGET
import '../widgets/dashboard_tile.dart';
import 'nethack_screen.dart';
import 'radar_screen.dart';
import 'uplink_screen.dart';
import 'toolkit_screen.dart';
import 'wardrive_screen.dart';
import 'profiler_screen.dart';
import 'override_screen.dart';
import 'iot_exploit_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _batteryService = BatteryService();
  double _batteryPercentage = 1.0; // Range 0.0 - 1.0

  @override
  void initState() {
    super.initState();
    _batteryService.batteryLevelStream().listen((pct) {
      if (mounted) setState(() => _batteryPercentage = pct);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Updated default skin binding
          Image.asset(
            AppAssets.dashboardBackground,
            fit: BoxFit.cover,
            // Fallback to pure background if the asset image isn't found
            errorBuilder: (_, __, ___) => Container(color: AppColors.background),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('DedSec // HOME_TERMINAL', style: AppText.title),
                  const SizedBox(height: 12),

                  // =============================================
                  // NEW CIRCULAR BOTNET INDICATOR SOCKET
                  // =============================================
                  SizedBox(
                    height: 140,
                    child: BatteryNodeCircle(percentage: _batteryPercentage),
                  ),

                  const SizedBox(height: 10),
                  Text('BOTNET_POWER_ARRAY', style: AppText.dim),
                  const SizedBox(height: 30),

                  // Grid View layout remains unchanged
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
                          label: 'Toolkit',
                          icon: Icons.terminal,
                          accent: AppColors.cyan,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const ToolkitScreen())),
                        ),
                        DashboardTile(
                          label: 'Wardrive',
                          icon: Icons.cell_tower,
                          accent: AppColors.warningYellow,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const WardriveScreen())),
                        ),
                        DashboardTile(
                          label: 'Profiler',
                          icon: Icons.person_search,
                          accent: AppColors.cyan,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const ProfilerScreen())),
                        ),
                        DashboardTile(
                          label: 'Override',
                          icon: Icons.bluetooth,
                          accent: AppColors.hazard,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const OverrideScreen())),
                        ),
                        DashboardTile(
                          label: 'IoT Exploit',
                          icon: Icons.settings_remote,
                          accent: AppColors.hazard,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const IotExploitScreen())),
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