import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/connection_status_chip.dart';
import '../../shared/widgets/robiq_logo.dart';
import '../control/control_screen.dart';
import '../devices/devices_screen.dart';
import '../settings/settings_screen.dart';
import '../telemetry/telemetry_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _control = 1;
  static const _titles = ['Devices', 'Control', 'Telemetry', 'Settings'];

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // Form-like pages read best at a fixed width on tablets.
    Widget readable(Widget child) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: child),
    );

    final pages = [
      readable(DevicesScreen(onOpenConsole: () => setState(() => _index = _control))),
      const ControlScreen(),
      const TelemetryScreen(),
      readable(const SettingsScreen()),
    ];

    return Scaffold(
      // The console has its own header with robot status and STOP.
      appBar: _index == _control
          ? null
          : AppBar(
              toolbarHeight: 64,
              titleSpacing: 20,
              title: Row(
                children: [
                  const RobiqMark(size: 30),
                  const SizedBox(width: 12),
                  Flexible(child: Text(_titles[_index], overflow: TextOverflow.ellipsis)),
                ],
              ),
              actions: const [ConnectionStatusChip(), SizedBox(width: 16)],
            ),
      body: SafeArea(
        bottom: false,
        top: _index == _control,
        child: _FadeStack(index: _index, children: pages),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.hub_outlined), selectedIcon: Icon(Icons.hub), label: 'Devices'),
            NavigationDestination(
              icon: Icon(Icons.gamepad_outlined),
              selectedIcon: Icon(Icons.gamepad),
              label: 'Control',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Telemetry',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

/// Like [IndexedStack] (every page keeps its state) but cross-fades between
/// pages instead of snapping.
class _FadeStack extends StatelessWidget {
  const _FadeStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          IgnorePointer(
            ignoring: i != index,
            child: ExcludeSemantics(
              excluding: i != index,
              child: AnimatedOpacity(
                opacity: i == index ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: children[i],
              ),
            ),
          ),
      ],
    );
  }
}
