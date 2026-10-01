# Contributing to ROBIQ

Thanks for your interest in improving ROBIQ! Contributions of all kinds are welcome: bug reports, features, firmware examples, docs and translations.

## Getting started

1. Fork the repository and create a branch: `git checkout -b feature/my-feature`
2. Install dependencies: `flutter pub get`
3. Make your changes.
4. Make sure these pass:
   ```bash
   dart format .
   flutter analyze
   flutter test
   ```
5. Commit with a clear message and open a Pull Request.

## Guidelines

- **Features go in `lib/features/<name>/`.** Shared widgets go in `lib/shared/`. Transport code goes in `lib/services/`.
- **Supporting new hardware?** Use the [ROBIQ protocol](docs/PROTOCOL.md) where you can. Add a reference sketch under `firmware/`.
- **New transport (e.g. USB serial, MQTT)?** Implement `DeviceConnection` in `lib/services/connection/`.
- Add tests for protocol or logic changes in `test/`.
- Keep pull requests focused. One feature or fix per PR.

## Reporting bugs

Open an issue. Please include:

- App version and platform (Android/iOS/desktop)
- The hardware (board, BLE module, firmware)
- Steps to reproduce, and what you expected

## Code of conduct

Be respectful and constructive. We want ROBIQ to be welcoming to everyone, from first-time makers to robotics professionals.
