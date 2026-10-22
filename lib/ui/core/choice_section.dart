import 'package:flutter/material.dart';
import 'package:fridgo/ui/core/app_theme.dart';

class ChoiceSection extends StatelessWidget {
  const new({required this.label, required this.children, super.key});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Spacing.s,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        Wrap(spacing: Spacing.s, runSpacing: Spacing.s, children: children),
      ],
    );
  }
}
