import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  PermissionsService._();

  /// Requests the runtime permissions needed for BLE scanning.
  /// Desktop and web platforms need no runtime permission here.
  static Future<bool> requestBluetooth() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return true;
    if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      return status.isGranted || status.isLimited;
    }
    // Android 12+ uses the scan/connect permissions; older versions need
    // location for BLE scanning, so request it too but don't hard-require it.
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    return results[Permission.bluetoothScan]!.isGranted && results[Permission.bluetoothConnect]!.isGranted;
  }
}
