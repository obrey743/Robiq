import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// ROBIQ component kit. Every screen builds from these so spacing, radii and
/// states stay consistent.

// ── Surfaces ───────────────────────────────────────────────────────────────

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor ?? AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Translucent panel for controls drawn over a robot view.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 10),
      child: Row(
        children: [
          Expanded(child: Text(title.toUpperCase(), style: AppText.overline)),
          ?trailing,
        ],
      ),
    );
  }
}

/// Settings-style grouped list: rows inside one card, separated by hairlines.
class GroupedList extends StatelessWidget {
  const GroupedList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(indent: 16), children[i]],
        ],
      ),
    );
  }
}

class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.maxLines = 2,
  });

  final String title;
  final String? subtitle;
  final IconData? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Subtitle line limit.
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (leading != null) ...[IconTile(leading!), const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.bodyStrong, overflow: TextOverflow.ellipsis),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppText.caption, overflow: TextOverflow.ellipsis, maxLines: maxLines),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Icon on a small rounded tile, used as a list-row leading.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.color = AppColors.text2, this.size = 36});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

// ── Buttons ────────────────────────────────────────────────────────────────

enum ButtonVariant { primary, secondary, ghost, danger }

(Color bg, Color fg, Color border) _buttonColors(ButtonVariant v, bool enabled) {
  if (!enabled) return (AppColors.surface2, AppColors.text3, AppColors.border);
  return switch (v) {
    ButtonVariant.primary => (AppColors.accent, AppColors.onAccent, AppColors.accent),
    ButtonVariant.secondary => (AppColors.surface2, AppColors.text, AppColors.borderStrong),
    ButtonVariant.ghost => (Colors.transparent, AppColors.text, Colors.transparent),
    ButtonVariant.danger => (AppColors.danger, Colors.white, AppColors.danger),
  };
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = ButtonVariant.secondary,
    this.height = 44,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonVariant variant;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = _buttonColors(variant, onPressed != null);
    final button = Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong.copyWith(color: fg, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Button that must be held for [AppConstants.holdToConfirm] before firing,
/// with a fill showing progress. For actions that must not happen by accident.
class HoldButton extends StatefulWidget {
  const HoldButton({
    super.key,
    required this.label,
    required this.onHeld,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onHeld;
  final IconData? icon;
  final ButtonVariant variant;
  final double height;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton> with SingleTickerProviderStateMixin {
  late final AnimationController _hold;

  @override
  void initState() {
    super.initState();
    _hold = AnimationController(vsync: this, duration: AppConstants.holdToConfirm)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          HapticFeedback.mediumImpact();
          widget.onHeld?.call();
          _hold.value = 0;
        }
      });
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onHeld != null;
    final (bg, fg, border) = _buttonColors(widget.variant, enabled);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: Listener(
        onPointerDown: enabled ? (_) => _hold.forward() : null,
        onPointerUp: (_) => _hold.reverse(),
        onPointerCancel: (_) => _hold.reverse(),
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) => Container(
            height: widget.height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: _hold.value,
                  heightFactor: 1,
                  child: ColoredBox(color: Colors.white.withValues(alpha: 0.18)),
                ),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[Icon(widget.icon, size: 18, color: fg), const SizedBox(width: 8)],
                      Text(
                        _hold.value > 0 ? 'Keep holding…' : widget.label,
                        style: AppText.bodyStrong.copyWith(color: fg, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Square or round icon button. Use [onTap] for normal taps, or
/// [onPress]/[onRelease] for hold-to-run motion (fires on touch down, always
/// stops on lift or cancel).
class AppIconButton extends StatefulWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.onPress,
    this.onRelease,
    this.tooltip,
    this.size = 44,
    this.round = false,
    this.selected = false,
    this.badge,
    this.label,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onPress;
  final VoidCallback? onRelease;
  final String? tooltip;
  final double size;
  final bool round;
  final bool selected;
  final String? badge;

  /// Text drawn instead of the icon (e.g. "+").
  final String? label;

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  bool _down = false;

  bool get _enabled => widget.onTap != null || widget.onPress != null;

  void _release() {
    if (!_down) return;
    setState(() => _down = false);
    widget.onRelease?.call();
  }

  @override
  void didUpdateWidget(AppIconButton old) {
    super.didUpdateWidget(old);
    // If the button gets disabled mid-press, still deliver the release.
    if (!_enabled) _release();
  }

  @override
  Widget build(BuildContext context) {
    final active = _down || widget.selected;
    final fg = !_enabled
        ? AppColors.text3
        : active
        ? AppColors.onAccent
        : AppColors.text;
    final radius = widget.round ? widget.size / 2 : 12.0;

    Widget button = Listener(
      onPointerDown: _enabled
          ? (_) {
              HapticFeedback.selectionClick();
              setState(() => _down = true);
              widget.onPress?.call();
            }
          : null,
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.accent : AppColors.surface2.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: active ? AppColors.accent : AppColors.borderStrong),
          ),
          child: widget.label != null
              ? Text(
                  widget.label!,
                  style: AppText.title.copyWith(fontSize: widget.size * 0.42, fontWeight: FontWeight.w500, color: fg),
                )
              : Icon(widget.icon, size: widget.size * 0.45, color: fg),
        ),
      ),
    );

    if (widget.badge != null) {
      button = Badge(
        label: Text(widget.badge!, style: AppText.label.copyWith(fontSize: 11, color: Colors.white)),
        backgroundColor: AppColors.warning,
        offset: const Offset(4, -4),
        child: button,
      );
    }
    return widget.tooltip == null ? button : Tooltip(message: widget.tooltip!, child: button);
  }
}

// ── Status & selection ─────────────────────────────────────────────────────

/// Soft tinted pill with a status dot, e.g. "● Connected".
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color, this.dense = false});

  final String label;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppText.label.copyWith(fontSize: dense ? 12 : 13, color: color),
          ),
        ],
      ),
    );
  }
}

/// iOS-style segmented control.
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, this.onChanged, this.height = 38});

  final Map<T, String> options;
  final T value;

  /// `null` locks the control.
  final ValueChanged<T>? onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final locked = onChanged == null;
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in options.entries)
            Flexible(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: locked ? null : () => onChanged!(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: e.key == value ? AppColors.surface3 : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: e.key == value ? AppColors.borderStrong : Colors.transparent),
                  ),
                  child: Text(
                    e.value,
                    maxLines: 1,
                    style: AppText.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: e.key == value ? (locked ? AppColors.text2 : AppColors.text) : AppColors.text3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AppBadge extends StatelessWidget {
  const AppBadge(this.text, {super.key, this.color = AppColors.accent});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: AppText.label.copyWith(fontSize: 11.5, color: color)),
    );
  }
}

/// Four-bar signal strength from an RSSI in dBm.
class SignalBars extends StatelessWidget {
  const SignalBars({super.key, required this.rssi});

  final int rssi;

  @override
  Widget build(BuildContext context) {
    final bars = rssi >= -60
        ? 4
        : rssi >= -70
        ? 3
        : rssi >= -80
        ? 2
        : 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            width: 3.5,
            height: 5.0 + i * 3.5,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: i < bars ? AppColors.text : AppColors.surface3,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }
}
