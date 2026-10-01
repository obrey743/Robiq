import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/control/robot_controller.dart';
import '../../../shared/widgets/ui.dart';

void showEventLog(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const FractionallySizedBox(heightFactor: 0.7, child: _EventLog()),
  );
}

class _EventLog extends StatelessWidget {
  const _EventLog();

  @override
  Widget build(BuildContext context) {
    final robot = context.watch<RobotController>();
    final events = robot.events;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Event log', style: AppText.title.copyWith(fontSize: 20)),
                    Text(
                      robot.unacknowledgedAlarms > 0
                          ? '${robot.unacknowledgedAlarms} unacknowledged alerts'
                          : 'All clear',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              AppButton(
                label: 'Acknowledge',
                variant: ButtonVariant.ghost,
                height: 36,
                onPressed: robot.unacknowledgedAlarms > 0 ? robot.acknowledgeAll : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: events.isEmpty
                ? Center(child: Text('No events yet', style: AppText.caption))
                : AppCard(
                    padding: EdgeInsets.zero,
                    child: ListView.separated(
                      itemCount: events.length,
                      separatorBuilder: (_, _) => const Divider(indent: 40),
                      itemBuilder: (context, i) {
                        final e = events[i];
                        final color = switch (e.severity) {
                          EventSeverity.info => AppColors.text3,
                          EventSeverity.warning => AppColors.warning,
                          EventSeverity.error => AppColors.danger,
                        };
                        final unread = !e.acknowledged && e.severity != EventSeverity.info;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  e.message,
                                  style: unread ? AppText.bodyStrong : AppText.body.copyWith(color: AppColors.text2),
                                ),
                              ),
                              Text(
                                e.time.toIso8601String().substring(11, 19),
                                style: AppText.mono.copyWith(fontSize: 12, color: AppColors.text3),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
