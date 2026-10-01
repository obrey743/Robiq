import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../services/control/robot_controller.dart';
import '../../shared/widgets/ui.dart';
import '../control/control_screen.dart';

const _jointNames = ['Base', 'Shoulder', 'Elbow', 'Wrist pitch', 'Wrist roll', 'Gripper'];
const _homeAngle = 90.0;

String _jointName(int i) => i < _jointNames.length ? _jointNames[i] : 'Joint ${i + 1}';

/// Arm-specific buttons for the control bar.
List<Widget> armActions(BuildContext context) {
  final robot = context.watch<RobotController>();
  return [
    AppIconButton(
      icon: Icons.add_location_alt_outlined,
      size: 48,
      tooltip: 'Teach waypoint',
      onTap: robot.isProgramActive ? null : robot.teachWaypoint,
    ),
    AppIconButton(
      icon: Icons.playlist_play,
      size: 48,
      tooltip: 'Program',
      selected: robot.isProgramActive,
      onTap: () => _showProgram(context),
    ),
  ];
}

/// Arm teach pendant over a live side-view model of the arm.
class ArmControlScreen extends StatefulWidget {
  const ArmControlScreen({super.key});

  @override
  State<ArmControlScreen> createState() => _ArmControlScreenState();
}

class _ArmControlScreenState extends State<ArmControlScreen> {
  int _joint = 2;

  /// Jog increment in degrees; `null` = continuous while held.
  int? _step;

