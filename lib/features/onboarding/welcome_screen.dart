import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../services/settings_service.dart';
import '../../shared/widgets/robiq_logo.dart';
import '../../shared/widgets/ui.dart';

/// First-launch welcome: what ROBIQ does and the three ideas an operator
/// needs before touching a robot.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _intro;

  static const _points = [
    (Icons.cable_rounded, 'Connect any robot', 'Bluetooth LE or Wi-Fi. Works with ESP32, Arduino and custom firmware.'),
    (
      Icons.verified_user_outlined,
      'Safety built in',
      'Hold to enable motion, a latched STOP, and automatic stop if the link drops.',
    ),
    (
      Icons.science_outlined,
      'Practise in simulation',
      'No robot yet? Drive, jog and teach programs on a simulated one.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  /// Fades and lifts a child in, staggered by [order].
  Widget _reveal(int order, Widget child) {
    final start = (order * 0.12).clamp(0.0, 0.6);
    final anim = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, start + 0.4, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Ambient glow behind the mark.
          Positioned(
            top: -160,
            left: -80,
            right: -80,
            child: Container(
              height: 480,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [AppColors.accent.withValues(alpha: 0.18), AppColors.accent.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                // Scrolls on short screens or with large text; otherwise the
                // button sits at the bottom.
                child: LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight - 56),
                      child: IntrinsicHeight(child: _content()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _reveal(0, const RobiqMark(size: 64)),
        const SizedBox(height: 28),
        _reveal(
          1,
          Text('Control any robot\nfrom one app.', style: AppText.display.copyWith(fontSize: 34, height: 1.12)),
        ),
        const SizedBox(height: 12),
        _reveal(
          2,
          Text(
            'Rovers, robotic arms and I/O boards, with the safety controls of an industrial pendant.',
            style: AppText.body.copyWith(color: AppColors.text2, height: 1.45),
          ),
        ),
        const SizedBox(height: 36),
        for (var i = 0; i < _points.length; i++)
          _reveal(
            3 + i,
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconTile(_points[i].$1, color: AppColors.accent, size: 42),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_points[i].$2, style: AppText.bodyStrong),
                        const SizedBox(height: 3),
                        Text(_points[i].$3, style: AppText.caption.copyWith(height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const Spacer(),
        _reveal(
          6,
          AppButton(
            label: 'Get started',
            variant: ButtonVariant.primary,
            height: 52,
            expand: true,
            onPressed: () => context.read<SettingsService>().onboarded = true,
          ),
        ),
        const SizedBox(height: 12),
        _reveal(6, Center(child: Text('You can connect a robot at any time.', style: AppText.caption))),
      ],
    );
  }
}
