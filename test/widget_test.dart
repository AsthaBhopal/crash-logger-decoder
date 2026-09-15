import 'package:flutter_test/flutter_test.dart';

import 'package:crash_logs_decode/main.dart';

void main() {
  testWidgets('App boots straight to the file picker with the default key loaded',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CrashLogDecoderApp());

    expect(find.text('Crash Log Decoder'), findsOneWidget);
    expect(find.text('Select a crash log file'), findsOneWidget);
    expect(find.text('Browse files…'), findsOneWidget);
  });
}
