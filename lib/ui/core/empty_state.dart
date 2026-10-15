import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/emoji.dart';

class EmptyState extends StatelessWidget {
  const new({
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(Corners.large),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.l,
          vertical: Spacing.xl,
        ),
        child: Column(
          spacing: Spacing.s,
          children: [
            SvgPicture.asset(
              Emoji.basket,
              width: Sizes.illustration,
              height: Sizes.illustration,
              excludeFromSemantics: true,
            ),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action case final action?)
              Padding(
                padding: const EdgeInsets.only(top: Spacing.s),
                child: action,
              ),
          ],
        ),
      ),
    );
  }
}
