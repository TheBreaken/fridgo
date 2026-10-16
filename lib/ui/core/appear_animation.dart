import 'package:flutter/material.dart';
import 'package:fridgo/ui/core/app_theme.dart';

class AppearAnimation extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Durations.medium2,
      curve: Easing.emphasizedDecelerate,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, (1 - progress) * Spacing.l),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
