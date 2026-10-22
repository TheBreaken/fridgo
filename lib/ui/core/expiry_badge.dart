import 'package:flutter/material.dart';
import 'package:fridgo/domain/expiry_status.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';

/// Warns about expired and soon expiring stock; fresh stock needs no badge.
class ExpiryBadge extends StatelessWidget {
  const new _(this.status);

  final ExpiryStatus status;

  static ExpiryBadge? forStatus(ExpiryStatus status) => switch (status) {
    Expired() || ExpiringSoon() => ExpiryBadge._(status),
    Fresh() || NoBestBeforeDate() => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (icon, label, background, foreground) = switch (status) {
      Expired(:final daysAgo) => (
        Icons.warning_rounded,
        l10n.expiryStatusExpired(daysAgo),
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      ExpiringSoon(:final daysLeft) => (
        Icons.schedule_rounded,
        l10n.expiryStatusExpiringSoon(daysLeft),
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      // Unreachable: forStatus creates no badge for these.
      Fresh() || NoBestBeforeDate() => throw StateError('No badge for $status'),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Corners.small),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.s,
          vertical: Spacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: Spacing.xs,
          children: [
            Icon(icon, size: Sizes.inlineIcon, color: foreground),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
