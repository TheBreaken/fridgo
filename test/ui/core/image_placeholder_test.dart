import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/ui/core/emoji.dart';
import 'package:fridgo/ui/core/image_placeholder.dart';

void main() {
  testWidgets('shows the canned food emoji', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ImagePlaceholder()));

    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect((picture.bytesLoader as SvgAssetLoader).assetName, Emoji.cannedFood);
  });
}
