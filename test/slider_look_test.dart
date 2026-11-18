import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_online/ui/widgets/timeshift_slider.dart';

void main() {
  testWidgets('barra de volta no tempo desenha sem erro nos dois estados', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF0B1220),
        body: Center(
          child: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TimeshiftSliderTheme(child: Slider(min: -100, max: 0, value: -35, onChanged: (_) {})),
                const TimeshiftSliderTheme(child: Slider(min: -1, max: 0, value: 0, onChanged: null)),
              ],
            ),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('SHOT')) {
      await expectLater(find.byType(Column), matchesGoldenFile('/tmp/golden/slider.png'));
    }
  });
}
