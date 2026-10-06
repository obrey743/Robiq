import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/robot_component.dart';
import '../../services/control/component_controller.dart';
import '../../services/control/robot_controller.dart';
import '../../shared/widgets/ui.dart';
import 'components_editor.dart';

const componentIcons = {
  ComponentIcon.light: Icons.lightbulb_outline,
  ComponentIcon.horn: Icons.campaign_outlined,
  ComponentIcon.fan: Icons.mode_fan_off_outlined,
  ComponentIcon.pump: Icons.water_drop_outlined,
  ComponentIcon.gripper: Icons.back_hand_outlined,
  ComponentIcon.laser: Icons.flare,
  ComponentIcon.power: Icons.power_settings_new,
  ComponentIcon.generic: Icons.toggle_on_outlined,
};

/// Pill button for one component. Toggles on tap, or for momentary
/// components stays on only while held.
class ComponentButton extends StatefulWidget {
  const ComponentButton({super.key, required this.component, required this.enabled});

  final RobotComponent component;
  final bool enabled;

  @override
  State<ComponentButton> createState() => _ComponentButtonState();
}

class _ComponentButtonState extends State<ComponentButton> {
  bool _held = false;

  @override
  void didUpdateWidget(ComponentButton old) {
    super.didUpdateWidget(old);
    // Disabled mid-hold (power off, E-stop): let go of a momentary output.
    if (_held && !widget.enabled) {
      _held = false;
      final controller = context.read<ComponentController>();
      final c = old.component;
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.release(c));
    }
  }

  void _down() {
    if (!widget.enabled) return;
    HapticFeedback.selectionClick();
    final controller = context.read<ComponentController>();
    if (widget.component.momentary) {
      _held = true;
      controller.press(widget.component);
    } else {
      controller.toggle(widget.component);
    }
  }

  void _up() {
    if (!_held) return;
    _held = false;
    context.read<ComponentController>().release(widget.component);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.component;
    final on = context.select<ComponentController, bool>((ctl) => ctl.isOn(c));
    final fg = !widget.enabled
        ? AppColors.text3
        : on
        ? AppColors.onAccent
        : AppColors.text;

    return Semantics(
      button: true,
      toggled: c.momentary ? null : on,
      label: c.name,
      child: Tooltip(
        message: c.momentary ? '${c.name} (hold) · GPIO ${c.pin}' : '${c.name} · GPIO ${c.pin}',
        child: Listener(
          onPointerDown: (_) => _down(),
          onPointerUp: (_) => _up(),
          onPointerCancel: (_) => _up(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: on ? AppColors.accent : AppColors.surface2.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: on ? AppColors.accent : AppColors.borderStrong),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(componentIcons[c.icon], size: 19, color: fg),
                const SizedBox(width: 8),
                Text(c.name, style: AppText.label.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Every component as a button, plus one to edit the list. Live while the
/// controller is powered.
class ComponentStrip extends StatelessWidget {
  const ComponentStrip({super.key, this.wrap = false});

  /// Wrap onto several lines instead of scrolling sideways.
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final components = context.select<ComponentController, List<RobotComponent>>((c) => c.components);
    final powered = context.select<RobotController, bool>((r) => r.isPowered);
    final children = [
      for (final (i, c) in components.indexed) ComponentButton(key: ValueKey(i), component: c, enabled: powered),
      AppIconButton(
        icon: components.isEmpty ? Icons.add : Icons.tune,
        tooltip: components.isEmpty ? 'Add component' : 'Edit components',
        onTap: () => showComponentsEditor(context),
      ),
    ];
    if (wrap) return Wrap(spacing: 8, runSpacing: 8, children: children);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(spacing: 8, children: children),
    );
  }
}
