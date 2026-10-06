import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The ROBIQ mark: a two-link arm (base, elbow, gripper) on a dark tile.
/// Drawn in code so the app and the generated platform icons share one source.
class RobiqMarkPainter extends CustomPainter {
  const RobiqMarkPainter({this.tile = true, this.cornerRadius = 0.23});

  /// Draw the dark rounded tile behind the mark.
  final bool tile;

  /// Tile corner radius as a fraction of its size (0 for full-bleed icons).
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final o = Offset((size.width - s) / 2, (size.height - s) / 2);
    Offset p(double x, double y) => o + Offset(x * s, y * s);
    final rect = o & Size(s, s);

    if (tile) {
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(s * cornerRadius));
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1D232C), Color(0xFF0B0D11)],
          ).createShader(rect),
      );
      // Soft accent glow behind the elbow.
      canvas.drawCircle(
        p(0.6, 0.36),
        s * 0.42,
        Paint()
          ..shader = RadialGradient(
            colors: [AppColors.accent.withValues(alpha: 0.28), AppColors.accent.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: p(0.6, 0.36), radius: s * 0.42)),
      );
    }

    final base = p(0.3, 0.72);
    final elbow = p(0.56, 0.3);
    final tip = p(0.76, 0.56);
    final width = s * 0.115;

    final link = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width;
    canvas.drawLine(
      base,
      elbow,
      link
        ..shader = const LinearGradient(
          colors: [Color(0xFF7FB0FF), AppColors.accent],
        ).createShader(Rect.fromPoints(base, elbow)),
    );
    canvas.drawLine(
      elbow,
      tip,
      link
        ..shader = const LinearGradient(
          colors: [AppColors.accent, Color(0xFF2F6BE0)],
        ).createShader(Rect.fromPoints(elbow, tip)),
    );

    // Joints.
    final hub = Paint()..color = const Color(0xFF0E1218);
    canvas.drawCircle(base, width * 0.62, Paint()..color = const Color(0xFFDCE7FF));
    canvas.drawCircle(base, width * 0.28, hub);
    canvas.drawCircle(elbow, width * 0.5, Paint()..color = const Color(0xFFDCE7FF));
    canvas.drawCircle(elbow, width * 0.22, hub);

    // Gripper: the one warm accent, matching the robot colour in the app.
    canvas.drawCircle(tip, width * 0.62, Paint()..color = AppColors.robot);
  }

  @override
  bool shouldRepaint(RobiqMarkPainter old) => old.tile != tile || old.cornerRadius != cornerRadius;
}

class RobiqMark extends StatelessWidget {
  const RobiqMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: const RobiqMarkPainter());
}
