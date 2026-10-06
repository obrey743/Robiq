import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/protocol/robiq_protocol.dart';
import '../../services/connection/connection_manager.dart';
import '../../services/control/robot_controller.dart';
import '../../shared/widgets/ui.dart';
import '../components/component_button.dart';

/// Generic GPIO panel for ESP32 / Arduino boards: digital output tiles and
/// PWM channels. Outputs are live whenever the controller is powered.
class IoControlPanel extends StatefulWidget {
  const IoControlPanel({super.key});

  @override
  State<IoControlPanel> createState() => _IoControlPanelState();
}

class _IoControlPanelState extends State<IoControlPanel> {
  final Map<int, bool> _digital = {2: false, 4: false, 5: false, 13: false};
  final Map<int, double> _pwm = {12: 0, 14: 0};

  void _allOff(ConnectionManager manager) {
    setState(() {
      for (final pin in _digital.keys) {
        _digital[pin] = false;
        manager.send(RobiqCommand.digital(pin, false));
      }
      for (final pin in _pwm.keys) {
        _pwm[pin] = 0;
        manager.send(RobiqCommand.pwm(pin, 0));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.read<ConnectionManager>();
    final powered = context.select<RobotController, bool>((r) => r.isPowered);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        const SectionHeader('Components'),
        const ComponentStrip(wrap: true),
        SectionHeader(
          'Digital outputs',
          trailing: AppButton(
            label: 'All off',
            variant: ButtonVariant.ghost,
            height: 32,
            onPressed: powered ? () => _allOff(manager) : null,
          ),
        ),
        LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth >= 600 ? 6 : 4;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
              children: [for (final pin in _digital.keys) _pinTile(manager, pin, powered)],
            );
          },
        ),
        const SectionHeader('PWM outputs'),
        GroupedList(
          children: [
            for (final pin in _pwm.keys)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    SizedBox(width: 72, child: Text('GPIO $pin', style: AppText.bodyStrong)),
                    Expanded(
                      child: Slider(
                        max: 255,
                        value: _pwm[pin]!,
                        onChanged: powered ? (v) => setState(() => _pwm[pin] = v) : null,
                        onChangeEnd: (v) => manager.send(RobiqCommand.pwm(pin, v.round())),
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        '${(_pwm[pin]! / 255 * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: AppText.mono,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (!powered)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text('Power on to switch outputs.', style: AppText.caption, textAlign: TextAlign.center),
          ),
      ],
    );
  }

  Widget _pinTile(ConnectionManager manager, int pin, bool powered) {
    final on = _digital[pin]!;
    return Material(
      color: on ? AppColors.accent.withValues(alpha: 0.16) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: on ? AppColors.accent : AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: powered
            ? () {
                setState(() => _digital[pin] = !on);
                manager.send(RobiqCommand.digital(pin, !on));
              }
            : null,
        child: Opacity(
          opacity: powered ? 1 : 0.45,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? AppColors.accent : AppColors.text3,
                    boxShadow: on ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.6), blurRadius: 6)] : null,
                  ),
                ),
                const Spacer(),
                Text('$pin', style: AppText.metric.copyWith(fontSize: 22)),
                Text(on ? 'On' : 'Off', style: AppText.caption),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
