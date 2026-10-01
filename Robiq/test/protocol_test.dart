import 'package:flutter_test/flutter_test.dart';
import 'package:robiq/data/models/robot_device.dart';
import 'package:robiq/data/protocol/robiq_protocol.dart';

void main() {
  group('RobiqCommand', () {
    test('drive clamps and rounds', () {
      expect(RobiqCommand.drive(1.5, -0.123).encode(), '{"cmd":"drive","x":1.0,"y":-0.12}\n');
    });

    test('joint rounds angle', () {
      expect(RobiqCommand.joint(2, 89.6).encode(), '{"cmd":"joint","id":2,"angle":90}\n');
    });
  });

  group('RobiqMessage.parse', () {
    test('telemetry', () {
      final msg = RobiqMessage.parse('{"type":"telemetry","data":{"battery":7.4,"rssi":-60}}');
      expect(msg, isA<TelemetryMessage>());
      expect((msg as TelemetryMessage).values, {'battery': 7.4, 'rssi': -60.0});
    });

    test('info', () {
      final msg = RobiqMessage.parse('{"type":"info","name":"Arm","kind":"arm","joints":4}') as InfoMessage;
      expect(msg.kind, DeviceKind.arm);
      expect(msg.jointCount, 4);
    });

    test('non-JSON becomes a log line', () {
      expect(RobiqMessage.parse('booting...'), isA<LogMessage>());
    });

    test('blank line is ignored', () {
      expect(RobiqMessage.parse('   '), isNull);
    });
  });

  test('LineBuffer splits across chunks', () {
    final buf = LineBuffer();
    expect(buf.add('{"a":1}\n{"b"'), ['{"a":1}']);
    expect(buf.add(':2}\n'), ['{"b":2}']);
  });
}
