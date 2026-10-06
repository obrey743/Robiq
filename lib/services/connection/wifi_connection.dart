import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../data/models/connection_type.dart';
import 'device_connection.dart';

/// Wi-Fi connection over a WebSocket (e.g. `ws://192.168.4.1:81`).
class WifiConnection implements DeviceConnection {
  WifiConnection({required this.host, required this.port});

  final String host;
  final int port;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  final _incoming = StreamController<String>.broadcast();
  final _status = StreamController<DeviceConnectionStatus>.broadcast();

  @override
  Stream<String> get incoming => _incoming.stream;

  @override
  Stream<DeviceConnectionStatus> get status => _status.stream;

  @override
  Future<void> connect() async {
    _status.add(DeviceConnectionStatus.connecting);
    final channel = WebSocketChannel.connect(Uri.parse('ws://$host:$port'));
    try {
      await channel.ready.timeout(const Duration(seconds: 8));
      _channel = channel;
      _sub = channel.stream.listen(
        // Each WebSocket frame is one message; append a newline so framing
        // matches the BLE transport.
        (data) =>
            _incoming.add(data is String ? '$data\n' : '${utf8.decode(data as List<int>, allowMalformed: true)}\n'),
        onDone: () => _status.add(DeviceConnectionStatus.disconnected),
        onError: (_) => _status.add(DeviceConnectionStatus.error),
      );
      _status.add(DeviceConnectionStatus.connected);
    } catch (_) {
      // Don't leave a half-open socket behind after a timeout.
      unawaited(channel.sink.close());
      _status.add(DeviceConnectionStatus.error);
      rethrow;
    }
  }

  @override
  Future<void> send(String data) async => _channel?.sink.add(data.trimRight());

  @override
  Future<void> disconnect() async {
    await _sub?.cancel();
    await _channel?.sink.close();
    _status.add(DeviceConnectionStatus.disconnected);
    await _incoming.close();
    await _status.close();
  }
}
