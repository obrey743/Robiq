import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robiq/core/theme/app_theme.dart';
import 'package:robiq/data/models/robot_device.dart';
import 'package:robiq/features/control/rover_control_panel.dart';
import 'package:robiq/services/connection/connection_manager.dart';
import 'package:robiq/services/control/component_controller.dart';
import 'package:robiq/services/control/robot_controller.dart';
import 'package:robiq/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('holding Forward drives the simulated rover forward', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    final conn = ConnectionManager()..setDeviceKind(DeviceKind.rover);
    final robot = RobotController(conn, settings);
    final components = ComponentController(conn, settings, robot);
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: conn),
          ChangeNotifierProvider.value(value: robot),
          ChangeNotifierProvider.value(value: components),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: RoverControlPanel()),
        ),
      ),
    );
    expect(find.text('Lights'), findsOneWidget);

    robot
      ..powerOn()
      ..enable();
    await tester.pump();

    final gesture = await tester.startGesture(tester.getCenter(find.byTooltip('Forward')));
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(robot.position.dy, greaterThan(0.05));
    expect(robot.position.dx.abs(), lessThan(1e-6));

    await tester.tap(find.text('Lights'));
    await tester.pump();
    expect(components.isOn(components.components.first), isTrue);

    robot.powerOff();
    await tester.pumpWidget(const SizedBox());
    components.dispose();
    robot.dispose();
  });
}
