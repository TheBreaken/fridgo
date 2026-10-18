import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/data/repositories/product_image_repository.dart';
import 'package:fridgo/domain/product_photo.dart';
import 'package:image_picker/image_picker.dart';

class _FakeImagePicker extends Fake implements ImagePicker {
  Future<XFile?> Function() onPickImage = () async => null;
  final requests = <({ImageSource source, double? maxWidth, bool metadata})>[];

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) {
    requests.add((
      source: source,
      maxWidth: maxWidth,
      metadata: requestFullMetadata,
    ));
    return onPickImage();
  }
}

void main() {
  late Directory appDirectory;
  late Directory temporaryDirectory;
  late _FakeImagePicker picker;
  late ProductImageRepository repository;

  setUp(() async {
    appDirectory = await Directory.systemTemp.createTemp('fridgo_app');
    temporaryDirectory = await Directory.systemTemp.createTemp('fridgo_tmp');
    addTearDown(() => appDirectory.delete(recursive: true));
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    picker = _FakeImagePicker();
    repository = ProductImageRepository(picker, () async => appDirectory);
  });

  File pickedPhoto(String name, [List<int> bytes = const [1, 2, 3]]) =>
      File('${temporaryDirectory.path}/$name')..writeAsBytesSync(bytes);

  test(
    'a stored photo lies in the app directory under a relative path',
    () async {
      final photo = pickedPhoto('image_picker_123.jpg', [9, 8, 7]);

      final imagePath = await repository.store(photo.path);

      expect(
        imagePath,
        matches(RegExp(r'^product_images/[0-9a-f-]{36}\.jpg$')),
      );
      expect(File('${appDirectory.path}/$imagePath').readAsBytesSync(), [
        9,
        8,
        7,
      ]);
    },
  );

  test('storing removes the temporary file of the picker', () async {
    final photo = pickedPhoto('image_picker_123.jpg');

    await repository.store(photo.path);

    expect(photo.existsSync(), isFalse);
  });

  const extensions = {
    'a JPEG keeps its extension': ('photo.jpg', r'\.jpg$'),
    'a PNG keeps its extension': ('photo.png', r'\.png$'),
    'a file without extension gets none': ('photo', r'[0-9a-f]$'),
  };

  for (final MapEntry(key: description, value: (name, ending))
      in extensions.entries) {
    test('storing: $description', () async {
      final imagePath = await repository.store(pickedPhoto(name).path);

      expect(imagePath, matches(RegExp(ending)));
    });
  }

  test('two photos of the same name get different paths', () async {
    final first = await repository.store(pickedPhoto('photo.jpg').path);
    final second = await repository.store(pickedPhoto('photo.jpg').path);

    expect(first, isNot(second));
  });

  test('a relative image path resolves inside the app directory', () async {
    final file = await repository.file('product_images/milk.jpg');

    expect(file.path, '${appDirectory.path}/product_images/milk.jpg');
  });

  test('a deleted image is gone from the app directory', () async {
    final imagePath = await repository.store(pickedPhoto('photo.jpg').path);

    await repository.delete(imagePath);

    expect(File('${appDirectory.path}/$imagePath').existsSync(), isFalse);
  });

  test('deleting a missing image completes without error', () async {
    await expectLater(
      repository.delete('product_images/missing.jpg'),
      completes,
    );
  });

  test('picking returns the path of the picked file', () async {
    picker.onPickImage = () async => XFile('/tmp/image_picker_1.jpg');

    final path = await repository.pickPhoto(PhotoSource.gallery);

    expect(path, '/tmp/image_picker_1.jpg');
  });

  test('a cancelled pick returns no path', () async {
    final path = await repository.pickPhoto(PhotoSource.camera);

    expect(path, isNull);
  });

  test('picking asks for a downscaled photo without full metadata', () async {
    await repository.pickPhoto(PhotoSource.camera);

    expect(picker.requests, [
      (source: ImageSource.camera, maxWidth: 1600.0, metadata: false),
    ]);
  });

  const deniedCodes = {
    'denied camera access': ('camera_access_denied', PhotoSource.camera),
    'restricted camera access': (
      'camera_access_restricted',
      PhotoSource.camera,
    ),
    'denied photo access': ('photo_access_denied', PhotoSource.gallery),
    'restricted photo access': ('photo_access_restricted', PhotoSource.gallery),
  };

  for (final MapEntry(key: description, value: (code, source))
      in deniedCodes.entries) {
    test('$description is reported as missing access', () async {
      picker.onPickImage = () => throw PlatformException(code: code);

      await expectLater(
        repository.pickPhoto(source),
        throwsA(
          isA<PhotoAccessDeniedException>().having(
            (error) => error.source,
            'source',
            source,
          ),
        ),
      );
    });
  }

  test('any other picker error is reported as unavailable', () async {
    picker.onPickImage = () =>
        throw PlatformException(code: 'no_available_camera');

    await expectLater(
      repository.pickPhoto(PhotoSource.camera),
      throwsA(
        isA<PhotoUnavailableException>().having(
          (error) => error.reason,
          'reason',
          'no_available_camera',
        ),
      ),
    );
  });
}
