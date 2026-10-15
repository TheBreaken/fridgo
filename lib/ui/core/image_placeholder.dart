import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/emoji.dart';

class ImagePlaceholder extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Sizes.thumbnail,
      height: Sizes.thumbnail,
      padding: const EdgeInsets.all(Spacing.m),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(Corners.small),
      ),
      child: SvgPicture.asset(Emoji.cannedFood, excludeFromSemantics: true),
    );
  }
}
