import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../data/models/robot_device.dart';

/// Persisted user preferences.
class SettingsService extends ChangeNotifier {
  SettingsService._(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsService> load() async => SettingsService._(await SharedPreferences.getInstance());

  String get lastHost => _prefs.getString('lastHost') ?? '192.168.4.1';
  int get lastPort => _prefs.getInt('lastPort') ?? AppConstants.defaultWsPort;
  void rememberWifiTarget(String host, int port) {
    _prefs
      ..setString('lastHost', host)
      ..setInt('lastPort', port);
  }

  /// Maximum drive output sent to rovers (0.1..1.0).
  double get maxSpeed => _prefs.getDouble('maxSpeed') ?? 1.0;
  set maxSpeed(double value) {
    _prefs.setDouble('maxSpeed', value);
    notifyListeners();
  }

  /// Taught arm waypoints, each a list of joint angles.
  List<List<double>> get armProgram {
    final raw = _prefs.getString('armProgram');
    if (raw == null) return [];
    try {
      return [
        for (final w in jsonDecode(raw) as List) [for (final a in w as List) (a as num).toDouble()],
      ];
    } on FormatException {
      return [];
    }
  }

  set armProgram(List<List<double>> program) => _prefs.setString('armProgram', jsonEncode(program));

  /// Most recently used devices, newest first.
  List<RobotDevice> get recentDevices {
    final raw = _prefs.getString('recentDevices');
    if (raw == null) return [];
    try {
      return [for (final d in jsonDecode(raw) as List) RobotDevice.fromJson(d as Map<String, dynamic>)];
    } on Object {
      return [];
    }
  }

  void rememberDevice(RobotDevice device) {
    final list = [device, ...recentDevices.where((d) => d.id != device.id)].take(5).toList();
    _prefs.setString('recentDevices', jsonEncode([for (final d in list) d.toJson()]));
    notifyListeners();
  }

  void forgetDevice(String id) {
    final list = recentDevices.where((d) => d.id != id).toList();
    _prefs.setString('recentDevices', jsonEncode([for (final d in list) d.toJson()]));
    notifyListeners();
  }

  /// Reconnect to the most recent device when the app starts.
  bool get autoConnect => _prefs.getBool('autoConnect') ?? false;
  set autoConnect(bool value) {
    _prefs.setBool('autoConnect', value);
    notifyListeners();
  }

  /// Battery voltage below which a low-battery alert is raised.
  double get lowBatteryVolts => _prefs.getDouble('lowBatteryVolts') ?? 6.8;
  set lowBatteryVolts(double value) {
    _prefs.setDouble('lowBatteryVolts', value);
    notifyListeners();
  }
}
