import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/domain/product_photo.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ProductImageRepository {
  new(this._picker, this._appDirectory);

  final ImagePicker _picker;
  final Future<Directory> Function() _appDirectory;

  // Sharp enough for a full-screen photo, a fraction of a camera photo's size.
  static const _maxEdge = 1600.0;
  static const _jpegQuality = 85;
  static const _folder = 'product_images';
  static final _extension = RegExp(r'\.\w+$');

  // Error codes of image_picker_ios and image_picker_android.
  static const _accessDeniedCodes = {
    'camera_access_denied',
    'camera_access_restricted',
    'photo_access_denied',
    'photo_access_restricted',
  };

  /// Returns the path of a temporary file, or null if the user cancels.
  ///
  /// Throws a [PhotoPickException] if the photo cannot be taken or picked.
  Future<String?> pickPhoto(PhotoSource source) async {
    try {
      final photo = await _picker.pickImage(
        source: switch (source) {
          PhotoSource.camera => ImageSource.camera,
          PhotoSource.gallery => ImageSource.gallery,
        },
        maxWidth: _maxEdge,
        maxHeight: _maxEdge,
        imageQuality: _jpegQuality,
        // Full metadata makes iOS ask for access to the whole photo library.
        requestFullMetadata: false,
      );
      return photo?.path;
    } on PlatformException catch (error) {
      if (_accessDeniedCodes.contains(error.code)) {
        throw PhotoAccessDeniedException(source);
      }
      throw PhotoUnavailableException(source, error.code);
    }
  }

  /// Moves a picked photo into the app directory and returns its path
  /// relative to that directory.
  Future<String> store(String pickedPhotoPath) async {
    final extension = _extension.firstMatch(pickedPhotoPath)?.group(0) ?? '';
    final imagePath = '$_folder/${const Uuid().v4()}$extension';
    final target = File(await _absolutePath(imagePath));
    await target.parent.create(recursive: true);
    final pickedPhoto = File(pickedPhotoPath);
    await pickedPhoto.copy(target.path);
    await pickedPhoto.delete();
    return imagePath;
  }

  Future<void> delete(String imagePath) async {
    final file = File(await _absolutePath(imagePath));
    if (file.existsSync()) await file.delete();
  }

  Future<String> _absolutePath(String imagePath) async =>
      '${(await _appDirectory()).path}/$imagePath';
}

final productImageRepositoryProvider = Provider<ProductImageRepository>(
  (ref) =>
      ProductImageRepository(ImagePicker(), getApplicationDocumentsDirectory),
);