  @override
  Widget build(BuildContext context) {
    final robot = context.watch<RobotController>();
    final joints = robot.joints;
    final enabled = robot.canJog;
    if (_joint >= joints.length) _joint = joints.length - 1;
    final step = _step;

    void jog(int dir) => step == null ? robot.startJog(_joint, dir) : robot.stepJoint(_joint, dir * step.toDouble());

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 600;
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ArmViewPainter(
                  joints: joints,
                  selected: _joint,
                  waypoints: robot.program,
                  current: robot.isProgramActive ? robot.programIndex : null,
                  narrow: !wide,
                ),
              ),
            ),
            if (wide)
              Positioned(
                left: 12,
                top: 12,
                child: Glass(
                  padding: const EdgeInsets.all(6),
                  child: SizedBox(
                    width: 190,
                    child: Column(
                      children: [
                        for (var i = 0; i < joints.length; i++)
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(() => _joint = i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: i == _joint ? AppColors.accent.withValues(alpha: 0.16) : null,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _jointName(i),
                                    style: AppText.label.copyWith(
                                      color: i == _joint ? AppColors.text : AppColors.text2,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text('${joints[i].round()}°', style: AppText.mono),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            if (robot.isProgramActive)
              Positioned(
                left: 0,
                right: 0,
                top: 12,
                child: Center(
                  child: Glass(
                    child: Text('Waypoint ${robot.programIndex + 1} of ${robot.program.length}', style: AppText.label),
                  ),
                ),
              ),
            const Positioned(right: 12, top: 12, child: ViewportStatus()),
            // Joint selector and jog buttons.
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: Glass(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<int>(
                        tooltip: 'Select joint',
                        position: PopupMenuPosition.under,
                        onSelected: (i) => setState(() => _joint = i),
                        itemBuilder: (_) => [
                          for (var i = 0; i < joints.length; i++)
                            CheckedPopupMenuItem(value: i, checked: i == _joint, child: Text(_jointName(i))),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_jointName(_joint), style: AppText.label),
                            const Icon(Icons.expand_more, size: 18, color: AppColors.text2),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      AppIconButton(
                        icon: Icons.add,
                        size: 54,
                        round: true,
                        tooltip: 'Increase',
                        onPress: enabled ? () => jog(1) : null,
                        onRelease: robot.stopJog,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text('${joints[_joint].round()}°', style: AppText.metric.copyWith(fontSize: 24)),
                      ),
                      AppIconButton(
                        icon: Icons.remove,
                        size: 54,
                        round: true,
                        tooltip: 'Decrease',
                        onPress: enabled ? () => jog(-1) : null,
                        onRelease: robot.stopJog,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.home_outlined,
                    tooltip: 'Hold to move home',
                    onPress: enabled ? () => robot.startMoveTo(List.filled(joints.length, _homeAngle)) : null,
                    onRelease: robot.stopMove,
                  ),
                  const SizedBox(width: 8),
                  Segmented<int?>(
                    height: 44,
                    options: const {null: 'Hold', 1: '1°', 5: '5°', 10: '10°'},
                    value: _step,
                    onChanged: (v) => setState(() => _step = v),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Side-view model of the arm drawn from live joint angles. Base yaw is shown
/// by foreshortening the arm; taught waypoints appear as numbered markers at
/// their gripper positions.
class _ArmViewPainter extends CustomPainter {
  _ArmViewPainter({
    required this.joints,
    required this.selected,
    required this.waypoints,
    required this.narrow,
    this.current,
  });

  final List<double> joints;
  final int selected;
  final List<List<double>> waypoints;
  final bool narrow;
  final int? current;

  static double _rad(double deg) => deg * math.pi / 180;

  /// Joint pivot points from shoulder to gripper tip for a pose.
  static List<Offset> _chain(List<double> j, Offset shoulder, double scale) {
    double at(int i) => i < j.length ? j[i] : _homeAngle;
    var yaw = math.cos(_rad(at(0) - 90));
    if (yaw.abs() < 0.15) yaw = 0.15 * (yaw.isNegative ? -1 : 1);

    final a1 = _rad(at(1));
    final a2 = a1 + _rad(at(2) - 180);
    final a3 = a2 + _rad(at(3) - 90);
    Offset step(Offset from, double a, double len) => from + Offset(math.cos(a) * len * yaw, -math.sin(a) * len);

    final elbow = step(shoulder, a1, scale * 0.30);
    final wrist = step(elbow, a2, scale * 0.26);
    final tip = step(wrist, a3, scale * 0.12);
    return [shoulder, elbow, wrist, tip];
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.9,
          colors: [Color(0xFF141922), AppColors.viewport],
        ).createShader(Offset.zero & size),
    );

    // Leave room for the jog controls on the right of narrow screens.
    final scale = math.min(size.height * (narrow ? 0.78 : 0.9), size.width * (narrow ? 0.55 : 0.85));
    final floorY = size.height * 0.84;
    final baseX = size.width * (narrow ? 0.36 : 0.5);

    // Perspective floor grid.
    final grid = Paint()
      ..color = AppColors.gridMajor
      ..strokeWidth = 1;
    for (var i = -12; i <= 12; i++) {
      canvas.drawLine(Offset(baseX + i * 50.0, floorY), Offset(baseX + i * 130.0, size.height), grid);
    }
    for (var k = 0; k < 5; k++) {
      final t = k / 4;
      final y = floorY + (size.height - floorY) * t * t;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Pedestal.
    final shoulder = Offset(baseX, floorY - scale * 0.16);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(baseX, floorY), width: scale * 0.34, height: scale * 0.06),
      Paint()
        ..color = const Color(0xCC000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    final pedestal = RRect.fromRectAndRadius(
      Rect.fromLTRB(baseX - scale * 0.07, shoulder.dy, baseX + scale * 0.07, floorY),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      pedestal,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF2E343D), Color(0xFF1C2027)],
        ).createShader(pedestal.outerRect),
    );
    if (selected == 0) _highlight(canvas, pedestal.outerRect.center, scale * 0.1);

    // Waypoint markers.
    for (var w = 0; w < waypoints.length; w++) {
      final tip = _chain(waypoints[w], shoulder, scale).last;
      final isCurrent = current == w;
      canvas.drawCircle(tip, 10, Paint()..color = isCurrent ? AppColors.accent : AppColors.surface3);
      canvas.drawCircle(
        tip,
        10,
        Paint()
          ..color = isCurrent ? AppColors.accent : AppColors.borderStrong
          ..style = PaintingStyle.stroke,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${w + 1}',
          style: AppText.label.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, tip - Offset(tp.width / 2, tp.height / 2));
    }

    // Arm links.
    final pts = _chain(joints, shoulder, scale);
    final widths = [scale * 0.06, scale * 0.048, scale * 0.034];
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        pts[i],
        pts[i + 1],
        Paint()
          ..color = const Color(0x66000000)
          ..strokeWidth = widths[i] + 4
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        pts[i],
        pts[i + 1],
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFF2C94C), Color(0xFFC99A1E)],
          ).createShader(Rect.fromPoints(pts[i], pts[i + 1]).inflate(widths[i]))
          ..strokeWidth = widths[i]
          ..strokeCap = StrokeCap.round,
      );
    }

    // Joint hubs.
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(pts[i], widths[i] * 0.52, Paint()..color = const Color(0xFF2A2F37));
      canvas.drawCircle(pts[i], widths[i] * 0.2, Paint()..color = const Color(0xFF59616D));
    }

    // Gripper jaws; opening follows the gripper joint.
    final grip = joints.length > 5 ? joints[5] : _homeAngle;
    final dir = (pts[3] - pts[2]).direction;
    final open = _rad(8 + grip / 180 * 32);
    final jaw = Paint()
      ..color = const Color(0xFF59616D)
      ..strokeWidth = scale * 0.014
      ..strokeCap = StrokeCap.round;
    for (final s in [-1, 1]) {
      canvas.drawLine(pts[3], pts[3] + Offset.fromDirection(dir + s * open, scale * 0.06), jaw);
    }

    // Selection ring on the active joint.
    final ringAt = switch (selected) {
      1 => pts[0],
      2 => pts[1],
      3 || 4 => pts[2],
      0 => null,
      _ => pts[3],
    };
    if (ringAt != null) _highlight(canvas, ringAt, scale * 0.05);
  }

  void _highlight(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r + 6, Paint()..color = AppColors.accent.withValues(alpha: 0.12));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ArmViewPainter old) => true;
}

