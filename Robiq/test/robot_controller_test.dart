import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robiq/data/models/connection_type.dart';
import 'package:robiq/data/models/robot_device.dart';
import 'package:robiq/services/connection/connection_manager.dart';
import 'package:robiq/services/control/robot_controller.dart';
import 'package:robiq/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late RobotController robot;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    robot = RobotController(ConnectionManager(), await SettingsService.load());
  });

  tearDown(() => robot.dispose());

  void enable() {
    robot
      ..powerOn()
      ..enable();
  }

  test('starts powered off and offline in simulation', () {
    expect(robot.state, RobotState.powerOff);
    expect(robot.simulated, isTrue);
    expect(robot.canJog, isFalse);
  });

  test('cannot enable without power', () {
    robot.enable();
    expect(robot.state, RobotState.powerOff);
  });

  test('power on → enable allows jogging in manual', () {
    enable();
    expect(robot.state, RobotState.enabled);
    expect(robot.canJog, isTrue);
    robot.stepJoint(0, 10);
    expect(robot.joints[0], 100);
  });

  test('joints are clamped to 0..180', () {
    enable();
    robot.stepJoint(0, 500);
    expect(robot.joints[0], 180);
  });

  test('jogging is ignored unless enabled', () {
    robot.powerOn();
    robot.stepJoint(0, 10);
    expect(robot.joints[0], 90);
  });

  test('E-stop latches and requires reset then re-enable', () {
    enable();
    robot.emergencyStop();
    expect(robot.state, RobotState.estop);
    expect(robot.canJog, isFalse);

    robot.enable();
    expect(robot.state, RobotState.estop, reason: 'enable must not clear an E-stop');

    robot.reset();
    expect(robot.state, RobotState.idle);
    expect(robot.unacknowledgedAlarms, 1);
    robot.acknowledgeAll();
    expect(robot.unacknowledgedAlarms, 0);
  });

  test('AUTO mode locks jogging', () {
    enable();
    robot.setMode(OperatingMode.auto);
    expect(robot.canJog, isFalse);
  });

  test('program runs through waypoints and completes', () {
    fakeAsync((async) {
      enable();
      robot.stepJoint(0, 10); // 100°
      robot.teachWaypoint();
      robot.stepJoint(0, -20); // 80°
      robot.teachWaypoint();

      robot.setSpeedOverride(1);
      robot.setMode(OperatingMode.auto);
      robot.runProgram();
      expect(robot.state, RobotState.running);
      expect(robot.canChangeMode, isFalse);

      async.elapse(const Duration(seconds: 3));
      expect(robot.state, RobotState.enabled);
      expect(robot.joints[0], 80);
    });
  });

  test('pause holds position until resumed', () {
    fakeAsync((async) {
      enable();
      robot.teachWaypoint(); // all joints at 90
      robot.stepJoint(0, 90); // move away to 180
      robot.setSpeedOverride(0.1); // 9°/s
      robot.setMode(OperatingMode.auto);
      robot.runProgram();

      async.elapse(const Duration(milliseconds: 500));
      robot.pauseProgram();
      final held = robot.joints[0];
      async.elapse(const Duration(seconds: 2));
      expect(robot.joints[0], held);

      robot.resumeProgram();
      async.elapse(const Duration(seconds: 2));
      expect(robot.joints[0], lessThan(held));
    });
  });

  test('taught program persists', () async {
    enable();
    robot.teachWaypoint();
    final reloaded = RobotController(ConnectionManager(), await SettingsService.load());
    expect(reloaded.program, hasLength(1));
    reloaded.dispose();
  });

  test('simulator publishes telemetry only while powered', () {
    fakeAsync((async) {
      final conn = ConnectionManager();
      late RobotController sim;
      SettingsService.load().then((s) => sim = RobotController(conn, s));
      async.flushMicrotasks();

      async.elapse(const Duration(seconds: 2));
      expect(conn.telemetry, isEmpty);

      sim.powerOn();
      async.elapse(const Duration(seconds: 2));
      expect(conn.telemetry.keys, containsAll(['battery', 'temp', 'current']));
      sim.dispose();
    });
  });

  test('low battery raises one alert and clears with hysteresis', () {
    fakeAsync((async) {
      final conn = ConnectionManager();
      late RobotController sim;
      late SettingsService settings;
      SettingsService.load().then((s) {
        settings = s..lowBatteryVolts = 8.25;
        sim = RobotController(conn, s);
      });
      async.flushMicrotasks();

      sim.powerOn();
      async.elapse(const Duration(seconds: 60)); // idle drain passes 8.25 V
      expect(sim.batteryLow, isTrue);
      expect(sim.events.where((e) => e.message.startsWith('Low battery')), hasLength(1));

      settings.lowBatteryVolts = 6.0;
      sim.resetSimulation();
      async.elapse(const Duration(seconds: 1));
      expect(sim.batteryLow, isFalse);
      sim.dispose();
    });
  });

  test('recent devices are remembered newest first without duplicates', () async {
    final settings = await SettingsService.load();
    const a = RobotDevice(id: 'a', name: 'Arm', connectionType: ConnectionType.bluetooth, kind: DeviceKind.arm);
    const b = RobotDevice(
      id: '1.2.3.4:81',
      name: 'Rover',
      connectionType: ConnectionType.wifi,
      host: '1.2.3.4',
      port: 81,
    );
    settings
      ..rememberDevice(a)
      ..rememberDevice(b)
      ..rememberDevice(a);
    expect([for (final d in settings.recentDevices) d.id], ['a', '1.2.3.4:81']);
    expect(settings.recentDevices.first.kind, DeviceKind.arm);
    settings.forgetDevice('a');
    expect(settings.recentDevices, hasLength(1));
  });
}
