import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valores/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Api.i.load();
    Api.i.liked.clear();
    GoogleFonts.config.allowRuntimeFetching = false;

    // Use a bundled font for layout tests instead of fetching Google Fonts.
    final font = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
    final manifest = <String, dynamic>{};
    for (final family in ['Newsreader', 'DMSans']) {
      for (final weight in ['Regular', 'Medium', 'Bold']) {
        for (final italic in [false, true]) {
          final suffix = italic
              ? (weight == 'Regular' ? 'Italic' : '${weight}Italic')
              : weight;
          final asset = '$family-$suffix.ttf';
          manifest[asset] = [
            {'asset': asset},
          ];
        }
      }
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key == 'AssetManifest.bin') {
            return const StandardMessageCodec().encodeMessage(manifest);
          }
          if (manifest.containsKey(key)) return font;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    GoogleFonts.config.allowRuntimeFetching = true;
  });

  for (final direction in [-1, 1]) {
    for (final dismiss in [true, false]) {
      testWidgets(
        'Card animates after release: direction=$direction, dismiss=$dismiss',
        (tester) async {
          await http.runWithClient(
            () async {
              await tester.pumpWidget(
                const MaterialApp(home: Scaffold(body: DiscoverScreen())),
              );
              await tester.pumpAndSettle();

              final card = find.byType(PaperCard);
              final origin = tester.getTopLeft(card).dx;
              final gesture = await tester.startGesture(tester.getCenter(card));
              await gesture.moveBy(Offset(direction * 30.0, 0));
              await tester.pump(const Duration(milliseconds: 16));
              await gesture.moveBy(
                Offset(direction * (dismiss ? 260.0 : 60.0), 0),
              );
              await tester.pump(const Duration(milliseconds: 100));
              final releasedAt = tester.getTopLeft(card).dx;
              expect((releasedAt - origin) * direction, greaterThan(0));

              await gesture.up(timeStamp: const Duration(seconds: 1));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 80));
              final firstFrame = tester.getTopLeft(card).dx;
              await tester.pump(const Duration(milliseconds: 80));
              final secondFrame = tester.getTopLeft(card).dx;

              final animationDirection = dismiss ? direction : -direction;
              expect(
                (firstFrame - releasedAt) * animationDirection,
                greaterThan(0),
              );
              expect(
                (secondFrame - firstFrame) * animationDirection,
                greaterThan(0),
              );
              await tester.pumpAndSettle();
              if (dismiss) {
                expect(card, findsNothing);
              } else {
                expect(tester.getTopLeft(card).dx, closeTo(origin, 0.01));
              }
              expect(tester.takeException(), isNull);
            },
            () => MockClient((request) async {
              if (request.url.path == '/likes') {
                return http.Response('{"is_match": false}', 200);
              }
              return http.Response(
                jsonEncode([
                  {
                    'user_id': 'test-user',
                    'board': {
                      'blocks': [
                        {'name': 'Hobby', 'description': 'Test board'},
                      ],
                    },
                  },
                ]),
                200,
              );
            }),
          );
        },
      );
    }
  }
}
