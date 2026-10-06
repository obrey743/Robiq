import 'package:flutter_test/flutter_test.dart';
import 'package:robiq/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('corrupt saved program loads as empty', () async {
    SharedPreferences.setMockInitialValues({'armProgram': '{"not":"a list"}'});
    final settings = await SettingsService.load();
    expect(settings.armProgram, isEmpty);
  });

  test('program round-trips', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    settings.armProgram = [
      [90, 45.5],
    ];
    expect(settings.armProgram, [
      [90.0, 45.5],
    ]);
  });
}
