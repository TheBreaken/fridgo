import 'package:fridgo/data/repositories/product_image_repository.dart';
import 'package:fridgo/domain/product_photo.dart';

class FakeProductImageRepository implements ProductImageRepository {
  Future<String?> Function(PhotoSource source) onPick = (source) async =>
      '/tmp/picked_from_${source.name}.jpg';

  /// Stored image paths mapped to the picked photo each one came from.
  final storedImages = <String, String>{};

  @override
  Future<String?> pickPhoto(PhotoSource source) => onPick(source);

  @override
  Future<String> store(String pickedPhotoPath) async {
    final imagePath = 'product_images/${storedImages.length + 1}.jpg';
    storedImages[imagePath] = pickedPhotoPath;
    return imagePath;
  }

  @override
  Future<void> delete(String imagePath) async => storedImages.remove(imagePath);
}
