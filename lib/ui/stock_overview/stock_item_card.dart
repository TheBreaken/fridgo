import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/expiry_status.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/calendar_date_display.dart';
import 'package:fridgo/ui/core/product_thumbnail.dart';
import 'package:fridgo/ui/core/stock_unit_display.dart';
import 'package:fridgo/ui/core/storage_location_kind_display.dart';

class StockItemCard extends StatelessWidget {
  const new({
    required this.details,
    required this.today,
    required this.onConsume,
    super.key,
  });

  final StockItemDetails details;
  final CalendarDate today;
  final VoidCallback onConsume;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final secondaryStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final StockItemDetails(:stockItem, :product, :storageLocation) = details;
    final quantity = stockItem.unit.formatQuantity(stockItem.quantity, l10n);
    final bestBeforeDate = stockItem.bestBeforeDate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.m),
        child: Row(
          spacing: Spacing.m,
          children: [
            ProductThumbnail(imagePath: product.imagePath),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Spacing.xs,
                children: [
                  Text(product.name, style: theme.textTheme.titleMedium),
                  ...switch (ExpiryStatus.of(bestBeforeDate, today: today)) {
                    Expired(:final daysAgo) => [
                      _ExpiryBadge(
                        icon: Icons.warning_rounded,
                        label: l10n.expiryStatusExpired(daysAgo),
                        background: colors.errorContainer,
                        foreground: colors.onErrorContainer,
                      ),
                    ],
                    ExpiringSoon(:final daysLeft) => [
                      _ExpiryBadge(
                        icon: Icons.schedule_rounded,
                        label: l10n.expiryStatusExpiringSoon(daysLeft),
                        background: colors.tertiaryContainer,
                        foreground: colors.onTertiaryContainer,
                      ),
                    ],
                    Fresh() || NoBestBeforeDate() => const <Widget>[],
                  },
                  _CrossFade(
                    child: Text(
                      [
                        quantity,
                        if (bestBeforeDate != null)
                          l10n.stockItemBestBefore(bestBeforeDate.format(l10n)),
                      ].join(' · '),
                      key: ValueKey(quantity),
                      style: secondaryStyle,
                    ),
                  ),
                  Row(
                    spacing: Spacing.xs,
                    children: [
                      SvgPicture.asset(
                        storageLocation.kind.emoji,
                        width: Sizes.inlineIcon,
                        height: Sizes.inlineIcon,
                        excludeFromSemantics: true,
                      ),
                      Flexible(
                        child: Text(
                          storageLocation.name,
                          style: secondaryStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onConsume,
              tooltip: l10n.consumeStockItem,
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrossFade extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Durations.medium2,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previousChildren, ?currentChild],
      ),
      child: child,
    );
  }
}

class _ExpiryBadge extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
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
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
