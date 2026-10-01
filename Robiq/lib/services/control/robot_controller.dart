import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Offset;

import '../../core/constants/app_constants.dart';
import '../../data/protocol/robiq_protocol.dart';
import '../connection/connection_manager.dart';
import '../settings_service.dart';

/// Robot safety state, modelled on industrial controllers.
///
/// ```
/// powerOff ─power on─▶ idle ─enable─▶ enabled ─run─▶ running ⇄ paused
///     ▲                 ▲  ◀─disable──┘                │
///     └──power off──────┤                              │
///                       └──reset── fault / estop ◀─────┘ (from any state)
/// ```
enum RobotState { powerOff, idle, enabled, running, paused, fault, estop }

/// Manual = jog/drive by hand. Auto = run taught programs; jogging locked.
enum OperatingMode { manual, auto }

enum EventSeverity { info, warning, error }

class RobotEvent {
  RobotEvent(this.severity, this.message) : time = DateTime.now();

  final DateTime time;
  final EventSeverity severity;
  final String message;
  bool acknowledged = false;
}

/// Owns the robot's state machine and gates every motion command through it.
///
/// Works the same with or without a device: while offline it runs in
/// simulation, so operators can learn the controls and teach programs.
class RobotController extends ChangeNotifier {
  RobotController(this._connection, this._settings) {
    _program = _settings.armProgram;
    _wasConnected = _connection.isConnected;
    _connection.addListener(_onConnectionChanged);
    _messageSub = _connection.messages.listen(_onMessage);
    _heartbeat = Timer.periodic(AppConstants.heartbeatInterval, (_) => _beat());
    _sim = Timer.periodic(AppConstants.simTelemetryInterval, (_) => _simTick());
    _syncJointCount();

    final recent = _settings.recentDevices;
    if (_settings.autoConnect && recent.isNotEmpty && !_connection.isConnected) {
      scheduleMicrotask(() => _connection.reconnect(recent.first));
    }
  }

  final ConnectionManager _connection;
  final SettingsService _settings;
  late final StreamSubscription<RobiqMessage> _messageSub;
  late final Timer _heartbeat;
  late final Timer _sim;

  RobotState _state = RobotState.powerOff;
  OperatingMode _mode = OperatingMode.manual;
  double _speedOverride = 0.25;
  String? _faultReason;
  final ListQueue<RobotEvent> _events = ListQueue();

  RobotState get state => _state;
  OperatingMode get mode => _mode;

  /// Global speed scale (0.01..1) applied to every motion, like a pendant's
  /// speed override.
  double get speedOverride => _speedOverride;
  String? get faultReason => _faultReason;
  List<RobotEvent> get events => _events.toList().reversed.toList();
  int get unacknowledgedAlarms => _events.where((e) => !e.acknowledged && e.severity != EventSeverity.info).length;

  bool get simulated => !_connection.isConnected;
  bool get isPowered => _state != RobotState.powerOff && _state != RobotState.estop;
  bool get canJog => _state == RobotState.enabled && _mode == OperatingMode.manual;
  bool get canRunProgram => _state == RobotState.enabled && _mode == OperatingMode.auto && _program.isNotEmpty;
  bool get isProgramActive => _state == RobotState.running || _state == RobotState.paused;

  /// Mode and device type can't change while a program owns the robot.
  bool get canChangeMode => !isProgramActive;

  // ── State transitions ────────────────────────────────────────────────────

  void powerOn() {
    if (_state != RobotState.powerOff) return;
    _setState(RobotState.idle, 'Power on');
  }

  void powerOff() {
    if (_state == RobotState.estop || _state == RobotState.powerOff) return;
    _haltMotion();
    _send(RobiqCommand.disable());
    _setState(RobotState.powerOff, 'Power off');
  }

  void enable() {
    if (_state != RobotState.idle) return;
    _send(RobiqCommand.enable());
    _setState(RobotState.enabled, 'Motion enabled');
  }

  void disable() {
    if (_state != RobotState.enabled && !isProgramActive) return;
    _haltMotion();
    _send(RobiqCommand.disable());
    _setState(RobotState.idle, 'Motion disabled');
  }

  /// Latched emergency stop. Only [reset] leaves this state.
  void emergencyStop() {
    _haltMotion();
    _send(RobiqCommand.disable());
    if (_state == RobotState.estop) return;
    _setState(RobotState.estop, 'EMERGENCY STOP', severity: EventSeverity.error);
  }

  /// Clears an E-stop or fault. The robot returns to idle and must be
  /// re-enabled before it moves again.
  void reset() {
    if (_state != RobotState.estop && _state != RobotState.fault) return;
    _faultReason = null;
    _setState(RobotState.idle, 'Reset');
  }

