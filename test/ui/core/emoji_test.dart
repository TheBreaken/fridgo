import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/ui/core/emoji.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const assets = {
    'basket': Emoji.basket,
    'camera': Emoji.camera,
    'canned food': Emoji.cannedFood,
    'carrot': Emoji.carrot,
    'house': Emoji.house,
    'ice cube': Emoji.iceCube,
    'jar': Emoji.jar,
    'milk': Emoji.milk,
    'wine glass': Emoji.wineGlass,
  };

  for (final MapEntry(key: name, value: path) in assets.entries) {
    test('$name emoji is a bundled SVG that flutter_svg can parse', () async {
      final picture = await vg.loadPicture(SvgAssetLoader(path), null);

      expect(picture.size.isEmpty, isFalse);
      picture.picture.dispose();
    });
  }
}
