/// Raw 802.11 radio signature captured during a wardriving sweep.
/// Each target represents a single access point detected in the local RF environment.
class WardriveTarget {
  final String ssid;
  final String bssid;
  final int rssi;
  final int frequency;
  final int channel;
  final String capabilities;

  WardriveTarget({
    required this.ssid,
    required this.bssid,
    required this.rssi,
    required this.frequency,
    required this.channel,
    required this.capabilities,
  });

  /// Frequency band label derived from raw MHz value
  String get frequencyBand {
    if (frequency >= 2400 && frequency < 2500) return '2.4 GHz';
    if (frequency >= 5000 && frequency < 5900) return '5 GHz';
    if (frequency >= 5900 && frequency <= 7125) return '6 GHz';
    return '$frequency MHz';
  }

  /// Normalized signal quality 0-100 from raw dBm
  int get signalQuality {
    if (rssi <= -100) return 0;
    if (rssi >= -50) return 100;
    return 2 * (rssi + 100);
  }

  /// True if network uses no encryption or broken WEP
  bool get isVulnerable {
    final upper = capabilities.toUpperCase();
    return upper.contains('OPEN') ||
        upper.contains('[ESS]') ||
        upper.contains('WEP');
  }

  /// True if WEP is detected (cryptographically broken)
  bool get isWep {
    return capabilities.toUpperCase().contains('WEP');
  }

  /// True if fully open / no auth
  bool get isOpen {
    final upper = capabilities.toUpperCase();
    return upper.contains('OPEN') || upper.contains('[ESS]');
  }

  /// Extract clean encryption label from raw capability string
  String get cryptoLayer {
    final upper = capabilities.toUpperCase();
    if (upper.contains('WPA3') || upper.contains('SAE')) return 'WPA3-SAE';
    if (upper.contains('WPA2') && upper.contains('WPA3')) return 'WPA2/WPA3';
    if (upper.contains('WPA2')) return 'WPA2-PSK';
    if (upper.contains('WPA')) return 'WPA-PSK';
    if (upper.contains('WEP')) return 'WEP [BROKEN]';
    if (upper.contains('OPEN') || upper.contains('[ESS]')) return 'OPEN [EXPOSED]';
    return 'UNKNOWN';
  }

  /// DedSec-style threat classification based on encryption
  String get threatClassification {
    if (isOpen) return 'CRITICAL :: UNENCRYPTED_TRAFFIC';
    if (isWep) return 'HIGH :: WEP_CIPHER_COMPROMISED';
    if (cryptoLayer.contains('WPA-PSK')) return 'MODERATE :: LEGACY_WPA';
    if (cryptoLayer.contains('WPA2')) return 'LOW :: WPA2AES_ACTIVE';
    if (cryptoLayer.contains('WPA3')) return 'MINIMAL :: WPA3_SAE_HARDENED';
    return 'UNKNOWN :: UNCLASSIFIED';
  }

  /// Risk badge color hint
  bool get isHighRisk => isOpen || isWep;
}
