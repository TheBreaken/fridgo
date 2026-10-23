import 'package:flutter/material.dart';
import 'package:fridgo/ui/core/app_theme.dart';

/// A quiet line of text with an icon, under a form field.
class InfoNote extends StatelessWidget {
  const new({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      spacing: Spacing.s,
      children: [
        Icon(
          icon,
          size: Sizes.inlineIcon,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
