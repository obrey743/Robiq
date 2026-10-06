import 'package:flutter_test/flutter_test.dart';
import 'package:robiq/data/models/robot_component.dart';
import 'package:robiq/services/connection/connection_manager.dart';
import 'package:robiq/services/control/component_controller.dart';
import 'package:robiq/services/control/robot_controller.dart';
import 'package:robiq/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsService settings;
  late RobotController robot;
  late ComponentController components;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.load();
    final conn = ConnectionManager();
    robot = RobotController(conn, settings);
    components = ComponentController(conn, settings, robot);
  });

  tearDown(() {
    components.dispose();
    robot.dispose();
  });

  test('starts with default lights and horn', () {
    expect(components.components.map((c) => c.name), ['Lights', 'Horn']);
  });

  test('toggle and momentary', () {
    final [lights, horn] = components.components;
    components.toggle(lights);
    expect(components.isOn(lights), isTrue);
    components.toggle(lights);
    expect(components.isOn(lights), isFalse);

    components.press(horn);
    expect(components.isOn(horn), isTrue);
    components.release(horn);
    expect(components.isOn(horn), isFalse);
  });

  test('E-stop switches everything off', () {
    robot.powerOn();
    components.toggle(components.components.first);
    robot.emergencyStop();
    expect(components.isOn(components.components.first), isFalse);
  });

  test('edits are saved', () async {
    components.add(const RobotComponent(name: 'Fan', pin: 15, icon: ComponentIcon.fan));
    components.remove(0);
    final reloaded = await SettingsService.load();
    expect(reloaded.components.map((c) => '${c.name}:${c.pin}'), ['Horn:4', 'Fan:15']);
  });

  test('re-pinning a lit component turns the old pin off', () {
    final lights = components.components.first;
    components.toggle(lights);
    components.replace(0, const RobotComponent(name: 'Lights', pin: 5));
    expect(components.isOn(lights), isFalse);
  });
}