// ── Program sheet ──────────────────────────────────────────────────────────

void _showProgram(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const FractionallySizedBox(heightFactor: 0.75, child: _ProgramSheet()),
  );
}

class _ProgramSheet extends StatelessWidget {
  const _ProgramSheet();

  @override
  Widget build(BuildContext context) {
    final robot = context.watch<RobotController>();
    final program = robot.program;
    final active = robot.isProgramActive;
    final paused = robot.state == RobotState.paused;

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
                    Text('Program', style: AppText.title.copyWith(fontSize: 20)),
                    Text(
                      active
                          ? 'Waypoint ${robot.programIndex + 1} of ${program.length}'
                          : '${program.length} waypoint${program.length == 1 ? '' : 's'}',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              Text('Loop', style: AppText.label.copyWith(color: AppColors.text2)),
              const SizedBox(width: 8),
              Switch(value: robot.loop, onChanged: (v) => robot.loop = v),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: paused ? 'Resume' : 'Run',
                  icon: Icons.play_arrow_rounded,
                  variant: ButtonVariant.primary,
                  expand: true,
                  onPressed: paused ? robot.resumeProgram : (robot.canRunProgram ? robot.runProgram : null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'Pause',
                  icon: Icons.pause_rounded,
                  expand: true,
                  onPressed: robot.state == RobotState.running ? robot.pauseProgram : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'Stop',
                  icon: Icons.stop_rounded,
                  expand: true,
                  onPressed: active ? robot.stopProgram : null,
                ),
              ),
            ],
          ),
          if (robot.mode != OperatingMode.auto && program.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Text('Switch to Auto mode to run', style: AppText.caption.copyWith(color: AppColors.warning)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: program.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const IconTile(Icons.route_outlined, size: 48),
                        const SizedBox(height: 12),
                        Text('No waypoints yet', style: AppText.bodyStrong),
                        const SizedBox(height: 4),
                        Text('Jog the arm to a pose and tap Teach.', style: AppText.caption),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: GroupedList(
                      children: [
                        for (var i = 0; i < program.length; i++)
                          _WaypointRow(index: i, pose: program[i], current: active && robot.programIndex == i),
                      ],
                    ),
                  ),
          ),
          if (program.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppButton(
              label: 'Clear program',
              icon: Icons.delete_outline,
              variant: ButtonVariant.ghost,
              onPressed: active ? null : () => _confirmClear(context, robot),
            ),
          ],
        ],
      ),
    );
  }
}

class _WaypointRow extends StatelessWidget {
  const _WaypointRow({required this.index, required this.pose, required this.current});

  final int index;
  final List<double> pose;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final robot = context.watch<RobotController>();
    return Container(
      color: current ? AppColors.accent.withValues(alpha: 0.08) : null,
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: current ? AppColors.accent : AppColors.surface3,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${index + 1}', style: AppText.label.copyWith(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              [for (final a in pose) '${a.round()}°'].join('   '),
              style: AppText.mono.copyWith(color: AppColors.text2),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppIconButton(
            icon: Icons.near_me_outlined,
            size: 36,
            tooltip: 'Hold to move here',
            onPress: robot.canJog ? () => robot.startMoveTo(pose) : null,
            onRelease: robot.stopMove,
          ),
          PopupMenuButton<String>(
            enabled: !robot.isProgramActive,
            tooltip: 'Waypoint options',
            iconColor: AppColors.text2,
            onSelected: (v) => v == 'update' ? robot.overwriteWaypoint(index) : robot.deleteWaypoint(index),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'update', child: Text('Update to current pose')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmClear(BuildContext context, RobotController robot) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Clear program?'),
      content: const Text('All taught waypoints will be deleted. This can’t be undone.'),
      actions: [
        AppButton(label: 'Cancel', variant: ButtonVariant.ghost, onPressed: () => Navigator.pop(c, false)),
        AppButton(label: 'Clear', variant: ButtonVariant.danger, onPressed: () => Navigator.pop(c, true)),
      ],
    ),
  );
  if (ok == true) robot.clearProgram();
}
