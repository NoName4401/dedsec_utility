import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/terminal_scaffold.dart';

class CommandTemplate {
  final String toolName;
  final String syntax;
  final String purpose;
  final String modifierBreakdown;
  final String technicalTheory;

  const CommandTemplate({
    required this.toolName,
    required this.syntax,
    required this.purpose,
    required this.modifierBreakdown,
    required this.technicalTheory,
  });
}

class ToolkitScreen extends StatefulWidget {
  const ToolkitScreen({super.key});

  @override
  State<ToolkitScreen> createState() => _ToolkitScreenState();
}

class _ToolkitScreenState extends State<ToolkitScreen> {
  CommandTemplate? _selectedCommand;
  String _terminalStatus = 'TOOLKIT_READY // SELECT SYSTEM REFERENCE';

  // Massive Repository of Educational Network Analysis & Security Audit Blueprints
  final List<CommandTemplate> _commands = const [
    CommandTemplate(
      toolName: 'NMAP // OS_DETECTION',
      syntax: 'nmap -O -v [TARGET_IP]',
      purpose: 'Identify host operating system parameters via TCP/IP stack fingerprinting.',
      modifierBreakdown:
      '• -O : Enables native operating system detection.\n'
          '• -v : Increases verbosity level, printing discovery metrics in real-time.',
      technicalTheory: 'Analyzes subtle variations in a target\'s responses to custom network probes (like TCP window size, initial sequence numbers, and IP options) to deduce the operating system version.',
    ),
    CommandTemplate(
      toolName: 'NMAP // AGGRESSIVE_AUDIT',
      syntax: 'nmap -A -T4 [TARGET_IP]',
      purpose: 'Execute a comprehensive network service map, script audit, and traceroute.',
      modifierBreakdown:
      '• -A : Enables OS detection, service version scanning, script scanning, and traceroute.\n'
          '• -T4 : Sets timing template to aggressive, accelerating execution speeds on modern connections.',
      technicalTheory: 'Combines multiple diagnostic techniques concurrently. It interacts directly with open network banners to extract software build versions and maps physical routing hops via TTL metrics.',
    ),
    CommandTemplate(
      toolName: 'NMAP // STEALTH_SYN_SCAN',
      syntax: 'sudo nmap -sS -p- [TARGET_IP]',
      purpose: 'Perform a semi-open stealth port check across all 65,335 TCP channels.',
      modifierBreakdown:
      '• -sS : Executes a SYN stealth scan (half-open inspection).\n'
          '• -p- : Overrides the default top-1000 limit to scan every single valid logical port.',
      technicalTheory: 'Sends a SYN packet and waits for a response. If a SYN/ACK is returned, the port is listening. It immediately drops the connection handshake with a RST frame to prevent standard application logging systems from registering the interaction.',
    ),
    CommandTemplate(
      toolName: 'AIRODUMP // RF_CAPTURE',
      syntax: 'sudo airodump-ng --band abg --write capture_file [INTERFACE]',
      purpose: 'Monitor ambient 2.4GHz and 5GHz wireless airspace coordinates and save logs.',
      modifierBreakdown:
      '• --band abg : Forces the network card to cycle across 802.11a, b, g, and n channels.\n'
          '• --write : Designates the file prefix where captured connection packets will be saved.',
      technicalTheory: 'Puts the designated network interface card into Monitor Mode. The hardware uncouples from router handshakes and captures raw management frames floating through the air, compiling a real-time list of nearby BSSIDs and active clients.',
    ),
    CommandTemplate(
      toolName: 'AIREPLAY // DEAUTH_VALIDATION',
      syntax: 'sudo aireplay-ng --deauth 15 -a [BSSID] -c [CLIENT_MAC] [INTERFACE]',
      purpose: 'Validate wireless connection durability and verification frames against a target.',
      modifierBreakdown:
      '• --deauth 15 : Broadcasts 15 distinct disassociation management frames.\n'
          '• -a [BSSID] : Hardware MAC address of the target access point router.\n'
          '• -c [CLIENT_MAC] : Restricts the frame delivery to a specific connected handset asset.',
      technicalTheory: 'Spoofs unencrypted 802.11 disassociation frames to test if local client hardware can securely handle unexpected disconnection vectors and correctly initiate a re-authentication sequence.',
    ),
    CommandTemplate(
      toolName: 'AIRCRACK // CRYPTO_AUDIT',
      syntax: 'aircrack-ng -w /usr/share/wordlists/rockyou.txt capture_file-01.cap',
      purpose: 'Verify the cryptographic strength of captured local network handshakes.',
      modifierBreakdown:
      '• -w : Specifies the absolute file path to a local alphanumeric wordlist registry.\n'
          '• .cap : The raw packet capture file containing a recorded 4-way wireless handshake.',
      technicalTheory: 'Performs highly parallelized, offline dictionary validation against recorded cryptographic handshakes. It uses PBKDF2 hashing functions to verify if the configured WPA/WPA2 pre-shared keys comply with modern organizational security policies.',
    ),
    CommandTemplate(
      toolName: 'DIRB // WEB_DIRECTORY_ENUM',
      syntax: 'dirb http://[TARGET_IP]/ -r -z 100',
      purpose: 'Audit a web server\'s hidden directory map to find exposed administrative files.',
      modifierBreakdown:
      '• -r : Disables recursive scanning, restricting directory traversal to the root level only.\n'
          '• -z 100 : Introduces a 100-millisecond delay between HTTP requests to prevent server exhaustion.',
      technicalTheory: 'Launches automated HTTP HEAD or GET requests against a target web server using a dictionary file. By inspecting returned HTTP status codes (e.g., 200 OK vs 403 Forbidden), it reconstructs the server\'s private folder layout.',
    ),
    CommandTemplate(
      toolName: 'NIKTO // VULN_ASSESSMENT',
      syntax: 'nikto -h http://[TARGET_IP]/ -C all -ssl',
      purpose: 'Scan a web platform for outdated server components and dangerous configuration files.',
      modifierBreakdown:
      '• -h : Designates the target host web URL or IP endpoint.\n'
          '• -C all : Forces the scanning engine to execute all known plugin validation checks.\n'
          '• -ssl : Explicitly forces the connections to encrypt via HTTPS protocols.',
      technicalTheory: 'Cross-references a target server\'s headers and software banners against a database of known dangerous files, default scripts, and misconfigured server properties to flag cross-site scripting or index exposure vulnerabilities.',
    ),
    CommandTemplate(
      toolName: 'NETCAT // BANNER_GRAB',
      syntax: 'nc -v -n -z -w 2 [TARGET_IP] 20-100',
      purpose: 'Perform lightning-fast service banner enumeration across a specific port range.',
      modifierBreakdown:
      '• -v : Verbose mode, printing active debugging connections.\n'
          '• -n : Disables DNS resolution to optimize raw throughput speed.\n'
          '• -z : Zero-I/O mode, scanning for listening daemons without transmitting payload data.\n'
          '• -w 2 : Enforces a strict 2-second timeout on unvalidated socket handshakes.',
      technicalTheory: 'Establishes a raw, low-level TCP stream connection to target ports. When a connection succeeds, it captures the initial raw text string sent by the host application (like an SSH version or server type string) to log asset data.',
    ),
  ];

