import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/expiry_status.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/calendar_date_display.dart';
import 'package:fridgo/ui/core/expiry_badge.dart';
import 'package:fridgo/ui/core/product_thumbnail.dart';
import 'package:fridgo/ui/core/stock_item_photo_hero.dart';
import 'package:fridgo/ui/core/stock_unit_display.dart';
import 'package:fridgo/ui/core/storage_location_kind_display.dart';

class StockItemCard extends StatelessWidget {
  const new({
    required this.details,
    required this.today,
    required this.onTap,
    required this.onConsume,
    super.key,
  });

  final StockItemDetails details;
  final CalendarDate today;
  final VoidCallback onTap;
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.m),
          child: Row(
            spacing: Spacing.m,
            children: [
              Hero(
                tag: stockItemPhotoHeroTag(stockItem.id),
                child: ProductThumbnail(imagePath: product.imagePath),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: Spacing.xs,
                  children: [
                    Text(product.name, style: theme.textTheme.titleMedium),
                    ?ExpiryBadge.forStatus(
                      ExpiryStatus.of(bestBeforeDate, today: today),
                    ),
                    _CrossFade(
                      child: Text(
                        [
                          quantity,
                          if (bestBeforeDate != null)
                            l10n.stockItemBestBefore(
                              bestBeforeDate.format(l10n),
                            ),
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
