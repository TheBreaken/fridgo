import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled fonts, so goldens show Nunito and the Material icons
/// instead of the test font's boxes. Only golden tests call this: real fonts
/// change text sizes, which other widget tests do not expect.
Future<void> loadAppFonts() async {
  final manifest = jsonDecode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font
        in (family['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// A widget test that draws real shadows. flutter_test draws them as black
/// outlines by default and checks after the test body, before any tear down,
/// that the setting is back.
void testGolden(
  String description,
  Future<void> Function(WidgetTester tester) body,
) => testWidgets(description, (tester) async {
  debugDisableShadows = false;
  try {
    await body(tester);
  } finally {
    debugDisableShadows = true;
  }
});

/// Pumps [widget] and waits until its photos and emojis are drawn. Both load
/// through real file access, which never finishes in the FakeAsync zone.
Future<void> pumpAndLoadImages(WidgetTester tester, Widget widget) async {
  // ponytail: fixed waits for data, image files and SVG emojis, which arrive
  // over a few frames; wait on them explicitly if a golden ever misses one.
  const settle = Duration(milliseconds: 100);
  await tester.runAsync(() async {
    await tester.pumpWidget(widget);
    for (var frame = 0; frame < 3; frame++) {
      await Future<void>.delayed(settle);
      await tester.pump();
    }
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage(
        (element.widget as Image).image,
        element,
        onError: (_, _) {},
      );
    }
    await Future<void>.delayed(settle);
  });
  await tester.pumpAndSettle();
}
