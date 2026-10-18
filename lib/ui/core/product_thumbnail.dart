import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:fridgo/data/repositories/product_image_repository.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/image_placeholder.dart';

class ProductThumbnail extends StatelessWidget {
  const new({required this.imagePath, super.key});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final imagePath = this.imagePath;
    if (imagePath == null) return const ImagePlaceholder();
    return _Photo(imagePath: imagePath);
  }
}

class _Photo extends ConsumerWidget {
  const new({required this.imagePath});

  final String imagePath;

  // Decoding into twice the thumbnail keeps photos up to 2:1 sharp after
  // cropping them to a square, while the full photo is never decoded.
  static const _decodeScale = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(productImageFileProvider(imagePath)).value;
    final decodeEdge =
        (Sizes.thumbnail *
                MediaQuery.devicePixelRatioOf(context) *
                _decodeScale)
            .round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(Corners.small),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: SizedBox.square(
          dimension: Sizes.thumbnail,
          child: file == null
              ? null
              : Image(
                  image: ResizeImage(
                    FileImage(file),
                    width: decodeEdge,
                    height: decodeEdge,
                    policy: ResizeImagePolicy.fit,
                  ),
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  frameBuilder: _fadeIn,
                  errorBuilder: (_, _, _) => const ImagePlaceholder(),
                ),
        ),
      ),
    );
  }

  static Widget _fadeIn(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (wasSynchronouslyLoaded) return child;
    return AnimatedOpacity(
      opacity: frame == null ? 0 : 1,
      duration: Durations.medium2,
      child: child,
    );
  }
}

// Not auto-disposed, so a card scrolled back into view shows its photo without
// a loading frame.
final FutureProviderFamily<File, String> productImageFileProvider =
    FutureProvider.family(
      (ref, imagePath) =>
          ref.watch(productImageRepositoryProvider).file(imagePath),
    );
