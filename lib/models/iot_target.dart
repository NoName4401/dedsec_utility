enum ExploitType { lan, ble }

class IotTarget {
  final String id;
  final String name;
  final ExploitType type;
  final String? ipAddress;
  final int? port;
  final String? bleDeviceId;
  final String? serviceUuid;
  final String? characteristicUuid;
  final String vendor;

  const IotTarget({
    required this.id,
    required this.name,
    required this.type,
    this.ipAddress,
    this.port,
    this.bleDeviceId,
    this.serviceUuid,
    this.characteristicUuid,
    this.vendor = 'UNKNOWN',
  });

  String get label => '$name [${type.name.toUpperCase()}]';
}
