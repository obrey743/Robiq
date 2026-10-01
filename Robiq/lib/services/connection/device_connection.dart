import 'dart:async';

import '../../data/models/connection_type.dart';

/// Transport-agnostic link to a device. Implementations deliver raw text
/// chunks; framing into lines happens in [ConnectionManager].
abstract class DeviceConnection {
  Stream<String> get incoming;
  Stream<DeviceConnectionStatus> get status;

  Future<void> connect();
  Future<void> send(String data);
  Future<void> disconnect();
}
