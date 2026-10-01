import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/connection_type.dart';
import '../../data/models/robot_device.dart';
import '../../services/connection/connection_manager.dart';
import '../../services/control/robot_controller.dart';
import '../../shared/widgets/ui.dart';
import '../arm/arm_control_screen.dart';
import 'io_control_panel.dart';
import 'rover_control_panel.dart';
import 'widgets/event_log_sheet.dart';
import 'widgets/robot_state_style.dart';

const _kindNames = {DeviceKind.rover: 'Rover', DeviceKind.arm: 'Arm', DeviceKind.generic: 'I/O board'};

/// Operator console: status and STOP on top, the robot view in the middle,
/// and motion controls in one bar at the bottom. Works offline in simulation.
class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kind = context.select<ConnectionManager, DeviceKind>((m) => m.kind);
    final (Widget view, List<Widget> actions) = switch (kind) {
      DeviceKind.rover => (const RoverControlPanel(), roverActions(context)),
      DeviceKind.arm => (const ArmControlScreen(), armActions(context)),
      DeviceKind.generic => (const IoControlPanel(), const <Widget>[]),
    };

    return Column(
      children: [
        const _Header(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.viewport,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: view,
            ),
          ),
        ),
        _ControlBar(actions: actions),
      ],
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final robot = context.watch<RobotController>();
    final conn = context.watch<ConnectionManager>();
    final (label, color) = robot.stateStyle;
    final kindName = _kindNames[conn.kind]!;
    final name = robot.simulated
        ? 'Simulated ${conn.kind == DeviceKind.generic ? kindName : kindName.toLowerCase()}'
        : conn.device?.name ?? 'Robot';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 640;
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RobotPicker(name: name),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StatusChip(label: label, color: color, dense: true),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(robot.nextStepHint, style: AppText.caption, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (wide) ...[const _Telemetry(), const SizedBox(width: 16)],
              const _StopButton(),
            ],
          );
        },
      ),
    );
  }
}

class _RobotPicker extends StatelessWidget {
  const _RobotPicker({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ConnectionManager>();
    final unlocked = context.select<RobotController, bool>((r) => r.canChangeMode);
    return PopupMenuButton<DeviceKind>(
      enabled: unlocked,
      tooltip: 'Robot type',
      position: PopupMenuPosition.under,
      onSelected: manager.setDeviceKind,
      itemBuilder: (_) => [
        for (final e in _kindNames.entries)
          CheckedPopupMenuItem(value: e.key, checked: e.key == manager.kind, child: Text(e.value)),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(name, overflow: TextOverflow.ellipsis, style: AppText.title.copyWith(fontSize: 20)),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more, color: unlocked ? AppColors.text2 : AppColors.text3, size: 22),
        ],
      ),
    );
  }
}

/// Battery and link readouts, shown in the header on wide screens and over
/// the robot view on phones.
class _Telemetry extends StatelessWidget {
  const _Telemetry();

  @override
  Widget build(BuildContext context) {
    final robot = context.watch<RobotController>();
    final conn = context.watch<ConnectionManager>();
    final battery = conn.telemetry['battery']?.last.value;
    final link = robot.simulated
        ? 'Simulation'
        : '${conn.device?.connectionType == ConnectionType.bluetooth ? 'BLE' : 'Wi-Fi'}'
              '${robot.latencyMs != null ? ' · ${robot.latencyMs} ms' : ''}';
    final linkIcon = robot.simulated
        ? Icons.science_outlined
        : conn.device?.connectionType == ConnectionType.bluetooth
        ? Icons.bluetooth
        : Icons.wifi;

    Widget item(IconData icon, String text, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(text, style: AppText.mono.copyWith(color: color == AppColors.text2 ? AppColors.text : color)),
      ],
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (battery != null) ...[
          item(
            robot.batteryLow ? Icons.battery_alert : Icons.battery_5_bar,
            '${battery.toStringAsFixed(1)} V',
            robot.batteryLow ? AppColors.danger : AppColors.text2,
          ),
          const SizedBox(width: 16),
        ],
        item(linkIcon, link, AppColors.text2),
      ],
    );
  }
}

/// Emergency stop. Fires on touch down and latches until reset.
class _StopButton extends StatefulWidget {
  const _StopButton();

  @override
  State<_StopButton> createState() => _StopButtonState();
}

