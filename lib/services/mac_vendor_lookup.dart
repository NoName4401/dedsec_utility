/// Small static OUI prefix -> vendor lookup table.
/// Not exhaustive -- extend as needed. Prefixes are the first 3 octets
/// of a MAC address, uppercase, colon-separated.
class MacVendorLookup {
  static const Map<String, String> _table = {
    'F4:F5:D8': 'GOOGLE_DEVICE',
    '3C:5A:B4': 'GOOGLE_DEVICE',
    'A4:83:E7': 'APPLE_DEVICE',
    'F0:18:98': 'APPLE_DEVICE',
    'AC:BC:32': 'APPLE_DEVICE',
    '00:1A:11': 'GOOGLE_DEVICE',
    '00:04:20': 'SLIM_DEVICES',
    '00:22:65': 'ROKU_DEVICE',
    'B8:27:EB': 'RASPBERRY_PI',
    'DC:A6:32': 'RASPBERRY_PI',
    '00:1D:C9': 'SONY_PLAYSTATION',
    '00:19:C5': 'SONY_PLAYSTATION',
    '7C:ED:8D': 'SONY_PLAYSTATION',
    '00:17:AB': 'MICROSOFT_XBOX',
    '00:50:F2': 'MICROSOFT_DEVICE',
    '00:0D:93': 'APPLE_DEVICE',
    '18:B4:30': 'NEST_SMART_APPLIANCE',
    'D0:52:A8': 'SMART_APPLIANCE',
    '64:16:66': 'SAMSUNG_DEVICE',
    '8C:79:F5': 'SAMSUNG_DEVICE',
    'E8:50:8B': 'SAMSUNG_DEVICE',
    'FC:A1:83': 'AMAZON_ECHO',
    '68:37:E9': 'AMAZON_ECHO',
    '44:65:0D': 'AMAZON_DEVICE',
  };

  static String lookup(String? mac) {
    if (mac == null || mac.length < 8) return 'UNKNOWN_VENDOR';
    final prefix = mac.toUpperCase().substring(0, 8);
    return _table[prefix] ?? 'UNKNOWN_VENDOR';
  }
}
