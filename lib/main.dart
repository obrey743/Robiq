import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/connection/connection_manager.dart';
import 'services/control/component_controller.dart';
import 'services/control/robot_controller.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsService.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(create: (_) => ConnectionManager()),
        ChangeNotifierProvider(create: (c) => RobotController(c.read<ConnectionManager>(), settings)),
        ChangeNotifierProvider(
          create: (c) => ComponentController(c.read<ConnectionManager>(), settings, c.read<RobotController>()),
        ),
      ],
      child: const RobiqApp(),
    ),
  );
}
