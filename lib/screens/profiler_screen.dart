import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/profile_hit.dart';
import '../services/identity_scanner_service.dart';
import '../widgets/terminal_scaffold.dart';

class ProfilerScreen extends StatefulWidget {
  const ProfilerScreen({super.key});

  @override
  State<ProfilerScreen> createState() => _ProfilerScreenState();
}

class _ProfilerScreenState extends State<ProfilerScreen> {
  final _service = IdentityScannerService();
  final _inputController = TextEditingController();
  final _logLines = <String>[];
  final _logScroll = ScrollController();
  StreamSubscription<ProfileHit>? _scanSub;
  final _hits = <ProfileHit>[];
  final _allResults = <ProfileHit>[];
  bool _scanning = false;
  bool _fuzzMode = false;

  void _log(String line) {
    setState(() => _logLines.add(line));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _startScan() async {
    final username = _inputController.text.trim();
    if (username.isEmpty) {
      _log('[!] INPUT_EMPTY :: ENTER A TARGET IDENTITY');
      return;
    }

    setState(() {
      _scanning = true;
      _logLines.clear();
      _hits.clear();
      _allResults.clear();
    });

    _log('// ═══════════════════════════════════════════');
    _log('//  DEDSEC IDENTITY PROFILER v2.4.1');
    _log('// ═══════════════════════════════════════════');
    _log('');

    _scanSub = _service.scan(
      baseUsername: username,
      fuzzMode: _fuzzMode,
      onLog: _log,
    ).listen(
      (hit) {
        setState(() {
          _allResults.add(hit);
          if (hit.found) _hits.add(hit);
        });
      },
      onDone: () {
        setState(() => _scanning = false);
        _log('');
        _log('// TARGET_DOSIER: ${_hits.length} PROFILES ACQUIRED');
        if (_hits.isNotEmpty) {
          _log('// ACCESS LINKS AVAILABLE BELOW');
        }
      },
      onError: (e) {
        _log('[!] SCAN_FAILURE :: $e');
        setState(() => _scanning = false);
      },
    );
  }

  void _stopScan() {
    _scanSub?.cancel();
    _scanSub = null;
    _log('');
    _log('// PROFILER TERMINATED BY OPERATOR');
    _log('[STATS] HITS=${_hits.length} :: PROBES=${_allResults.length}');
    setState(() => _scanning = false);
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _inputController.dispose();
    _logScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TerminalScaffold(
      title: 'Profiler // Identity Scanner',
      accent: AppColors.cyan,
      backgroundAsset: AppAssets.terminalBackground,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // ── INPUT SECTION ──
            _buildInputSection(),
            const SizedBox(height: 12),

            // ── EXECUTE BUTTON ──
            ExecuteButton(
              label: _scanning ? 'TERMINATE_SCAN' : 'INITIALIZE_PROFILER',
              color: _scanning ? AppColors.hazard : AppColors.cyan,
              busy: false,
              onPressed: _scanning ? _stopScan : _startScan,
            ),
            const SizedBox(height: 12),

            // ── RESULTS SUMMARY ──
            if (_allResults.isNotEmpty) ...[
              _buildStatsBar(),
              const SizedBox(height: 10),
            ],

            // ── RESULTS LIST ──
            Expanded(
              child: _allResults.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _logScroll,
                      itemCount: _allResults.length,
                      itemBuilder: (context, i) {
                        final hit = _allResults[i];
                        return hit.found
                            ? _buildHitCard(hit)
                            : _buildMissCard(hit);
                      },
                    ),
            ),
            const SizedBox(height: 10),

            // ── TERMINAL LOG ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: AppColors.glitchGrey.withOpacity(0.3),
              child: Text(
                '// LIVE_OSINT_CONSOLE',
                style: AppText.label.copyWith(fontSize: 10, color: AppColors.cyan, letterSpacing: 1.5),
              ),
            ),
            SizedBox(
              height: 70,
              child: TerminalLog(lines: _logLines, controller: _logScroll),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: hudPanelDecoration(borderColor: AppColors.cyan, opacity: 0.15, glitchOffset: 1.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('// TARGET_IDENTITY_INPUT', style: AppText.dim.copyWith(fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          TextField(
            controller: _inputController,
            enabled: !_scanning,
            style: AppText.label.copyWith(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'ENTER_BASE_USERNAME',
              hintStyle: AppText.dim.copyWith(fontSize: 14),
              filled: true,
              fillColor: AppColors.background.withOpacity(0.8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: const BorderSide(color: AppColors.glitchGrey, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: const BorderSide(color: AppColors.glitchGrey, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onSubmitted: (_) => _scanning ? null : _startScan(),
          ),
          const SizedBox(height: 10),

          // ── FUZZY PERMUTATION TOGGLE ──
          Row(
            children: [
              GestureDetector(
                onTap: _scanning ? null : () => setState(() => _fuzzMode = !_fuzzMode),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _fuzzMode ? AppColors.cyan.withOpacity(0.15) : Colors.transparent,
                    border: Border.all(
                      color: _fuzzMode ? AppColors.cyan : AppColors.glitchGrey,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _fuzzMode ? Icons.toggle_on : Icons.toggle_off,
                        color: _fuzzMode ? AppColors.cyan : AppColors.glitchGrey,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'DEEP_SCAN // FUZZY_PERMUTATIONS',
                        style: AppText.label.copyWith(
                          fontSize: 11,
                          color: _fuzzMode ? AppColors.cyan : AppColors.glitchGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (_fuzzMode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.warningYellow, width: 1),
                  ),
                  child: Text(
                    '${IdentityScannerService.generatePermutations(_inputController.text.isEmpty ? "A" : _inputController.text.trim()).length} VARIANTS',
                    style: AppText.dim.copyWith(fontSize: 9, color: AppColors.warningYellow),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final hitCount = _hits.length;
    final missCount = _allResults.length - hitCount;
    final total = _allResults.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: hudPanelDecoration(
        borderColor: hitCount > 0 ? AppColors.cyan : AppColors.glitchGrey,
        opacity: 0.15,
        glitchOffset: 1.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statChip('PROBES', '$total', AppColors.cyan),
          _statChip('HITS', '$hitCount', hitCount > 0 ? AppColors.cyan : AppColors.glitchGrey),
          _statChip('MISS', '$missCount', AppColors.glitchGrey),
          _statChip('HIT_RATE', '${total > 0 ? ((hitCount / total) * 100).toStringAsFixed(1) : 0}%', AppColors.warningYellow),
        ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '// NO_IDENTITY_DATA',
            style: AppText.dim.copyWith(fontSize: 14, letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          Text(
            'ENTER A USERNAME AND INITIALIZE THE PROFILER\nTO BEGIN OPEN-SOURCE INTELLIGENCE GATHERING',
            textAlign: TextAlign.center,
            style: AppText.dim.copyWith(height: 1.6, fontSize: 11),
          ),
        ],
      ),
    );
  }

  /// MISS card: compact, dim, minimal vertical footprint.
  Widget _buildMissCard(ProfileHit hit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          Text(
            '[ MISS ]',
            style: AppText.dim.copyWith(fontSize: 10, color: AppColors.glitchGrey),
          ),
          const SizedBox(width: 8),
          Text(
            hit.platform,
            style: AppText.dim.copyWith(fontSize: 10),
          ),
          const Spacer(),
          Text(
            '@${hit.username}',
            style: AppText.dim.copyWith(fontSize: 9),
          ),
          const SizedBox(width: 8),
          Text(
            'HTTP ${hit.statusCode}',
            style: AppText.dim.copyWith(fontSize: 9, color: AppColors.glitchGrey.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  /// HIT card: prominent, cyan border, actionable link button.
  Widget _buildHitCard(ProfileHit hit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: hudPanelDecoration(
        borderColor: AppColors.cyan,
        opacity: 0.2,
        glitchOffset: 1.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withOpacity(0.15),
                  border: Border.all(color: AppColors.cyan, width: 1),
                ),
                child: Text(
                  '[ HIT: TARGET ACQUIRED ]',
                  style: AppText.label.copyWith(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              Text(
                'HTTP ${hit.statusCode}',
                style: AppText.dim.copyWith(fontSize: 10, color: AppColors.cyan),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── PLATFORM + USERNAME ──
          Row(
            children: [
              Text('PLATFORM:', style: AppText.dim.copyWith(fontSize: 11)),
              const SizedBox(width: 8),
              Text(hit.platform, style: AppText.label.copyWith(fontSize: 13, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('IDENTITY:', style: AppText.dim.copyWith(fontSize: 11)),
              const SizedBox(width: 8),
              Text('@${hit.username}', style: AppText.label.copyWith(fontSize: 13, color: AppColors.cyan)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('ENDPOINT:', style: AppText.dim.copyWith(fontSize: 11)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hit.url,
                  style: AppText.dim.copyWith(fontSize: 10, color: AppColors.warningYellow),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── ACTION BUTTON ──
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _launchUrl(hit.url),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.cyan, width: 1.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(
                '[ ACCESS EXTERNAL PROFILE ]',
                style: AppText.label.copyWith(fontSize: 12, color: AppColors.cyan),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
