import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../services/control/robot_controller.dart';
import '../../services/settings_service.dart';
import '../../shared/widgets/ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final robot = context.read<RobotController>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        const SectionHeader('Motion'),
        GroupedList(
          children: [
            _SliderRow(
              title: 'Rover max speed',
              subtitle: 'Hard limit on drive output. The console speed control scales within it.',
              value: settings.maxSpeed,
              min: 0.1,
              max: 1,
              divisions: 9,
              format: (v) => '${(v * 100).round()}%',
              onChanged: (v) => settings.maxSpeed = v,
            ),
          ],
        ),
        const SectionHeader('Alerts'),
        GroupedList(
          children: [
            _SliderRow(
              title: 'Low battery warning',
              subtitle: '2S Li-ion: 6.8 V · 3S: 10.2 V',
              value: settings.lowBatteryVolts,
              min: 3,
              max: 16,
              divisions: 130,
              format: (v) => '${v.toStringAsFixed(1)} V',
              onChanged: (v) => settings.lowBatteryVolts = v,
            ),
            ListRow(
              title: 'High temperature warning',
              subtitle: 'From any "temp" telemetry value',
              trailing: Text(
                '${AppConstants.overTempC.round()} °C',
                style: AppText.mono.copyWith(color: AppColors.text2),
              ),
            ),
          ],
        ),
        const SectionHeader('Connection'),
        GroupedList(
          children: [
            ListRow(
              title: 'Auto-connect',
              subtitle: 'Reconnect to the most recent robot when the app opens',
              trailing: Switch(value: settings.autoConnect, onChanged: (v) => settings.autoConnect = v),
              onTap: () => settings.autoConnect = !settings.autoConnect,
            ),
          ],
        ),
        const SectionHeader('Simulation'),
        GroupedList(
          children: [
            ListRow(
              title: 'Recharge simulated robot',
              subtitle: 'Used whenever no robot is connected',
              trailing: const Icon(Icons.chevron_right, color: AppColors.text3),
              onTap: () {
                robot.resetSimulation();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Simulated robot recharged')));
              },
            ),
          ],
        ),
        const SectionHeader('About'),
        GroupedList(
          children: [
            ListRow(
              title: AppConstants.appName,
              subtitle: AppConstants.appTagline,
              trailing: Text('1.0.0', style: AppText.mono.copyWith(color: AppColors.text2)),
            ),
            const ListRow(
              title: 'Protocol',
              subtitle: 'Newline-delimited JSON over BLE or WebSocket · docs/PROTOCOL.md',
            ),
            const ListRow(title: 'License', subtitle: 'Open source · MIT'),
          ],
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.bodyStrong),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppText.caption),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(format(value), style: AppText.mono.copyWith(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          Slider(min: min, max: max, divisions: divisions, value: value.clamp(min, max), onChanged: onChanged),
        ],
      ),
    );
  }
}
