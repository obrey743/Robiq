import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';

class RobiqApp extends StatelessWidget {
  const RobiqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      // Field controllers are dark-only: readable outdoors and easy on night
      // shifts, and the console's colours are tuned for it.
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
