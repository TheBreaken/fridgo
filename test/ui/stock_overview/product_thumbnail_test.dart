import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/repositories/product_image_repository.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/image_placeholder.dart';
import 'package:fridgo/ui/stock_overview/product_thumbnail.dart';

import '../../data/repositories/fake_product_image_repository.dart';

// A green 1×1 PNG.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGA'
  'WjR9awAAAABJRU5ErkJggg==',
);

Widget _thumbnailApp(
  String? imagePath, {
  FakeProductImageRepository? productImages,
}) => ProviderScope(
  overrides: [
    productImageRepositoryProvider.overrideWithValue(
      productImages ?? FakeProductImageRepository(),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: ProductThumbnail(imagePath: imagePath),
  ),
);

/// Pumps the thumbnail and lets its image finish loading. Reading the file
/// needs real asynchronous file access, so the load starts in `runAsync`.
Future<void> _pumpThumbnailAndLoadImage(
  WidgetTester tester,
  String imagePath, {
  FakeProductImageRepository? productImages,
}) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(
      _thumbnailApp(imagePath, productImages: productImages),
    );
    await tester.pump();
    final image = find.byType(Image);
    await precacheImage(
      tester.widget<Image>(image).image,
      tester.element(image),
      onError: (_, _) {},
    );
  });
  await tester.pumpAndSettle();
}

void main() {
  late Directory appDirectory;

  setUp(() => appDirectory = Directory.systemTemp.createTempSync('fridgo'));
  tearDown(() => appDirectory.deleteSync(recursive: true));

  FakeProductImageRepository productImagesWith(String imagePath) {
    File('${appDirectory.path}/$imagePath')
      ..createSync(recursive: true)
      ..writeAsBytesSync(_png);
    return FakeProductImageRepository()..appDirectoryPath = appDirectory.path;
  }

  testWidgets('a product without photo shows the placeholder', (tester) async {
    await tester.pumpWidget(_thumbnailApp(null));

    expect(find.byType(ImagePlaceholder), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets(
    'a product whose image file is missing shows the placeholder without error',
    (tester) async {
      await _pumpThumbnailAndLoadImage(tester, 'product_images/missing.jpg');

      expect(find.byType(ImagePlaceholder), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a stored photo is shown instead of the placeholder', (
    tester,
  ) async {
    await _pumpThumbnailAndLoadImage(
      tester,
      'product_images/milk.png',
      productImages: productImagesWith('product_images/milk.png'),
    );

    expect(find.byType(ImagePlaceholder), findsNothing);
    expect(find.byType(RawImage), findsOneWidget);
  });

  testWidgets('a photo is decoded at twice the thumbnail size, never in full', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpThumbnailAndLoadImage(
      tester,
      'product_images/milk.png',
      productImages: productImagesWith('product_images/milk.png'),
    );

    final image = tester.widget<Image>(find.byType(Image)).image;
    expect(
      image,
      isA<ResizeImage>()
          .having((image) => image.width, 'width', 384)
          .having((image) => image.height, 'height', 384)
          .having((image) => image.policy, 'policy', ResizeImagePolicy.fit),
    );
  });
}
