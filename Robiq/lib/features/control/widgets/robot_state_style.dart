import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/control/robot_controller.dart';

/// Display label, colour and "what to do next" hint for each robot state.
/// The hint is what makes the console easy to use: the operator always sees
/// the next step.
extension RobotStateStyle on RobotController {
  (String label, Color color) get stateStyle => switch (state) {
    RobotState.powerOff => ('Powered off', AppColors.text3),
    RobotState.idle => ('Standby', AppColors.text2),
    RobotState.enabled => ('Ready', AppColors.success),
    RobotState.running => ('Running', AppColors.accent),
    RobotState.paused => ('Paused', AppColors.warning),
    RobotState.fault => ('Fault', AppColors.warning),
    RobotState.estop => ('Emergency stop', AppColors.danger),
  };

  String get nextStepHint => switch (state) {
    RobotState.powerOff => 'Power on to begin',
    RobotState.idle => 'Hold Enable to allow motion',
    RobotState.enabled when mode == OperatingMode.manual => 'Motion enabled',
    RobotState.enabled when program.isEmpty => 'Teach waypoints in Manual first',
    RobotState.enabled => 'Ready to run program',
    RobotState.running => 'Program running',
    RobotState.paused => 'Resume or stop the program',
    RobotState.fault => '${faultReason ?? 'Fault'} — hold Reset to clear',
    RobotState.estop => 'Make the area safe, then hold Reset',
  };
}
