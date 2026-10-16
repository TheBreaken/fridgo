import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridgo/ui/core/emoji.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const assets = {'canned food': Emoji.cannedFood, 'house': Emoji.house};

  for (final MapEntry(key: name, value: path) in assets.entries) {
    test('$name emoji is a bundled SVG that flutter_svg can parse', () async {
      final picture = await vg.loadPicture(SvgAssetLoader(path), null);

      expect(picture.size.isEmpty, isFalse);
      picture.picture.dispose();
    });
  }
}
