import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/connection_type.dart';
import '../../data/models/robot_device.dart';
import '../../services/connection/connection_manager.dart';
import '../../services/control/robot_controller.dart';
import '../../services/permissions_service.dart';
import '../../services/settings_service.dart';
import '../../shared/widgets/ui.dart';
import 'wifi_connect_dialog.dart';

String _kindName(DeviceKind k) => switch (k) {
  DeviceKind.rover => 'Rover',
  DeviceKind.arm => 'Robotic arm',
  DeviceKind.generic => 'I/O board',
};

/// Connect to robots: current link, remembered devices for one-tap
/// reconnect, and a Bluetooth scan that surfaces ROBIQ-compatible devices.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key, this.onOpenConsole});

  final VoidCallback? onOpenConsole;

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  List<ScanResult> _results = [];
  bool _scanning = false;
  bool _showAll = false;
  StreamSubscription<List<ScanResult>>? _resultsSub;
  StreamSubscription<bool>? _scanningSub;

  @override
  void initState() {
    super.initState();
    _resultsSub = FlutterBluePlus.scanResults.listen((r) => setState(() => _results = r));
    _scanningSub = FlutterBluePlus.isScanning.listen((s) => setState(() => _scanning = s));
  }

  @override
  void dispose() {
    _resultsSub?.cancel();
    _scanningSub?.cancel();
    super.dispose();
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _scan() async {
    if (!await FlutterBluePlus.isSupported) {
      _toast('Bluetooth LE isn’t supported on this device');
      return;
    }
    if (!await PermissionsService.requestBluetooth()) {
      _toast('Bluetooth permission was denied');
      return;
    }
    await FlutterBluePlus.startScan(timeout: AppConstants.bleScanTimeout);
  }

  Future<void> _connectBle(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    if (!mounted) return;
    await context.read<ConnectionManager>().connectBluetooth(device);
  }

  /// Advertises one of the UART services ROBIQ firmware uses.
  static bool _compatible(ScanResult r) {
    final ids = r.advertisementData.serviceUuids.map((g) => g.str128.toLowerCase());
    return ids.any((id) => id == BleUuids.nusService || id == BleUuids.hm10Service);
  }

  static String _name(ScanResult r) =>
      r.device.platformName.isNotEmpty ? r.device.platformName : r.advertisementData.advName;

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ConnectionManager>();
    final recent = context.watch<SettingsService>().recentDevices;

    final results =
        [
          for (final r in _results)
            if (_showAll || _compatible(r) || _name(r).isNotEmpty) r,
        ]..sort((a, b) {
          final c = (_compatible(b) ? 1 : 0) - (_compatible(a) ? 1 : 0);
          return c != 0 ? c : b.rssi.compareTo(a.rssi);
        });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _ConnectionCard(onOpenConsole: widget.onOpenConsole),
        if (recent.isNotEmpty) ...[
          const SectionHeader('Recent'),
          GroupedList(
            children: [
              for (final d in recent)
                _RecentRow(
                  device: d,
                  current: manager.device?.id == d.id && manager.status != DeviceConnectionStatus.disconnected,
                ),
            ],
          ),
        ],
        const SectionHeader('Add a robot'),
        GroupedList(
          children: [
            ListRow(
              leading: Icons.bluetooth_searching,
              title: _scanning ? 'Scanning…' : 'Scan for Bluetooth robots',
              subtitle: 'ESP32 · HM-10 · nRF UART',
              trailing: _scanning
                  ? AppButton(
                      label: 'Stop',
                      height: 32,
                      variant: ButtonVariant.ghost,
                      onPressed: FlutterBluePlus.stopScan,
                    )
                  : const Icon(Icons.chevron_right, color: AppColors.text3),
              onTap: _scanning ? null : _scan,
            ),
            ListRow(
              leading: Icons.wifi,
              title: 'Connect over Wi-Fi',
              subtitle: 'WebSocket · port ${AppConstants.defaultWsPort}',
              trailing: const Icon(Icons.chevron_right, color: AppColors.text3),
              onTap: () => showWifiConnectSheet(context),
            ),
          ],
        ),
        if (_scanning || _results.isNotEmpty) ...[
          SectionHeader(
            'Nearby · ${results.length}',
            trailing: GestureDetector(
              onTap: () => setState(() => _showAll = !_showAll),
              child: Text(
                _showAll ? 'Hide unnamed' : 'Show all',
                style: AppText.label.copyWith(color: AppColors.accent),
              ),
            ),
          ),
          if (_scanning)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(2)),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            ),
          if (results.isEmpty && !_scanning)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No robots found. Make sure the robot is powered on and nearby.',
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),
            )
          else if (results.isNotEmpty)
            GroupedList(
              children: [
                for (final r in results)
                  ListRow(
                    title: _name(r).isEmpty ? 'Unnamed device' : _name(r),
                    subtitle: r.device.remoteId.str,
                    leading: Icons.bluetooth,
                    onTap: () => _connectBle(r.device),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_compatible(r)) ...[const AppBadge('ROBIQ'), const SizedBox(width: 10)],
                        SignalBars(rssi: r.rssi),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ],
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({this.onOpenConsole});

  final VoidCallback? onOpenConsole;

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ConnectionManager>();
    final latency = context.select<RobotController, int?>((r) => r.latencyMs);
    final d = manager.device;
    final status = d == null ? DeviceConnectionStatus.disconnected : manager.status;

    final (chip, color, title, detail) = switch (status) {
      DeviceConnectionStatus.connected => (
        'Connected',
        AppColors.success,
        d!.name,
        [
          _kindName(d.kind),
          d.connectionType == ConnectionType.bluetooth ? 'Bluetooth' : 'Wi-Fi',
          if (latency != null) '$latency ms',
        ].join(' · '),
      ),
      DeviceConnectionStatus.connecting => ('Connecting', AppColors.warning, d!.name, 'Establishing link…'),
      DeviceConnectionStatus.error => (
        'Connection failed',
        AppColors.danger,
        d!.name,
        manager.lastError ?? 'Unknown error',
      ),
      DeviceConnectionStatus.disconnected => (
        'Simulation',
        AppColors.text2,
        'No robot connected',
        'The console runs a simulated robot, so you can practise and teach programs before connecting hardware.',
      ),
    };

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(label: chip, color: color),
              const Spacer(),
              if (status == DeviceConnectionStatus.connecting)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: AppText.title.copyWith(fontSize: 22)),
          const SizedBox(height: 4),
          Text(detail, style: AppText.body.copyWith(color: AppColors.text2, fontSize: 14)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Open console',
                  icon: Icons.gamepad_outlined,
                  variant: ButtonVariant.primary,
                  expand: true,
                  onPressed: onOpenConsole,
                ),
              ),
              if (status == DeviceConnectionStatus.error) ...[
                const SizedBox(width: 10),
                AppButton(label: 'Retry', onPressed: () => manager.reconnect(d!)),
              ],
              if (status == DeviceConnectionStatus.connected || status == DeviceConnectionStatus.connecting) ...[
                const SizedBox(width: 10),
                AppButton(label: 'Disconnect', onPressed: manager.disconnect),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.device, required this.current});

  final RobotDevice device;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final manager = context.read<ConnectionManager>();
    final wifi = device.connectionType == ConnectionType.wifi;
    return ListRow(
      leading: wifi ? Icons.wifi : Icons.bluetooth,
      title: device.name,
      subtitle: '${_kindName(device.kind)} · ${wifi ? device.host : 'Bluetooth'}',
      maxLines: 1,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (current)
            const AppBadge('Active', color: AppColors.success)
          else
            AppButton(label: 'Connect', height: 34, onPressed: () => manager.reconnect(device)),
          PopupMenuButton<String>(
            iconColor: AppColors.text3,
            tooltip: 'Options',
            onSelected: (_) => context.read<SettingsService>().forgetDevice(device.id),
            itemBuilder: (_) => const [PopupMenuItem(value: 'forget', child: Text('Forget this robot'))],
          ),
        ],
      ),
    );
  }
}
