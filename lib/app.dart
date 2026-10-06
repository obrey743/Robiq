import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'services/settings_service.dart';

class RobiqApp extends StatelessWidget {
  const RobiqApp({super.key});

  @override
  Widget build(BuildContext context) {
    final onboarded = context.select<SettingsService, bool>((s) => s.onboarded);
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      // Field controllers are dark-only: readable outdoors and easy on night
      // shifts, and the console's colours are tuned for it.
      theme: AppTheme.dark,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: onboarded ? const HomeScreen() : const WelcomeScreen(),
      ),
    );
  }
}
