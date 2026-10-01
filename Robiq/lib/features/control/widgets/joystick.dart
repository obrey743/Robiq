import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Virtual joystick. Reports a normalised offset in -1..1 on both axes
/// (screen coordinates: +y is down). Springs back to centre on release.
class Joystick extends StatefulWidget {
  const Joystick({super.key, required this.onChanged, this.size = 220});

  final ValueChanged<Offset> onChanged;
  final double size;

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  Offset _knob = Offset.zero;
  bool _active = false;

  double get _radius => widget.size / 2;

  void _update(Offset local) {
    var delta = local - Offset(_radius, _radius);
    if (delta.distance > _radius) delta = Offset.fromDirection(delta.direction, _radius);
    setState(() {
      _knob = delta;
      _active = true;
    });
    widget.onChanged(delta / _radius);
  }

  void _reset() {
    setState(() {
      _knob = Offset.zero;
      _active = false;
    });
    widget.onChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final knob = widget.size * 0.38;
    return GestureDetector(
      onPanStart: (d) => _update(d.localPosition),
      onPanUpdate: (d) => _update(d.localPosition),
      onPanEnd: (_) => _reset(),
      onPanCancel: _reset,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface.withValues(alpha: 0.85),
          border: Border.all(color: _active ? AppColors.accent.withValues(alpha: 0.6) : AppColors.borderStrong),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Inner guide ring.
            Container(
              width: widget.size * 0.62,
              height: widget.size * 0.62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
            ),
            Transform.translate(
              offset: _knob,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: knob,
                height: knob,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _active ? AppColors.accent : AppColors.surface3,
                  border: Border.all(color: _active ? AppColors.accent : AppColors.borderStrong),
                  boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 10, offset: Offset(0, 3))],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
