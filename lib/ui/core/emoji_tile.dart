import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fridgo/ui/core/app_theme.dart';

class EmojiTile extends StatelessWidget {
  const new({required this.emoji, super.key});

  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Sizes.icon,
      height: Sizes.icon,
      padding: const EdgeInsets.all(Spacing.s),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(Corners.small),
      ),
      child: SvgPicture.asset(emoji, excludeFromSemantics: true),
    );
  }
}
