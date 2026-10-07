// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:valores/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    // Start without a saved session so the app shows the auth screen.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ValoresApp());
    // Let the async session load finish and the first frame settle.
    await tester.pump();

    expect(find.byType(ValoresApp), findsOneWidget);
  });

  testWidgets('bundled fonts are available as assets', (
    WidgetTester tester,
  ) async {
    // These are the files google_fonts looks up by name, so they must exist in
    // the asset bundle for startup to work without network access.
    for (final name in [
      'DMSans-Regular.ttf',
      'DMSans-Medium.ttf',
      'DMSans-SemiBold.ttf',
      'DMSans-Bold.ttf',
      'Newsreader-Regular.ttf',
      'Newsreader-Medium.ttf',
      'Newsreader-SemiBold.ttf',
      'Newsreader-Italic.ttf',
      'FiraCode-Regular.ttf',
    ]) {
      final data = await rootBundle.load('assets/fonts/$name');
      expect(data.lengthInBytes, greaterThan(0), reason: name);
    }
  });
}
