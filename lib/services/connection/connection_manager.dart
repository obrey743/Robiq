import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/connection_type.dart';
import '../../data/models/robot_device.dart';
import '../../data/models/telemetry.dart';
import '../../data/protocol/robiq_protocol.dart';
import 'bluetooth_connection.dart';
import 'device_connection.dart';
import 'wifi_connection.dart';

/// Owns the active device connection and exposes its state to the UI.
class ConnectionManager extends ChangeNotifier {
  DeviceConnection? _connection;
  StreamSubscription<String>? _incomingSub;
  StreamSubscription<DeviceConnectionStatus>? _statusSub;
  var _lineBuffer = LineBuffer();

  RobotDevice? _device;
  DeviceKind _selectedKind = DeviceKind.generic;
  DeviceConnectionStatus _status = DeviceConnectionStatus.disconnected;
  String? _lastError;

  final Map<String, ListQueue<TelemetrySample>> _telemetry = {};
  final ListQueue<String> _log = ListQueue();
  final _messages = StreamController<RobiqMessage>.broadcast();

  RobotDevice? get device => _device;

  /// Control surface to show. Falls back to the user's last manual choice so
  /// controls stay usable while offline.
  DeviceKind get kind => _device?.kind ?? _selectedKind;
  DeviceConnectionStatus get status => _status;
  bool get isConnected => _status == DeviceConnectionStatus.connected;
  String? get lastError => _lastError;
  Map<String, List<TelemetrySample>> get telemetry => {for (final e in _telemetry.entries) e.key: e.value.toList()};
  List<String> get log => _log.toList();

  /// Every parsed message from the device, for services that need more than
  /// the aggregated state (e.g. heartbeat replies).
  Stream<RobiqMessage> get messages => _messages.stream;

  Future<void> connectBluetooth(BluetoothDevice bleDevice) {
    final name = bleDevice.platformName.isNotEmpty ? bleDevice.platformName : bleDevice.remoteId.str;
    return _connect(
      BluetoothConnection(bleDevice),
      RobotDevice(
        id: bleDevice.remoteId.str,
        name: name,
        connectionType: ConnectionType.bluetooth,
        kind: _selectedKind,
      ),
    );
  }

  Future<void> connectWifi({required String host, int port = AppConstants.defaultWsPort, String? name}) {
    return _connect(
      WifiConnection(host: host, port: port),
      RobotDevice(
        id: '$host:$port',
        name: name ?? host,
        connectionType: ConnectionType.wifi,
        kind: _selectedKind,
        host: host,
        port: port,
      ),
    );
  }

  /// Reconnects to a remembered device, restoring its robot type until the
  /// firmware reports its own.
  Future<void> reconnect(RobotDevice d) {
    _selectedKind = d.kind;
    return switch (d.connectionType) {
      ConnectionType.bluetooth => connectBluetooth(BluetoothDevice.fromId(d.id)),
      ConnectionType.wifi => connectWifi(
        host: d.host ?? d.id.split(':').first,
        port: d.port ?? AppConstants.defaultWsPort,
        name: d.name,
      ),
    };
  }

  Future<void> _connect(DeviceConnection connection, RobotDevice device) async {
    await disconnect();
    _connection = connection;
    _device = device;
    _lastError = null;
    _telemetry.clear();
    _lineBuffer = LineBuffer();
    _statusSub = connection.status.listen(_setStatus);
    _incomingSub = connection.incoming.listen(_onChunk);
    try {
      await connection.connect();
      await send(RobiqCommand.info());
    } catch (e) {
      _lastError = e.toString();
      _setStatus(DeviceConnectionStatus.error);
    }
  }

  Future<void> disconnect() async {
    final conn = _connection;
    if (conn == null) return;
    _connection = null;
    await _incomingSub?.cancel();
    await _statusSub?.cancel();
    try {
      await conn.disconnect();
    } catch (_) {}
    _setStatus(DeviceConnectionStatus.disconnected);
  }

  Future<void> send(RobiqCommand command) async {
    if (!isConnected) return;
    try {
      await _connection?.send(command.encode());
    } catch (e) {
      _addLog('send failed: $e');
    }
  }

  /// Manually override the device type (e.g. firmware without `info` support).
  void setDeviceKind(DeviceKind kind, {int? jointCount}) {
    _selectedKind = kind;
    _device = _device?.copyWith(kind: kind, jointCount: jointCount);
    notifyListeners();
  }

  void _setStatus(DeviceConnectionStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }

  void _onChunk(String chunk) {
    for (final line in _lineBuffer.add(chunk)) {
      final msg = RobiqMessage.parse(line);
      if (msg != null) _messages.add(msg);
      switch (msg) {
        case TelemetryMessage(:final values):
          _ingest(values);
        case InfoMessage(:final name, :final kind, :final jointCount):
          _device = _device?.copyWith(name: name, kind: kind, jointCount: jointCount);
        case LogMessage(:final text):
          _addLog(text);
        case PongMessage() || null:
          break;
      }
    }
    notifyListeners();
  }

  /// Adds telemetry that didn't come from a device (e.g. the simulator).
  void ingestTelemetry(Map<String, double> values) {
    _ingest(values);
    notifyListeners();
  }

  void _ingest(Map<String, double> values) {
    final now = DateTime.now();
    values.forEach((key, value) {
      final q = _telemetry.putIfAbsent(key, ListQueue.new);
      q.add(TelemetrySample(now, value));
      while (q.length > AppConstants.telemetryHistoryLength) {
        q.removeFirst();
      }
    });
  }

  void _addLog(String text) {
    _log.addLast('${DateTime.now().toIso8601String().substring(11, 19)}  $text');
    while (_log.length > 200) {
      _log.removeFirst();
    }
  }

  @override
  void dispose() {
    disconnect();
    _messages.close();
    super.dispose();
  }
}
