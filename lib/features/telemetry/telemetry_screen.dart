import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/telemetry.dart';
import '../../services/connection/connection_manager.dart';
import '../../services/control/robot_controller.dart';
import '../../services/settings_service.dart';
import '../../shared/widgets/ui.dart';
import '../control/widgets/event_log_sheet.dart';
import 'widgets/sparkline.dart';

/// Live dashboard of every telemetry key the robot sends (or the simulator
/// generates), with units, trends and health colouring, plus the device log.
class TelemetryScreen extends StatelessWidget {
  const TelemetryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ConnectionManager>();
    final robot = context.watch<RobotController>();
    final telemetry = manager.telemetry;
    final log = manager.log;
    final source = robot.simulated ? 'Simulated robot' : manager.device?.name ?? 'Robot';
    final alerts = robot.unacknowledgedAlarms;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Row(
          children: [
            _LiveDot(active: telemetry.isNotEmpty),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                telemetry.isEmpty ? 'No data' : 'Live · $source',
                style: AppText.bodyStrong.copyWith(color: telemetry.isEmpty ? AppColors.text2 : AppColors.text),
              ),
            ),
            AppButton(
              label: alerts > 0 ? '$alerts alert${alerts == 1 ? '' : 's'}' : 'Event log',
              icon: alerts > 0 ? Icons.warning_amber_rounded : Icons.receipt_long_outlined,
              height: 36,
              onPressed: () => showEventLog(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (telemetry.isEmpty)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              children: [
                const IconTile(Icons.sensors, size: 52),
                const SizedBox(height: 16),
                Text('Waiting for telemetry', style: AppText.title),
                const SizedBox(height: 6),
                Text(
                  robot.simulated
                      ? 'Power on the robot in Control to start the simulator.'
                      : 'Send {"type":"telemetry","data":{…}} from your firmware to fill this page.',
                  textAlign: TextAlign.center,
                  style: AppText.caption,
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              final columns = c.maxWidth >= 900
                  ? 4
                  : c.maxWidth >= 600
                  ? 3
                  : 2;
              final width = (c.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final e in telemetry.entries)
                    SizedBox(
                      width: width,
                      child: _MetricCard(name: e.key, samples: e.value),
                    ),
                ],
              );
            },
          ),
        const SectionHeader('Device log'),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: log.isEmpty
              ? Text('No messages from the robot yet.', style: AppText.caption)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in log.reversed.take(50))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(line, style: AppText.mono.copyWith(fontSize: 12, color: AppColors.text2)),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// How a telemetry key is labelled and formatted.
class _Metric {
  const _Metric(this.label, this.unit, {this.decimals = 1});

  final String label;
  final String unit;
  final int decimals;

  static _Metric of(String key) {
    final k = key.toLowerCase();
    if (k.contains('bat') || k.contains('volt') || k == 'v' || k.contains('vin')) {
      return const _Metric('Battery', 'V', decimals: 2);
    }
    if (k.contains('temp')) return const _Metric('Temperature', '°C');
    if (k.contains('curr') || k.contains('amp')) return const _Metric('Current', 'A', decimals: 2);
    if (k.contains('rssi') || k.contains('signal')) return const _Metric('Signal', 'dBm', decimals: 0);
    if (k.contains('uptime')) return const _Metric('Uptime', '', decimals: 0);
    if (k.contains('humid')) return const _Metric('Humidity', '%', decimals: 0);
    if (k.contains('speed')) return const _Metric('Speed', 'm/s', decimals: 2);
    if (k.contains('dist')) return const _Metric('Distance', 'cm');
    return _Metric(key[0].toUpperCase() + key.substring(1), '', decimals: 2);
  }
}

/// Rough state of charge for 1S–4S lithium packs, from resting voltage.
int? _batteryPercent(double v) {
  for (var cells = 1; cells <= 4; cells++) {
    final lo = 3.0 * cells, hi = 4.2 * cells;
    if (v >= lo - 0.3 && v <= hi + 0.3) return ((v - lo) / (hi - lo) * 100).clamp(0, 100).round();
  }
  return null;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.name, required this.samples});

  final String name;
  final List<TelemetrySample> samples;

  @override
  Widget build(BuildContext context) {
    final metric = _Metric.of(name);
    final values = [for (final s in samples) s.value];
    final last = values.last;
    final low = context.select<SettingsService, double>((s) => s.lowBatteryVolts);

    final (Color color, String? status) = metric.unit == 'V' && last < low
        ? (AppColors.danger, 'Low')
        : metric.unit == '°C' && last > AppConstants.overTempC
        ? (AppColors.warning, 'Hot')
        : (AppColors.accent, null);

    // Trend: latest value against the average of the previous few.
    final window = values.length > 10 ? values.sublist(values.length - 11, values.length - 1) : <double>[];
    final avg = window.isEmpty ? last : window.reduce((a, b) => a + b) / window.length;
    final delta = last - avg;
    final threshold = math.max(0.005, (values.reduce(math.max) - values.reduce(math.min)) * 0.05);
    final trend = delta > threshold
        ? Icons.trending_up
        : delta < -threshold
        ? Icons.trending_down
        : Icons.trending_flat;

    final text = metric.label == 'Uptime' ? _duration(last) : last.toStringAsFixed(metric.decimals);
    final percent = metric.unit == 'V' ? _batteryPercent(last) : null;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      borderColor: status == null ? null : color.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  metric.label,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label.copyWith(color: AppColors.text2),
                ),
              ),
              if (status != null) AppBadge(status, color: color) else Icon(trend, size: 16, color: AppColors.text3),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(text, style: AppText.metric.copyWith(color: status == null ? AppColors.text : color)),
              const SizedBox(width: 4),
              Text(metric.unit, style: AppText.label.copyWith(color: AppColors.text3)),
              const Spacer(),
              if (percent != null) Text('$percent%', style: AppText.mono.copyWith(color: AppColors.text2)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: Sparkline(values: values, color: color),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Min ', style: AppText.caption.copyWith(color: AppColors.text3)),
              Text(
                values.reduce(math.min).toStringAsFixed(metric.decimals),
                style: AppText.mono.copyWith(fontSize: 12),
              ),
              const SizedBox(width: 12),
              Text('Max ', style: AppText.caption.copyWith(color: AppColors.text3)),
              Text(
                values.reduce(math.max).toStringAsFixed(metric.decimals),
                style: AppText.mono.copyWith(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _duration(double seconds) {
    final s = seconds.round();
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m ${sec.toString().padLeft(2, '0')}s';
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.active});

  final bool active;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    if (widget.active) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_LiveDot old) {
    super.didUpdateWidget(old);
    if (widget.active && !_pulse.isAnimating) _pulse.repeat(reverse: true);
    if (!widget.active) _pulse.stop();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: widget.active ? Tween(begin: 0.35, end: 1.0).animate(_pulse) : const AlwaysStoppedAnimation(1),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.active ? AppColors.success : AppColors.text3, shape: BoxShape.circle),
      ),
    );
  }
}