  void setMode(OperatingMode mode) {
    if (mode == _mode || !canChangeMode) return;
    _haltMotion();
    _mode = mode;
    _log(EventSeverity.info, 'Mode: ${mode.name.toUpperCase()}');
    notifyListeners();
  }

  void setSpeedOverride(double value) {
    _speedOverride = value.clamp(0.01, 1.0);
    notifyListeners();
  }

  void _fault(String reason) {
    _haltMotion();
    _faultReason = reason;
    _setState(RobotState.fault, reason, severity: EventSeverity.error);
  }

  void _setState(RobotState s, String message, {EventSeverity severity = EventSeverity.info}) {
    _state = s;
    _log(severity, message);
    notifyListeners();
  }

  // ── Rover ────────────────────────────────────────────────────────────────

  /// Drive at ([x] turn, [y] throttle) in -1..1, scaled by max speed and the
  /// speed override. Ignored unless jogging is allowed.
  void drive(double x, double y) {
    if (!canJog && (x != 0 || y != 0)) return;
    final scale = _settings.maxSpeed * _speedOverride;
    _cmdTurn = x * scale;
    _cmdThrottle = y * scale;
    _send(RobiqCommand.drive(_cmdTurn, _cmdThrottle));
    if (_cmdTurn != 0 || _cmdThrottle != 0) {
      _odomTimer ??= Timer.periodic(_odomInterval, (_) => _odomTick());
    }
  }

  // Dead-reckoned pose from the commands sent. It's an estimate (no wheel
  // feedback), used to animate the rover view, and in simulation it is the
  // robot.
  static const _odomInterval = Duration(milliseconds: 50);
  double _cmdTurn = 0;
  double _cmdThrottle = 0;
  Offset _position = Offset.zero;
  double _heading = 0;
  Timer? _odomTimer;

  /// Metres from the start point. +y is forward at heading 0.
  Offset get position => _position;

  /// Radians, clockwise from the start heading.
  double get heading => _heading;

  void resetOdometry() {
    _position = Offset.zero;
    _heading = 0;
    notifyListeners();
  }

  void _odomTick() {
    if (_cmdTurn == 0 && _cmdThrottle == 0) {
      _odomTimer?.cancel();
      _odomTimer = null;
      return;
    }
    final dt = _odomInterval.inMilliseconds / 1000;
    _heading += _cmdTurn * AppConstants.roverMaxTurnRate * dt;
    final d = _cmdThrottle * AppConstants.roverMaxSpeed * dt;
    _position += Offset(math.sin(_heading) * d, math.cos(_heading) * d);
    notifyListeners();
  }

  // ── Arm: joints, jogging, programs ───────────────────────────────────────

  List<double> _joints = [];
  List<List<double>> _program = [];
  int? _jogJoint;
  int _jogDir = 0;
  List<double>? _moveTarget;
  int _programIndex = 0;
  bool _loop = false;
  int _dwellTicks = 0;
  Timer? _ticker;

  List<double> get joints => List.unmodifiable(_joints);
  List<List<double>> get program => List.unmodifiable(_program);
  int get programIndex => _programIndex;
  bool get loop => _loop;
  set loop(bool v) {
    _loop = v;
    notifyListeners();
  }

  bool get isMovingToTarget => _moveTarget != null;

  /// Moves one joint by [delta] degrees (step jog).
  void stepJoint(int joint, double delta) {
    if (!canJog) return;
    _setJoint(joint, _joints[joint] + delta);
    notifyListeners();
  }

  /// Sets one joint directly (e.g. from a slider).
  void setJoint(int joint, double angle) {
    if (!canJog) return;
    _setJoint(joint, angle);
    notifyListeners();
  }

  /// Hold-to-run continuous jog. Call [stopJog] when the button is released.
  void startJog(int joint, int direction) {
    if (!canJog) return;
    _jogJoint = joint;
    _jogDir = direction.sign;
    _startTicker();
  }

  void stopJog() {
    _jogJoint = null;
    _jogDir = 0;
  }

  /// Hold-to-run move to a pose. Motion stops as soon as [stopMove] is called.
  void startMoveTo(List<double> target) {
    if (!canJog) return;
    _moveTarget = List.of(target);
    _startTicker();
    notifyListeners();
  }

  void stopMove() {
    if (_moveTarget == null) return;
    _moveTarget = null;
    notifyListeners();
  }

  void teachWaypoint() {
    _program.add(List.of(_joints));
    _saveProgram('Waypoint ${_program.length} taught');
  }

  void overwriteWaypoint(int index) {
    if (isProgramActive) return;
    _program[index] = List.of(_joints);
    _saveProgram('Waypoint ${index + 1} updated');
  }

