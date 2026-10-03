import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/connection_type.dart';
import '../../services/connection/connection_manager.dart';
import 'ui.dart';

class ConnectionStatusChip extends StatelessWidget {
  const ConnectionStatusChip({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select<ConnectionManager, DeviceConnectionStatus>((m) => m.status);
    final (label, color) = switch (status) {
      DeviceConnectionStatus.connected => ('Connected', AppColors.success),
      DeviceConnectionStatus.connecting => ('Connecting', AppColors.warning),
      DeviceConnectionStatus.error => ('Error', AppColors.danger),
      DeviceConnectionStatus.disconnected => ('Simulation', AppColors.text2),
    };
    return StatusChip(label: label, color: color);
  }
}
