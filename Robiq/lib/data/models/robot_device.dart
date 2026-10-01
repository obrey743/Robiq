import 'connection_type.dart';

/// What kind of hardware a device is. Reported by the firmware in its
/// `info` message, or chosen manually by the user.
enum DeviceKind { rover, arm, generic }

/// A device ROBIQ knows how to talk to.
class RobotDevice {
  const RobotDevice({
    required this.id,
    required this.name,
    required this.connectionType,
    this.kind = DeviceKind.generic,
    this.host,
    this.port,
    this.jointCount = 0,
  });

  /// BLE remote id, or `host:port` for Wi-Fi devices.
  final String id;
  final String name;
  final ConnectionType connectionType;
  final DeviceKind kind;

  /// Wi-Fi only.
  final String? host;
  final int? port;

  /// Number of servo joints for robotic arms.
  final int jointCount;

  RobotDevice copyWith({String? name, DeviceKind? kind, int? jointCount}) => RobotDevice(
    id: id,
    name: name ?? this.name,
    connectionType: connectionType,
    kind: kind ?? this.kind,
    host: host,
    port: port,
    jointCount: jointCount ?? this.jointCount,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'connectionType': connectionType.name,
    'kind': kind.name,
    'host': host,
    'port': port,
    'jointCount': jointCount,
  };

  factory RobotDevice.fromJson(Map<String, dynamic> json) => RobotDevice(
    id: json['id'] as String,
    name: json['name'] as String,
    connectionType: ConnectionType.values.byName(json['connectionType'] as String),
    kind: DeviceKind.values.byName(json['kind'] as String? ?? 'generic'),
    host: json['host'] as String?,
    port: json['port'] as int?,
    jointCount: json['jointCount'] as int? ?? 0,
  );
}
