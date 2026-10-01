import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../services/connection/connection_manager.dart';
import '../../services/settings_service.dart';
import '../../shared/widgets/ui.dart';

void showWifiConnectSheet(BuildContext context) {
  showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => const _WifiConnectSheet());
}

class _WifiConnectSheet extends StatefulWidget {
  const _WifiConnectSheet();

  @override
  State<_WifiConnectSheet> createState() => _WifiConnectSheetState();
}

class _WifiConnectSheetState extends State<_WifiConnectSheet> {
  /// Address the ROBIQ ESP32 firmware uses in access-point mode.
  static const _apDefault = '192.168.4.1';

  late final TextEditingController _host;
  late final TextEditingController _port;
  String? _error;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsService>();
    _host = TextEditingController(text: settings.lastHost);
    _port = TextEditingController(text: '${settings.lastPort}');
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  void _connect() {
    final host = _host.text.trim();
    final port = int.tryParse(_port.text.trim());
    if (host.isEmpty) return setState(() => _error = 'Enter the robot’s IP address.');
    if (port == null || port <= 0 || port > 65535) return setState(() => _error = 'Port must be between 1 and 65535.');
    context.read<SettingsService>().rememberWifiTarget(host, port);
    context.read<ConnectionManager>().connectWifi(host: host, port: port);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Connect over Wi-Fi', style: AppText.title.copyWith(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            'Join the robot’s Wi-Fi network (or the same network as the robot), then enter its address.',
            style: AppText.caption,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _host,
                  style: AppText.mono.copyWith(fontSize: 16),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'IP address'),
                  onSubmitted: (_) => _connect(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _port,
                  style: AppText.mono.copyWith(fontSize: 16),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Port'),
                  onSubmitted: (_) => _connect(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => setState(() {
                _host.text = _apDefault;
                _port.text = '${AppConstants.defaultWsPort}';
                _error = null;
              }),
              child: Text('Use robot hotspot ($_apDefault)', style: AppText.label.copyWith(color: AppColors.accent)),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: AppText.caption.copyWith(color: AppColors.danger)),
            ),
          const SizedBox(height: 20),
          AppButton(label: 'Connect', variant: ButtonVariant.primary, height: 48, expand: true, onPressed: _connect),
        ],
      ),
    );
  }
}
