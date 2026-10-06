import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/ui.dart';

enum _Dir { forward, back, left, right }

/// Hold-to-drive direction pad. Reports the same normalised offset as
/// [Joystick] (screen coordinates: forward is -y). Holding two directions
/// (e.g. forward + left) drives a curve.
///
/// Arrow keys and W/A/S/D drive it too, for desktop and web.
class DPad extends StatefulWidget {
  const DPad({super.key, required this.onChanged, this.enabled = true, this.buttonSize = 56});

  final ValueChanged<Offset> onChanged;
  final bool enabled;
  final double buttonSize;

  @override
  State<DPad> createState() => _DPadState();
}

class _DPadState extends State<DPad> {
  final Set<_Dir> _touch = {};
  final Set<_Dir> _keys = {};

  static final _keyMap = {
    LogicalKeyboardKey.arrowUp: _Dir.forward,
    LogicalKeyboardKey.keyW: _Dir.forward,
    LogicalKeyboardKey.arrowDown: _Dir.back,
    LogicalKeyboardKey.keyS: _Dir.back,
    LogicalKeyboardKey.arrowLeft: _Dir.left,
    LogicalKeyboardKey.keyA: _Dir.left,
    LogicalKeyboardKey.arrowRight: _Dir.right,
    LogicalKeyboardKey.keyD: _Dir.right,
  };

  Set<_Dir> get _held => {..._touch, ..._keys};

  @override
  void didUpdateWidget(DPad old) {
    super.didUpdateWidget(old);
    // Drop held input silently: we're mid-build, and the parent zeroes its
    // own input when it disables us.
    if (!widget.enabled) {
      _touch.clear();
      _keys.clear();
    }
  }

  void _emit() {
    final held = _held;
    var x = 0.0, y = 0.0;
    if (held.contains(_Dir.left)) x -= 1;
    if (held.contains(_Dir.right)) x += 1;
    if (held.contains(_Dir.forward)) y -= 1;
    if (held.contains(_Dir.back)) y += 1;
    var o = Offset(x, y);
    // Keep diagonals at full stick deflection, not √2.
    if (o.distance > 1) o /= o.distance;
    setState(() {});
    widget.onChanged(o);
  }

  void _setTouch(_Dir d, bool down) {
    if (down ? _touch.add(d) : _touch.remove(d)) _emit();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final dir = _keyMap[event.logicalKey];
    if (dir == null) return KeyEventResult.ignored;
    if (!widget.enabled) return KeyEventResult.handled;
    // Rebuild from what's physically held so repeats and missed key-ups can't
    // leave a direction stuck.
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final next = {
      for (final e in _keyMap.entries)
        if (pressed.contains(e.key)) e.value,
    };
    if (!_setEquals(next, _keys)) {
      _keys
        ..clear()
        ..addAll(next);
      _emit();
    }
    return KeyEventResult.handled;
  }

  void _onFocusChange(bool focused) {
    // Key-ups go elsewhere once focus leaves, so stop rather than run away.
    if (!focused && _keys.isNotEmpty) {
      _keys.clear();
      _emit();
    }
  }

  static bool _setEquals(Set<_Dir> a, Set<_Dir> b) => a.length == b.length && a.containsAll(b);

  @override
  Widget build(BuildContext context) {
    final s = widget.buttonSize;
    const gap = 6.0;
    final held = _held;

    Widget button(_Dir d, IconData icon, String tip) => AppIconButton(
      icon: icon,
      size: s,
      tooltip: tip,
      selected: held.contains(d),
      onPress: widget.enabled ? () => _setTouch(d, true) : null,
      onRelease: () => _setTouch(d, false),
    );

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      onFocusChange: _onFocusChange,
      child: SizedBox(
        width: s * 3 + gap * 2,
        height: s * 3 + gap * 2,
        child: Stack(
          children: [
            Positioned(left: s + gap, top: 0, child: button(_Dir.forward, Icons.keyboard_arrow_up_rounded, 'Forward')),
            Positioned(left: 0, top: s + gap, child: button(_Dir.left, Icons.keyboard_arrow_left_rounded, 'Left')),
            Positioned(right: 0, top: s + gap, child: button(_Dir.right, Icons.keyboard_arrow_right_rounded, 'Right')),
            Positioned(left: s + gap, bottom: 0, child: button(_Dir.back, Icons.keyboard_arrow_down_rounded, 'Back')),
            // Hub: lights up while any direction is held.
            Positioned(
              left: s + gap,
              top: s + gap,
              child: SizedBox(
                width: s,
                height: s,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    width: s * 0.3,
                    height: s * 0.3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: held.isNotEmpty ? AppColors.accent : AppColors.surface3,
                      border: Border.all(color: AppColors.borderStrong),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
