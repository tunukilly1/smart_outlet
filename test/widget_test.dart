import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_electric/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SmartOutlet());

    // Verify that our app builds (we can't really test counter if it's not there)
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
