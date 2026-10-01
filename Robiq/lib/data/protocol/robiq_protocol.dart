import 'dart:convert';

import '../models/robot_device.dart';

/// ROBIQ wire protocol: newline-delimited JSON over BLE or WebSocket.
///
/// See `docs/PROTOCOL.md` for the full specification.
class RobiqCommand {
  const RobiqCommand._(this.payload);

  final Map<String, dynamic> payload;

  /// Differential/omni drive. [x] (turn) and [y] (throttle) are in -1..1.
  factory RobiqCommand.drive(double x, double y) => RobiqCommand._({'cmd': 'drive', 'x': _round(x), 'y': _round(y)});

  /// Move a servo joint to [angle] degrees (0..180).
  factory RobiqCommand.joint(int id, double angle) =>
      RobiqCommand._({'cmd': 'joint', 'id': id, 'angle': angle.round()});

  /// Set a digital output pin.
  factory RobiqCommand.digital(int pin, bool value) =>
      RobiqCommand._({'cmd': 'digital', 'pin': pin, 'value': value ? 1 : 0});

  /// Set a PWM output (0..255).
  factory RobiqCommand.pwm(int pin, int value) =>
      RobiqCommand._({'cmd': 'pwm', 'pin': pin, 'value': value.clamp(0, 255)});

  factory RobiqCommand.stop() => const RobiqCommand._({'cmd': 'stop'});

  /// Arm the device's drives. Firmware should ignore motion until enabled.
  factory RobiqCommand.enable() => const RobiqCommand._({'cmd': 'enable'});

  /// Halt motion and disarm the drives.
  factory RobiqCommand.disable() => const RobiqCommand._({'cmd': 'disable'});

  factory RobiqCommand.ping() => const RobiqCommand._({'cmd': 'ping'});
  factory RobiqCommand.info() => const RobiqCommand._({'cmd': 'info'});

  /// Free-form command for custom firmware.
  factory RobiqCommand.raw(Map<String, dynamic> payload) => RobiqCommand._(payload);

  String encode() => '${jsonEncode(payload)}\n';

  static double _round(double v) => (v.clamp(-1.0, 1.0) * 100).round() / 100;
}

/// Messages sent from a device to the app.
sealed class RobiqMessage {
  const RobiqMessage();

  /// Parses one line. Returns `null` for blank or malformed lines so that a
  /// noisy serial link never crashes the app.
  static RobiqMessage? parse(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    try {
      final json = jsonDecode(trimmed);
      if (json is! Map<String, dynamic>) return null;
      switch (json['type']) {
        case 'telemetry':
          final data = (json['data'] as Map<String, dynamic>? ?? {});
          return TelemetryMessage({
            for (final e in data.entries)
              if (e.value is num) e.key: (e.value as num).toDouble(),
          });
        case 'info':
          return InfoMessage(
            name: json['name'] as String?,
            kind: DeviceKind.values.asNameMap()[json['kind']] ?? DeviceKind.generic,
            jointCount: json['joints'] as int? ?? 0,
          );
        case 'pong':
          return const PongMessage();
        case 'log':
          return LogMessage(json['msg']?.toString() ?? '');
      }
    } on FormatException {
      return LogMessage(trimmed);
    }
    return null;
  }
}

class TelemetryMessage extends RobiqMessage {
  const TelemetryMessage(this.values);
  final Map<String, double> values;
}

class InfoMessage extends RobiqMessage {
  const InfoMessage({this.name, required this.kind, required this.jointCount});
  final String? name;
  final DeviceKind kind;
  final int jointCount;
}

class PongMessage extends RobiqMessage {
  const PongMessage();
}

class LogMessage extends RobiqMessage {
  const LogMessage(this.text);
  final String text;
}

/// Splits an incoming byte/text stream into complete lines.
class LineBuffer {
  final _buffer = StringBuffer();

  Iterable<String> add(String chunk) sync* {
    _buffer.write(chunk);
    final text = _buffer.toString();
    final parts = text.split('\n');
    _buffer
      ..clear()
      ..write(parts.removeLast());
    yield* parts;
  }
}
