import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robiq/app.dart';
import 'package:robiq/features/home/home_screen.dart';
import 'package:robiq/features/onboarding/welcome_screen.dart';
import 'package:robiq/services/connection/connection_manager.dart';
import 'package:robiq/services/control/component_controller.dart';
import 'package:robiq/services/control/robot_controller.dart';
import 'package:robiq/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('welcome shows once, then opens the app', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    final conn = ConnectionManager();
    final robot = RobotController(conn, settings);
    final components = ComponentController(conn, settings, robot);
    tester.view.physicalSize = const Size(390, 844);
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
        child: const RobiqApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(settings.onboarded, isTrue);
    robot.dispose();
  });
}
