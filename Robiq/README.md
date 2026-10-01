<div align="center">

# 🤖 ROBIQ

### Universal Robotics Controller

**Control and monitor robots, robotic arms, ESP32 and Arduino boards, and IoT devices from one open-source Flutter app.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

</div>

---

## About

ROBIQ is a multi-purpose **Flutter and Dart** application. It controls and monitors robots, robotic arms, **ESP32** and **Arduino** devices, and other IoT systems.

The app connects over **Bluetooth Low Energy** and **Wi-Fi**. It gives you simple screens for real-time device control, sensor monitoring, telemetry and device management.

ROBIQ works with many kinds of robots and embedded systems. It suits robotics projects, teaching, prototyping and IoT development.

## ✨ Features

| | Feature | Description |
|---|---------|-------------|
| 📡 | **Bluetooth LE** | Scan for and connect to devices using the Nordic UART Service or HM-10 (`FFE0/FFE1`) modules |
| 📶 | **Wi-Fi** | Connect to any device that runs a WebSocket server (e.g. `ws://192.168.4.1:81`) |
| 🕹️ | **Rover control** | Virtual joystick with rate-limited commands, an adjustable max speed and an emergency stop |
| 🦾 | **Robotic arm control** | A slider for each servo joint, a home position, and pose save/recall |
| 🔌 | **GPIO panel** | Toggle digital pins and drive PWM outputs on ESP32/Arduino boards |
| 📈 | **Live telemetry** | Every numeric value the device reports is shown and graphed in real time |
| 🧾 | **Device log** | Non-JSON output (like `Serial.println`) appears in the app |
| 🔍 | **Auto-detection** | The device reports its type (rover, arm or generic) and the matching controls open |
| 🌗 | **Light & dark themes** | Material 3 design |
| 🧩 | **Open protocol** | A simple JSON protocol you can add to any firmware ([spec](docs/PROTOCOL.md)) |

## 📱 Supported Platforms

| Android | iOS | macOS | Windows | Linux | Web |
|:---:|:---:|:---:|:---:|:---:|:---:|
| ✅ BLE + Wi-Fi | ✅ BLE + Wi-Fi | ✅ BLE + Wi-Fi | ⚠️ Wi-Fi\* | ⚠️ Wi-Fi\* | ⚠️ Wi-Fi\* |

\* Bluetooth support on these platforms depends on [`flutter_blue_plus`](https://pub.dev/packages/flutter_blue_plus).

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.x (stable channel)
- Android Studio or Xcode, for mobile builds
- A device to control. The [reference firmware](#-firmware) below works out of the box.

### Install & run

```bash
git clone https://github.com/obrey743/RAC.git
cd RAC/Robiq
flutter pub get
flutter run
```

### Connect to a device

**Over Bluetooth**
1. Open the **Devices** tab and tap **Scan Bluetooth**.
2. Tap your device (e.g. `ROBIQ-ESP32`).

**Over Wi-Fi**
1. Join your phone to the device's network. The reference firmware creates an access point called `ROBIQ-ESP32` (password `robiq1234`).
2. Tap **Connect Wi-Fi**, enter `192.168.4.1` and port `81`.

Then open the **Control** tab to drive your robot, or the **Telemetry** tab to see sensor data.

## 🔧 Firmware

You'll find ready-to-flash reference sketches in [`firmware/`](firmware):

| Sketch | Hardware | Transports |
|--------|----------|------------|
| [`esp32/robiq_esp32`](firmware/esp32/robiq_esp32/robiq_esp32.ino) | ESP32 + motor driver and/or servos | Wi-Fi (WebSocket) **and** BLE |
| [`arduino/robiq_arduino`](firmware/arduino/robiq_arduino/robiq_arduino.ino) | Arduino Uno/Nano/Mega + HM-10 BLE module | BLE |

> **Note:** ROBIQ uses Bluetooth **Low Energy**. Classic Bluetooth modules (HC-05 / HC-06) are not supported. Use an HM-10 or an ESP32 instead.

### Add ROBIQ to your own firmware

Send and receive one JSON object per line:

```jsonc
// App → Device
{"cmd":"drive","x":0.0,"y":0.8}
{"cmd":"joint","id":1,"angle":120}
{"cmd":"stop"}

// Device → App
{"type":"info","name":"My Rover","kind":"rover","joints":0}
{"type":"telemetry","data":{"battery":7.4,"distance_cm":42}}
```

The full specification is in [`docs/PROTOCOL.md`](docs/PROTOCOL.md).

## 🗂️ Project Structure

```
Robiq/
├── lib/
│   ├── main.dart                      # Entry point, sets up providers
│   ├── app.dart                       # MaterialApp and theming
│   ├── core/
│   │   ├── constants/                 # App constants and BLE UUIDs
│   │   └── theme/                     # Material 3 light/dark themes
│   ├── data/
│   │   ├── models/                    # RobotDevice, TelemetrySample, enums
│   │   └── protocol/                  # ROBIQ JSON protocol: commands, messages, framing
│   ├── services/
│   │   ├── connection/
│   │   │   ├── device_connection.dart     # Transport interface
│   │   │   ├── bluetooth_connection.dart  # BLE (Nordic UART / HM-10)
│   │   │   ├── wifi_connection.dart       # WebSocket
│   │   │   └── connection_manager.dart    # Active connection and telemetry state
│   │   ├── permissions_service.dart
│   │   └── settings_service.dart      # Saved preferences
│   ├── features/
│   │   ├── home/                      # Navigation shell
│   │   ├── devices/                   # BLE scan and Wi-Fi connect
│   │   ├── control/                   # Rover joystick, GPIO panel
│   │   ├── arm/                       # Robotic arm joint control
│   │   ├── telemetry/                 # Live charts and device log
│   │   └── settings/
│   └── shared/widgets/                # Reusable UI
├── firmware/
│   ├── esp32/                         # ESP32 reference firmware
│   └── arduino/                       # Arduino + HM-10 reference firmware
├── docs/PROTOCOL.md                   # Communication protocol spec
├── test/                              # Unit tests
└── android/ ios/ macos/ linux/ windows/ web/
```

### Architecture

```
 UI (features/*)  ──watch──▶  ConnectionManager (ChangeNotifier)
                                   │  RobiqCommand / RobiqMessage
                                   ▼
                          DeviceConnection (interface)
                          ├── BluetoothConnection  (flutter_blue_plus)
                          └── WifiConnection       (web_socket_channel)
```

To add a new transport (USB serial, MQTT, TCP…), implement `DeviceConnection` and connect it in `ConnectionManager`.

## 🛣️ Roadmap

- [ ] Saved devices and auto-reconnect
- [ ] Customisable dashboards (buttons, gauges, sliders mapped to commands)
- [ ] Inverse kinematics for robotic arms
- [ ] Motion recording and playback
- [ ] USB serial and MQTT transports
- [ ] Camera stream (ESP32-CAM)
- [ ] Gamepad and controller support
- [ ] Localization

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before you open a pull request.

## 📄 License

ROBIQ is released under the [MIT License](LICENSE).

> ROBIQ uses [`flutter_blue_plus`](https://pub.dev/packages/flutter_blue_plus) for Bluetooth. It is free for personal, educational and non-profit use. **Commercial** use of ROBIQ (or a fork) needs a commercial `flutter_blue_plus` license. See that package's license for details.

---

<div align="center">Built with ❤️ and Flutter for makers, students and roboticists.</div>
