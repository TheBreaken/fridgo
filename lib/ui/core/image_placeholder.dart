import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/emoji.dart';

/// Fills the space it is given; the emoji grows up to an illustration.
class ImagePlaceholder extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.m),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(Corners.small),
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        Emoji.cannedFood,
        width: Sizes.illustration,
        height: Sizes.illustration,
        excludeFromSemantics: true,
      ),
    );
  }
}
