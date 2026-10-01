/// App-wide constants for ROBIQ.
class AppConstants {
  AppConstants._();

  static const appName = 'ROBIQ';
  static const appTagline = 'Universal Robotics Controller';

  /// Default WebSocket port exposed by the ROBIQ ESP32 firmware.
  static const defaultWsPort = 81;

  /// How often continuous controls (joystick) send commands.
  static const controlSendInterval = Duration(milliseconds: 100);

  /// Maximum number of telemetry samples kept in memory per key.
  static const telemetryHistoryLength = 120;

  static const bleScanTimeout = Duration(seconds: 10);

  /// Link heartbeat: ping interval, and how long without a reply before the
  /// latency readout is cleared.
  static const heartbeatInterval = Duration(seconds: 1);
  static const heartbeatTimeout = Duration(seconds: 3);

  /// How often the offline simulator publishes telemetry.
  static const simTelemetryInterval = Duration(milliseconds: 500);

  /// Motor/driver temperature that raises an alert.
  static const overTempC = 60.0;

  /// Arm joint speed at 100% speed override.
  static const jointSpeedDegPerSec = 90.0;

  /// Rover speed and turn rate at full command, for the estimated pose.
  static const roverMaxSpeed = 1.0; // m/s
  static const roverMaxTurnRate = 1.6; // rad/s

  /// Pause at each waypoint while running a program.
  static const waypointDwell = Duration(milliseconds: 300);

  /// Joints shown for arms that don't report a count.
  static const defaultJointCount = 6;

  /// How long ENABLE / RESET must be held.
  static const holdToConfirm = Duration(milliseconds: 800);
}

/// Well-known BLE UART-style services supported out of the box.
class BleUuids {
  BleUuids._();

  // Nordic UART Service (used by the ROBIQ ESP32 firmware).
  static const nusService = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const nusRx = '6e400002-b5a3-f393-e0a9-e50e24dcca9e'; // app -> device
  static const nusTx = '6e400003-b5a3-f393-e0a9-e50e24dcca9e'; // device -> app

  // HM-10 / HM-19 style modules commonly paired with Arduino boards.
  static const hm10Service = '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const hm10Char = '0000ffe1-0000-1000-8000-00805f9b34fb';
}
