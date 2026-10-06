import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robiq/features/control/widgets/dpad.dart';

void main() {
  late List<Offset> sent;

  Future<void> pump(WidgetTester tester, {bool enabled = true}) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: DPad(enabled: enabled, onChanged: sent.add),
        ),
      ),
    ),
  );

  setUp(() => sent = []);

  testWidgets('hold forward drives forward until released', (tester) async {
    await pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byTooltip('Forward')));
    await tester.pump();
    expect(sent.last, const Offset(0, -1));
    await gesture.up();
    await tester.pump();
    expect(sent.last, Offset.zero);
  });

  testWidgets('arrow keys combine into a normalised diagonal', (tester) async {
    await pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    expect(sent.last.distance, closeTo(1, 1e-9));
    expect(sent.last.dx, lessThan(0));
    expect(sent.last.dy, lessThan(0));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    expect(sent.last, Offset.zero);
  });

  testWidgets('disabled pad sends nothing', (tester) async {
    await pump(tester, enabled: false);
    await tester.tap(find.byTooltip('Back'));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    expect(sent, isEmpty);
  });
}
