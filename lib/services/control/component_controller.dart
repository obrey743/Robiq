import 'package:flutter/foundation.dart';

import '../../data/models/robot_component.dart';
import '../../data/protocol/robiq_protocol.dart';
import '../connection/connection_manager.dart';
import '../settings_service.dart';
import 'robot_controller.dart';

/// Switches the robot's extra components and remembers which are on.
///
/// State is per pin: two buttons wired to the same pin drive one output.
/// Everything switches off on E-stop or power off.
class ComponentController extends ChangeNotifier {
  ComponentController(this._connection, this._settings, this._robot) : _components = _settings.components {
    _wasConnected = _connection.isConnected;
    _connection.addListener(_onConnectionChanged);
    _robot.addListener(_onRobotChanged);
  }

  final ConnectionManager _connection;
  final SettingsService _settings;
  final RobotController _robot;
  final Set<int> _on = {};
  bool _wasConnected = false;
  List<RobotComponent> _components;

  List<RobotComponent> get components => _components;

  bool isOn(RobotComponent c) => _on.contains(c.pin);

  void toggle(RobotComponent c) => _set(c.pin, !isOn(c));

  /// Momentary components: on while held.
  void press(RobotComponent c) => _set(c.pin, true);
  void release(RobotComponent c) => _set(c.pin, false);

  void allOff() {
    for (final pin in List.of(_on)) {
      _set(pin, false);
    }
  }

  void add(RobotComponent c) => _save([..._components, c]);

  void replace(int index, RobotComponent c) {
    final list = List.of(components);
    final old = list[index];
    // Don't leave the old pin stuck on after re-wiring the button.
    if (old.pin != c.pin) _set(old.pin, false);
    list[index] = c;
    _save(list);
  }

  void remove(int index) {
    final list = List.of(components);
    _set(list.removeAt(index).pin, false);
    _save(list);
  }

  void _save(List<RobotComponent> list) {
    _components = List.unmodifiable(list);
    _settings.components = list;
    notifyListeners();
  }

  void _set(int pin, bool on) {
    final changed = on ? _on.add(pin) : _on.remove(pin);
    if (!changed) return;
    _connection.send(RobiqCommand.digital(pin, on));
    notifyListeners();
  }

  void _onRobotChanged() {
    if (!_robot.isPowered) allOff();
  }

  /// A new link means the outputs' real state is unknown (firmware boots with
  /// them off), so start from all off.
  void _onConnectionChanged() {
    final connected = _connection.isConnected;
    if (connected == _wasConnected) return;
    _wasConnected = connected;
    if (_on.isEmpty) return;
    _on.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _connection.removeListener(_onConnectionChanged);
    _robot.removeListener(_onRobotChanged);
    super.dispose();
  }
}
