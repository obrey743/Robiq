import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../services/control/robot_controller.dart';
import '../../shared/widgets/ui.dart';
import 'control_screen.dart';
import 'widgets/joystick.dart';

/// Rover-specific buttons for the control bar.
List<Widget> roverActions(BuildContext context) {
  final robot = context.read<RobotController>();
  return [AppIconButton(icon: Icons.my_location, size: 48, tooltip: 'Recenter view', onTap: robot.resetOdometry)];
}

/// Rover teleoperation over a top-down view. The view follows the
/// dead-reckoned pose, so in simulation the rover visibly drives around.
class RoverControlPanel extends StatefulWidget {
  const RoverControlPanel({super.key});

  @override
  State<RoverControlPanel> createState() => _RoverControlPanelState();
}

class _RoverControlPanelState extends State<RoverControlPanel> {
  Offset _stick = Offset.zero;
  Offset _lastSent = Offset.zero;
  Timer? _timer;
  final List<Offset> _trail = [];

  @override
  void initState() {
    super.initState();
    // Send at a fixed rate instead of on every drag event to avoid flooding
    // slow links like BLE.
    _timer = Timer.periodic(AppConstants.controlSendInterval, (_) => _flush());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _flush() {
    if (_stick == _lastSent) return;
    _lastSent = _stick;
    context.read<RobotController>().drive(_stick.dx, -_stick.dy);
  }

  void _setStick(Offset o) => setState(() => _stick = o);

  @override
  Widget build(BuildContext context) {
    final robot = context.watch<RobotController>();
    final active = robot.canJog;

    // Drop any held input the moment motion is no longer allowed.
    if (!active && _stick != Offset.zero) {
      _stick = _lastSent = Offset.zero;
    }

    final pos = robot.position;
    if (pos == Offset.zero) {
      _trail.clear();
    } else if (_trail.isEmpty || (_trail.last - pos).distance > 0.05) {
      _trail.add(pos);
      if (_trail.length > 400) _trail.removeAt(0);
    }

    Widget nudge(IconData icon, Offset dir, String tip) => AppIconButton(
      icon: icon,
      tooltip: tip,
      onPress: active ? () => _setStick(dir) : null,
      onRelease: () => _setStick(Offset.zero),
    );

    final heading = (robot.heading * 180 / math.pi) % 360;

    return LayoutBuilder(
      builder: (context, c) {
        final stickSize = (math.min(c.maxWidth, c.maxHeight) * 0.42).clamp(130.0, 200.0);
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RoverViewPainter(position: pos, heading: robot.heading, trail: List.of(_trail)),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Glass(
                child: Flex(
                  // Stack the readouts on phones so they clear the status panel.
                  direction: c.maxWidth >= 600 ? Axis.horizontal : Axis.vertical,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: c.maxWidth >= 600 ? 14 : 4,
                  children: [
                    _Readout('HDG', '${heading.round().toString().padLeft(3, '0')}°'),
                    _Readout('X', '${pos.dx.toStringAsFixed(2)} m'),
                    _Readout('Y', '${pos.dy.toStringAsFixed(2)} m'),
                  ],
                ),
              ),
            ),
            const Positioned(right: 12, top: 12, child: ViewportStatus()),
            Positioned(
              left: 12,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      nudge(Icons.undo_rounded, const Offset(-1, 0), 'Rotate left'),
                      const SizedBox(width: 6),
                      nudge(Icons.keyboard_arrow_up, const Offset(0, -1), 'Forward'),
                      const SizedBox(width: 6),
                      nudge(Icons.redo_rounded, const Offset(1, 0), 'Rotate right'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  nudge(Icons.keyboard_arrow_down, const Offset(0, 1), 'Reverse'),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: active ? 1 : 0.45,
                child: IgnorePointer(
                  ignoring: !active,
                  child: Joystick(size: stickSize, onChanged: _setStick),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 30, child: Text(label, style: AppText.overline)),
        Text(value, style: AppText.mono),
      ],
    );
  }
}

/// Robot-centred top-down view: the rover stays in the middle pointing up and
/// the floor grid moves and turns beneath it.
class _RoverViewPainter extends CustomPainter {
  _RoverViewPainter({required this.position, required this.heading, required this.trail});

  final Offset position;
  final double heading;
  final List<Offset> trail;

  static const _ppm = 90.0; // pixels per metre
  static const _gridStep = 0.5; // metres

  Offset _world(Offset p) => Offset((p.dx - position.dx) * _ppm, -(p.dy - position.dy) * _ppm);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final center = size.center(Offset.zero);

    // Soft vignette so the robot reads as the focal point.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xFF131820), AppColors.viewport],
          radius: 0.8,
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-heading);

    // Floor grid, snapped to world coordinates so it scrolls with motion.
    final reach = size.longestSide / _ppm;
    final minor = Paint()
      ..color = AppColors.gridMinor
      ..strokeWidth = 1;
    final major = Paint()
      ..color = AppColors.gridMajor
      ..strokeWidth = 1;
    final startX = ((position.dx - reach) / _gridStep).floor();
    final endX = ((position.dx + reach) / _gridStep).ceil();
    final startY = ((position.dy - reach) / _gridStep).floor();
    final endY = ((position.dy + reach) / _gridStep).ceil();
    for (var i = startX; i <= endX; i++) {
      final x = i * _gridStep;
      canvas.drawLine(
        _world(Offset(x, position.dy - reach)),
        _world(Offset(x, position.dy + reach)),
        i % 2 == 0 ? major : minor,
      );
    }
    for (var j = startY; j <= endY; j++) {
      final y = j * _gridStep;
      canvas.drawLine(
        _world(Offset(position.dx - reach, y)),
        _world(Offset(position.dx + reach, y)),
        j % 2 == 0 ? major : minor,
      );
    }

    // Start point.
    final origin = _world(Offset.zero);
    canvas.drawCircle(
      origin,
      9,
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(origin, 2.5, Paint()..color = AppColors.accent);

    // Path driven so far.
    if (trail.length > 1) {
      final path = Path()..moveTo(_world(trail.first).dx, _world(trail.first).dy);
      for (final p in trail.skip(1)) {
        final w = _world(p);
        path.lineTo(w.dx, w.dy);
      }
      final w = _world(position);
      path.lineTo(w.dx, w.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.accent.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.restore();

    _paintRover(canvas, center);
  }

  void _paintRover(Canvas canvas, Offset c) {
    const bodyW = 42.0, bodyH = 64.0, wheelW = 10.0, wheelH = 20.0;

    // Heading cone.
    final cone = Path()
      ..moveTo(c.dx, c.dy - bodyH / 2)
      ..lineTo(c.dx - 70, c.dy - bodyH / 2 - 150)
      ..lineTo(c.dx + 70, c.dy - bodyH / 2 - 150)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [AppColors.accent.withValues(alpha: 0.18), AppColors.accent.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(c.dx - 70, c.dy - bodyH / 2 - 150, 140, 150)),
    );

    canvas.drawOval(
      Rect.fromCenter(center: c + const Offset(0, 4), width: bodyW + 30, height: bodyH + 16),
      Paint()
        ..color = const Color(0x99000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    final wheel = Paint()..color = const Color(0xFF2A2F37);
    for (final dx in [-1, 1]) {
      for (final dy in [-1, 1]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: c + Offset(dx * (bodyW / 2 + wheelW / 2 - 1), dy * (bodyH / 2 - wheelH / 2 - 4)),
              width: wheelW,
              height: wheelH,
            ),
            const Radius.circular(3),
          ),
          wheel,
        );
      }
    }

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: bodyW, height: bodyH),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF2C94C), Color(0xFFC99A1E)],
        ).createShader(body.outerRect),
    );

    // Deck plate and front marker.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + const Offset(0, 6), width: bodyW - 16, height: bodyH - 28),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF2A2F37),
    );
    canvas.drawCircle(c + Offset(0, -bodyH / 2 + 9), 3, Paint()..color = const Color(0xFF2A2F37));
  }

  @override
  bool shouldRepaint(_RoverViewPainter old) =>
      old.position != position || old.heading != heading || old.trail.length != trail.length;
}
