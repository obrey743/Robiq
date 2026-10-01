import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/connection_type.dart';
import 'device_connection.dart';

/// BLE connection using a UART-style service (Nordic UART or HM-10).
class BluetoothConnection implements DeviceConnection {
  BluetoothConnection(this.device);

  final BluetoothDevice device;

  final _incoming = StreamController<String>.broadcast();
  final _status = StreamController<DeviceConnectionStatus>.broadcast();

  BluetoothCharacteristic? _writeChar;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _stateSub;
  int _mtu = 23;

  @override
  Stream<String> get incoming => _incoming.stream;

  @override
  Stream<DeviceConnectionStatus> get status => _status.stream;

  @override
  Future<void> connect() async {
    _status.add(DeviceConnectionStatus.connecting);
    try {
      // ROBIQ is an open-source, non-commercial project. Commercial forks
      // must obtain a flutter_blue_plus commercial license.
      await device.connect(license: License.nonprofit, timeout: const Duration(seconds: 15));
      _mtu = device.mtuNow;

      _stateSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _status.add(DeviceConnectionStatus.disconnected);
        }
      });

      final services = await device.discoverServices();
      BluetoothCharacteristic? notifyChar;
      for (final service in services) {
        final uuid = service.uuid.str128.toLowerCase();
        if (uuid == BleUuids.nusService) {
          for (final c in service.characteristics) {
            final cu = c.uuid.str128.toLowerCase();
            if (cu == BleUuids.nusRx) _writeChar = c;
            if (cu == BleUuids.nusTx) notifyChar = c;
          }
        } else if (uuid == BleUuids.hm10Service) {
          for (final c in service.characteristics) {
            if (c.uuid.str128.toLowerCase() == BleUuids.hm10Char) {
              _writeChar = c;
              notifyChar = c;
            }
          }
        }
      }

      if (_writeChar == null) {
        throw StateError('No supported UART service found on ${device.platformName}');
      }
      if (notifyChar != null) {
        await notifyChar.setNotifyValue(true);
        _notifySub = notifyChar.onValueReceived.listen(
          (bytes) => _incoming.add(utf8.decode(bytes, allowMalformed: true)),
        );
      }
      _status.add(DeviceConnectionStatus.connected);
    } catch (e) {
      _status.add(DeviceConnectionStatus.error);
      await device.disconnect();
      rethrow;
    }
  }

  @override
  Future<void> send(String data) async {
    final char = _writeChar;
    if (char == null) return;
    final bytes = utf8.encode(data);
    final noResponse = char.properties.writeWithoutResponse;
    // Chunk to fit the negotiated MTU (3 bytes ATT header).
    final chunkSize = (_mtu - 3).clamp(20, 512);
    for (var i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, bytes.length);
      await char.write(bytes.sublist(i, end), withoutResponse: noResponse);
    }
  }

  @override
  Future<void> disconnect() async {
    await _notifySub?.cancel();
    await _stateSub?.cancel();
    await device.disconnect();
    _status.add(DeviceConnectionStatus.disconnected);
    await _incoming.close();
    await _status.close();
  }
}
