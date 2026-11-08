import 'dart:io';
import 'dart:typed_data';

import 'package:fridgo/data/repositories/product_image_repository.dart';
import 'package:fridgo/domain/product_photo.dart';

class FakeProductImageRepository implements ProductImageRepository {
  Future<String?> Function(PhotoSource source) onPick = (source) async =>
      '/tmp/picked_from_${source.name}.jpg';

  /// Stored image paths mapped to the picked photo each one came from.
  final storedImages = <String, String>{};

  @override
  Future<String?> pickPhoto(PhotoSource source) => onPick(source);

  /// Downloaded images by the temporary path each one got.
  final temporaryImages = <String, Uint8List>{};

  @override
  Future<String> storeTemporary(Uint8List jpeg) async {
    final path = '/tmp/downloaded_${temporaryImages.length + 1}.jpg';
    temporaryImages[path] = jpeg;
    return path;
  }

  @override
  Future<String> store(String pickedPhotoPath) async {
    final imagePath = 'product_images/${storedImages.length + 1}.jpg';
    storedImages[imagePath] = pickedPhotoPath;
    return imagePath;
  }

  /// Nothing lies there unless a test puts a file into it.
  String appDirectoryPath = '/nonexistent';

  @override
  Future<File> file(String imagePath) async =>
      File('$appDirectoryPath/$imagePath');

  @override
  Future<void> delete(String imagePath) async => storedImages.remove(imagePath);
}