  void deleteWaypoint(int index) {
    if (isProgramActive) return;
    _program.removeAt(index);
    _saveProgram('Waypoint ${index + 1} deleted');
  }

  void clearProgram() {
    if (isProgramActive) return;
    _program.clear();
    _saveProgram('Program cleared');
  }

  void runProgram() {
    if (!canRunProgram) return;
    _programIndex = 0;
    _dwellTicks = 0;
    _setState(RobotState.running, 'Program started');
    _startTicker();
  }

  void pauseProgram() {
    if (_state != RobotState.running) return;
    _setState(RobotState.paused, 'Program paused');
  }

  void resumeProgram() {
    if (_state != RobotState.paused) return;
    _setState(RobotState.running, 'Program resumed');
    _startTicker();
  }

  void stopProgram() {
    if (!isProgramActive) return;
    _haltMotion();
    _setState(RobotState.enabled, 'Program stopped');
  }

  void _saveProgram(String message) {
    _settings.armProgram = _program;
    _log(EventSeverity.info, message);
    notifyListeners();
  }

  void _setJoint(int i, double angle) {
    final v = angle.clamp(0.0, 180.0);
    // Only send whole-degree changes; keeps slow BLE links from flooding.
    if (v.round() != _joints[i].round()) _send(RobiqCommand.joint(i, v));
    _joints[i] = v;
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(AppConstants.controlSendInterval, (_) => _tick());
  }

  void _tick() {
    final dt = AppConstants.controlSendInterval.inMilliseconds / 1000;
    final maxStep = AppConstants.jointSpeedDegPerSec * _speedOverride * dt;

    if (_jogJoint != null && canJog) {
      _setJoint(_jogJoint!, _joints[_jogJoint!] + _jogDir * maxStep);
      notifyListeners();
      return;
    }

    final List<double>? target;
    if (_moveTarget != null && canJog) {
      target = _moveTarget;
    } else if (_state == RobotState.running && _program.isNotEmpty) {
      if (_dwellTicks > 0) {
        if (--_dwellTicks == 0) _advanceProgram();
        return;
      }
      target = _program[_programIndex];
    } else {
      target = null;
    }

    if (target == null) {
      _stopTicker();
      return;
    }

    var arrived = true;
    for (var i = 0; i < _joints.length && i < target.length; i++) {
      final diff = target[i] - _joints[i];
      if (diff.abs() > maxStep) arrived = false;
      if (diff != 0) _setJoint(i, _joints[i] + diff.clamp(-maxStep, maxStep));
    }
    if (arrived) {
      if (_moveTarget != null) {
        _moveTarget = null;
      } else {
        _dwellTicks = 1 + AppConstants.waypointDwell.inMilliseconds ~/ AppConstants.controlSendInterval.inMilliseconds;
      }
    }
    notifyListeners();
  }