class _StopButtonState extends State<_StopButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final latched = context.select<RobotController, bool>((r) => r.state == RobotState.estop);
    return Semantics(
      button: true,
      label: 'Emergency stop',
      child: Listener(
        onPointerDown: (_) {
          HapticFeedback.heavyImpact();
          setState(() => _down = true);
          context.read<RobotController>().emergencyStop();
        },
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: latched
                ? AppColors.danger.withValues(alpha: 0.14)
                : _down
                ? const Color(0xFFC93636)
                : AppColors.danger,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.danger, width: 1.5),
            boxShadow: latched ? null : [BoxShadow(color: AppColors.danger.withValues(alpha: 0.35), blurRadius: 16)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.front_hand, size: 18, color: latched ? AppColors.danger : Colors.white),
              const SizedBox(width: 8),
              Text(
                latched ? 'Stopped' : 'STOP',
                style: AppText.bodyStrong.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: latched ? 0 : 1,
                  color: latched ? AppColors.danger : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom control bar ─────────────────────────────────────────────────────

class _ControlBar extends StatelessWidget {
  const _ControlBar({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final robot = context.watch<RobotController>();
    final alarms = robot.unacknowledgedAlarms;

    final Widget primary = switch (robot.state) {
      RobotState.powerOff => AppButton(
        label: 'Power on',
        icon: Icons.power_settings_new,
        variant: ButtonVariant.primary,
        height: 48,
        expand: true,
        onPressed: robot.powerOn,
      ),
      RobotState.idle => HoldButton(label: 'Hold to enable', icon: Icons.lock_open, onHeld: robot.enable),
      RobotState.fault || RobotState.estop => HoldButton(
        label: 'Hold to reset',
        icon: Icons.restart_alt,
        variant: ButtonVariant.danger,
        onHeld: robot.reset,
      ),
      _ => AppButton(label: 'Disable', icon: Icons.lock, height: 48, expand: true, onPressed: robot.disable),
    };

    final mode = Segmented<OperatingMode>(
      height: 40,
      options: const {OperatingMode.manual: 'Manual', OperatingMode.auto: 'Auto'},
      value: robot.mode,
      onChanged: robot.canChangeMode ? robot.setMode : null,
    );

    final speed = Row(
      children: [
        const Icon(Icons.speed, size: 18, color: AppColors.text2),
        const SizedBox(width: 10),
        Expanded(
          child: Slider(min: 0.01, value: robot.speedOverride, onChanged: robot.setSpeedOverride),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          child: Text('${(robot.speedOverride * 100).round()}%', textAlign: TextAlign.right, style: AppText.mono),
        ),
      ],
    );

    final tools = [
      ...actions,
      AppIconButton(icon: Icons.more_horiz, size: 48, tooltip: 'More', onTap: () => _showMenu(context)),
      AppIconButton(
        icon: Icons.notifications_none,
        size: 48,
        tooltip: 'Event log',
        badge: alarms > 0 ? '$alarms' : null,
        onTap: () => showEventLog(context),
      ),
    ];
    Widget spaced(List<Widget> items) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [for (final t in items) Padding(padding: const EdgeInsets.only(left: 8), child: t)],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 900) {
            return Row(
              children: [
                mode,
                const SizedBox(width: 20),
                SizedBox(width: 260, child: speed),
                const Spacer(),
                spaced(tools),
                const SizedBox(width: 12),
                SizedBox(width: 220, child: primary),
              ],
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  mode,
                  const SizedBox(width: 16),
                  Expanded(child: speed),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: primary),
                  spaced(tools),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Battery/link readout for phones, drawn over the robot view.
class ViewportStatus extends StatelessWidget {
  const ViewportStatus({super.key});

  @override
  Widget build(BuildContext context) {
    // On wide screens the same readout sits in the header instead.
    if (MediaQuery.sizeOf(context).width >= 640) return const SizedBox.shrink();
    return const Glass(child: _Telemetry());
  }
}

// ── More menu ──────────────────────────────────────────────────────────────

void _showMenu(BuildContext context) {
  showModalBottomSheet<void>(context: context, builder: (_) => const _MenuSheet());
}

class _MenuSheet extends StatelessWidget {
  const _MenuSheet();

  @override
  Widget build(BuildContext context) {
    final robot = context.watch<RobotController>();
    final manager = context.watch<ConnectionManager>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Console', style: AppText.title.copyWith(fontSize: 20)),
            const SizedBox(height: 16),
            GroupedList(
              children: [
                ListRow(
                  leading: Icons.smart_toy_outlined,
                  title: 'Robot type',
                  subtitle: robot.canChangeMode ? null : 'Stop the program to change',
                  trailing: Segmented<DeviceKind>(
                    height: 34,
                    options: const {DeviceKind.rover: 'Rover', DeviceKind.arm: 'Arm', DeviceKind.generic: 'I/O'},
                    value: manager.kind,
                    onChanged: robot.canChangeMode ? manager.setDeviceKind : null,
                  ),
                ),
                ListRow(
                  leading: Icons.receipt_long_outlined,
                  title: 'Event log',
                  subtitle: '${robot.events.length} events',
                  trailing: const Icon(Icons.chevron_right, color: AppColors.text3),
                  onTap: () {
                    Navigator.pop(context);
                    showEventLog(context);
                  },
                ),
                if (robot.simulated)
                  ListRow(
                    leading: Icons.battery_charging_full,
                    title: 'Recharge simulated robot',
                    trailing: const Icon(Icons.chevron_right, color: AppColors.text3),
                    onTap: () {
                      robot.resetSimulation();
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Power off',
              icon: Icons.power_settings_new,
              expand: true,
              onPressed: robot.isPowered && robot.state != RobotState.fault
                  ? () {
                      robot.powerOff();
                      Navigator.pop(context);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
