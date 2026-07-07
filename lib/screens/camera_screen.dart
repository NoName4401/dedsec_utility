import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import '../theme/app_theme.dart';
import '../services/camera_service.dart';
import '../widgets/terminal_scaffold.dart';

class CameraScreen extends StatefulWidget {
  final String cameraIp;

  const CameraScreen({super.key, required this.cameraIp});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _cameraService = CameraService();
  VlcPlayerController? _vlcController;
  final List<String> _feedLogs = [];
  String _connectionStatus = 'INITIALIZING_FEED_OVERRIDE...';
  bool _initialized = false;
  String? _resolvedRtspUrl;

  @override
  void initState() {
    super.initState();
    _establishVideoUplink();
  }

  Future<void> _establishVideoUplink() async {
    _log('[INIT] SEARCHING STREAM PATHS FOR TARGET: ${widget.cameraIp}');

    // Scan and isolate the active media gateway string
    final streamUrl = await _cameraService.identifyStreamPath(widget.cameraIp);
    _resolvedRtspUrl = streamUrl;

    if (streamUrl == null) {
      setState(() => _connectionStatus = 'UPLINK_FAILURE // NO_VALID_STREAM_PATH');
      return;
    }

    _log('[CONNECT] UPLINK LINK MATCH FOUND :: $streamUrl');
    _log('[EXECUTE] ATTEMPTING DECODER HANDSHAKE OVER PORT 554...');

    // Initialize the GPU-accelerated video player instance
    _vlcController = VlcPlayerController.network(
      streamUrl,
      hwAcc: HwAcc.full, // Force full hardware graphics acceleration
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.liveCaching(150), // Ultra-low latency buffer (150ms)
        ]),
        rtp: VlcRtpOptions([
          '--rtsp-tcp', // Force RTSP over TCP instead of UDP to prevent dropped frame lines
        ]),
      ),
    );

    _vlcController!.addOnInitListener(() {
      if (mounted) {
        setState(() {
          _initialized = true;
          _connectionStatus = 'FEED_STABLE // OVERRIDE_OK';
        });
        _log('[SUCCESS] ctOS SURVEILLANCE LAYER INTERCEPTED.');
      }
    });

    _vlcController!.addOnInitListener(() {
      if (mounted) {
        setState(() {
          _initialized = true;
          _connectionStatus = 'FEED_STABLE // OVERRIDE_OK';
        });
        _log('[SUCCESS] ctOS SURVEILLANCE LAYER INTERCEPTED.');
      }
    });

    // 🟢 REPLACED OUTDATED METHOD WITH STANDARD VALUE STATE LISTENER
    _vlcController!.addListener(() {
      if (!mounted) return;

      // If the controller value drops into an error state, flag the terminal log
      if (_vlcController!.value.hasError) {
        _log('[ERROR] DECODER HANDSHAKE TERMINATED BY TARGET HOST.');
        setState(() {
          _initialized = false;
          _connectionStatus = 'CONNECTION_LOST // REJECTED';
        });
      }
    });
  }

  void _log(String line) {
    if (mounted) setState(() => _feedLogs.add(line));
  }

  @override
  void dispose() {
    _vlcController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TerminalScaffold(
      title: 'Override // Surveillance Matrix',
      accent: AppColors.hazard,
      backgroundAsset: AppAssets.terminalBackground,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // 1. DYNAMIC FEED VIEWER CONTAINER
            Container(
              height: 220,
              width: double.infinity,
              decoration: hudPanelDecoration(borderColor: AppColors.hazard, opacity: 0.15, glitchOffset: 1.0),
              clipBehavior: Clip.antiAlias,
              child: _initialized && _vlcController != null
                  ? VlcPlayer(
                controller: _vlcController!,
                aspectRatio: 16 / 9,
                placeholder: const Center(child: CircularProgressIndicator(color: AppColors.hazard)),
              )
                  : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.videocam_off, color: AppColors.hazard, size: 40),
                    const SizedBox(height: 8),
                    Text(_connectionStatus, style: AppText.label.copyWith(color: AppColors.hazard)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 2. TECH METRICS GRID OVERLAY
            if (_initialized)
              Container(
                padding: const EdgeInsets.all(10),
                color: AppColors.glitchGrey.withOpacity(0.15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('SOURCE: ${widget.cameraIp}', style: AppText.label.copyWith(fontSize: 11, color: AppColors.cyan)),
                    Text('PROTOCOL: RTSP/TCP', style: AppText.label.copyWith(fontSize: 11, color: AppColors.warningYellow)),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // 3. SCROLLING FEED AUDIO/VIDEO CONSOLE LOGS
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.black.withOpacity(0.4),
                child: ListView.builder(
                  itemCount: _feedLogs.length,
                  itemBuilder: (context, idx) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        _feedLogs[idx],
                        style: AppText.dim.copyWith(fontSize: 11, color: Colors.greenAccent, fontFamily: 'monospace'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}