  void _copyToClipboard(CommandTemplate cmd) {
    Clipboard.setData(ClipboardData(text: cmd.syntax));
    setState(() {
      _terminalStatus = 'COPIED_TO_CLIPBOARD :: ${cmd.toolName}';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.glitchGrey,
        content: Text(
          'SYNTAX COPIED TO SYSTEM CLIPBOARD',
          style: AppText.label.copyWith(color: AppColors.cyan, fontSize: 11),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TerminalScaffold(
      title: 'Toolkit // Command Reference',
      accent: AppColors.cyan,
      backgroundAsset: AppAssets.terminalBackground,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // TOP STATUS TERMINAL BAR
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.glitchGrey.withOpacity(0.2),
                border: Border.all(color: AppColors.glitchGrey),
              ),
              child: Text(
                '// $_terminalStatus',
                style: AppText.label.copyWith(fontSize: 11, color: AppColors.cyan, letterSpacing: 1),
              ),
            ),
            const SizedBox(height: 14),

            // SPLIT WORKSPACE PANELS
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT SIDE: SELECTION DECK
                  Expanded(
                    flex: 4,
                    child: ListView.builder(
                      itemCount: _commands.length,
                      itemBuilder: (context, idx) {
                        final cmd = _commands[idx];
                        final isSelected = _selectedCommand?.toolName == cmd.toolName;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedCommand = cmd),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.cyan.withOpacity(0.05) : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? AppColors.cyan : AppColors.glitchGrey,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cmd.toolName,
                                  style: AppText.label.copyWith(
                                    fontSize: 12,
                                    color: isSelected ? AppColors.cyan : Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  cmd.syntax,
                                  style: AppText.dim.copyWith(fontSize: 11, fontFamily: 'monospace'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // RIGHT SIDE: SYSTEM DOSSIER EXPLANATION
                  Expanded(
                    flex: 5,
                    child: _selectedCommand == null
                        ? Container(
                      decoration: hudPanelDecoration(borderColor: AppColors.hazard, opacity: 0.15, glitchOffset: 1.0),
                      child: Center(
                        child: Text(
                          'AWAITING_SELECTION\n[LOAD ARCHITECTURE]',
                          textAlign: TextAlign.center,
                          style: AppText.dim.copyWith(fontSize: 11, height: 1.4),
                        ),
                      ),
                    )
                        : Container(
                      padding: const EdgeInsets.all(14),
                      decoration: hudPanelDecoration(borderColor: AppColors.hazard, opacity: 0.15, glitchOffset: 1.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedCommand!.toolName,
                            style: AppText.label.copyWith(fontSize: 14, color: Colors.white),
                          ),
                          const Divider(color: AppColors.glitchGrey, height: 16),

                          Text('FUNCTIONAL_USE:', style: AppText.dim.copyWith(fontSize: 10)),
                          const SizedBox(height: 2),
                          Text(_selectedCommand!.purpose, style: AppText.label.copyWith(fontSize: 11, height: 1.3)),
                          const SizedBox(height: 12),

                          Text('MODIFIER_ARGUMENTS:', style: AppText.dim.copyWith(fontSize: 10)),
                          const SizedBox(height: 4),
                          Text(
                              _selectedCommand!.modifierBreakdown,
                              style: AppText.label.copyWith(fontSize: 11, color: Colors.white70, height: 1.3, fontFamily: 'monospace')
                          ),
                          const SizedBox(height: 12),

                          Text('THEORETICAL_MECHANICS:', style: AppText.dim.copyWith(fontSize: 10)),
                          const SizedBox(height: 2),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                _selectedCommand!.technicalTheory,
                                style: AppText.dim.copyWith(fontSize: 11, height: 1.3, color: Colors.white60),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          ExecuteButton(
                            label: 'COPY_SYNTAX_STRING',
                            color: AppColors.warningYellow,
                            onPressed: () => _copyToClipboard(_selectedCommand!),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}