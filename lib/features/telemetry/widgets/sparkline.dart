import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Minimal line chart for a telemetry history, with a soft fill underneath.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, this.color});

  final List<double> values;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _SparklinePainter(values, color ?? Theme.of(context).colorScheme.primary),
  );
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;
    final dx = size.width / (values.length - 1);
    // Keep a little headroom so the line never touches the edges.
    double y(double v) => size.height - 2 - (v - minV) / range * (size.height - 4);

    final line = Path();
    for (var i = 0; i < values.length; i++) {
      i == 0 ? line.moveTo(0, y(values[i])) : line.lineTo(i * dx, y(values[i]));
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(Offset(size.width, y(values.last)), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values || old.color != color;
}