  void _advanceProgram() {
    if (_programIndex < _program.length - 1) {
      _programIndex++;
    } else if (_loop) {
      _programIndex = 0;
    } else {
      _setState(RobotState.enabled, 'Program complete');
      return;
    }
    notifyListeners();
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Stops every in-progress motion and tells the device to stop.
  void _haltMotion() {
    _cmdTurn = _cmdThrottle = 0;
    stopJog();
    _moveTarget = null;
    _dwellTicks = 0;
    _stopTicker();
    _send(RobiqCommand.stop());
  }

  void _syncJointCount() {
    final reported = _connection.device?.jointCount ?? 0;
    final count = reported > 0 ? reported : AppConstants.defaultJointCount;
    if (_joints.length == count) return;
    _joints = List.generate(count, (i) => i < _joints.length ? _joints[i] : 90);
  }

  // ── Connection & heartbeat ───────────────────────────────────────────────

  bool _wasConnected = false;
  DateTime? _pingSentAt;
  DateTime? _lastPong;
  int? _latencyMs;

  /// Round-trip time of the last heartbeat, or `null` if the device isn't
  /// answering pings.
  int? get latencyMs => _latencyMs;

  void _onConnectionChanged() {
    _syncJointCount();
    final connected = _connection.isConnected;
    _rememberDevice();
    if (connected == _wasConnected) return;
    _wasConnected = connected;
    _latencyMs = null;
    _lastPong = null;

    final wasMoving = _state == RobotState.enabled || isProgramActive;
    if (!connected) {
      if (wasMoving) {
        _fault('Communication lost');
      } else {
        _log(EventSeverity.warning, 'Device disconnected — simulation mode');
        notifyListeners();
      }
    } else {
      // Never carry an "enabled" state from simulation onto real hardware.
      if (wasMoving) {
        _haltMotion();
        _state = RobotState.idle;
      }
      _log(EventSeverity.info, 'Connected to ${_connection.device?.name ?? 'device'}');
      notifyListeners();
    }
  }

  String? _remembered;

  /// Keeps the recent-devices list up to date, including the type and joint
  /// count the firmware reports after connecting.
  void _rememberDevice() {
    final d = _connection.device;
    if (!_connection.isConnected || d == null) return;
    final key = '${d.id}|${d.name}|${d.kind}|${d.jointCount}';
    if (key == _remembered) return;
    _remembered = key;
    _settings.rememberDevice(d);
  }

  void _onMessage(RobiqMessage msg) {
    switch (msg) {
      case TelemetryMessage(:final values):
        _checkHealth(values);
      case PongMessage():
        final sent = _pingSentAt;
        _lastPong = DateTime.now();
        if (sent != null) _latencyMs = _lastPong!.difference(sent).inMilliseconds;
        notifyListeners();
      case LogMessage(:final text) when RegExp('error|fault|fail', caseSensitive: false).hasMatch(text):
        _log(EventSeverity.warning, 'Device: $text');
        notifyListeners();
      default:
        break;
    }
  }

  void _beat() {
    if (!_connection.isConnected) return;
    final stale = _lastPong == null || DateTime.now().difference(_lastPong!) > AppConstants.heartbeatTimeout;
    if (stale && _latencyMs != null) {
      _latencyMs = null;
      notifyListeners();
    }
    _pingSentAt = DateTime.now();
    _send(RobiqCommand.ping());
  }

  void _send(RobiqCommand command) => _connection.send(command);

  // ── Simulation & health ──────────────────────────────────────────────────

  double _simBattery = 8.3;
  double _simTemp = 27;
  final _rand = math.Random();

  /// Restores the simulated robot to a full battery and cool motors.
  void resetSimulation() {
    _simBattery = 8.4;
    _simTemp = 27;
    _log(EventSeverity.info, 'Simulation reset');
    notifyListeners();
  }

  /// Generates plausible telemetry while offline, driven by how hard the
  /// simulated robot is working, so the dashboard and alerts behave as they
  /// would with hardware.
  void _simTick() {
    if (!simulated || _state == RobotState.powerOff) return;
    final rover = (_cmdTurn.abs() + _cmdThrottle.abs()).clamp(0.0, 1.0);
    final arm = _ticker != null ? _speedOverride : 0.0;
    final load = math.max(rover, arm);

    _simBattery = math.max(6.0, _simBattery - 0.0006 - 0.008 * load);
    _simTemp += ((27 + 38 * load) - _simTemp) * 0.04;
    final values = {
      'battery': _simBattery + (_rand.nextDouble() - 0.5) * 0.02,
      'temp': _simTemp + (_rand.nextDouble() - 0.5) * 0.3,
      'current': 0.15 + 2.6 * load + _rand.nextDouble() * 0.05,
    };
    _connection.ingestTelemetry(values);
    _checkHealth(values);
  }

  bool _batteryLow = false;
  bool _overTemp = false;

  /// True while the battery is below the configured threshold.
  bool get batteryLow => _batteryLow;

  void _checkHealth(Map<String, double> values) {
    final battery = values['battery'];
    final threshold = _settings.lowBatteryVolts;
    if (battery != null) {
      if (!_batteryLow && battery < threshold) {
        _batteryLow = true;
        _log(EventSeverity.warning, 'Low battery: ${battery.toStringAsFixed(1)} V');
        notifyListeners();
      } else if (_batteryLow && battery > threshold + 0.2) {
        _batteryLow = false;
        notifyListeners();
      }
    }
    final temp = values['temp'];
    if (temp != null) {
      if (!_overTemp && temp > AppConstants.overTempC) {
        _overTemp = true;
        _log(EventSeverity.warning, 'High temperature: ${temp.round()} °C');
        notifyListeners();
      } else if (_overTemp && temp < AppConstants.overTempC - 5) {
        _overTemp = false;
        notifyListeners();
      }
    }
  }

  // ── Event log ────────────────────────────────────────────────────────────

  void acknowledgeAll() {
    for (final e in _events) {
      e.acknowledged = true;
    }
    notifyListeners();
  }

  void _log(EventSeverity severity, String message) {
    _events.addLast(RobotEvent(severity, message));
    while (_events.length > 200) {
      _events.removeFirst();
    }
  }

  @override
  void dispose() {
    _connection.removeListener(_onConnectionChanged);
    _messageSub.cancel();
    _heartbeat.cancel();
    _sim.cancel();
    _stopTicker();
    _odomTimer?.cancel();
    super.dispose();
  }
}
