import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/expiry_status.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/calendar_date_display.dart';
import 'package:fridgo/ui/core/emoji.dart';
import 'package:fridgo/ui/core/expiry_badge.dart';
import 'package:fridgo/ui/core/image_placeholder.dart';
import 'package:fridgo/ui/core/product_thumbnail.dart';
import 'package:fridgo/ui/core/stock_item_photo_hero.dart';
import 'package:fridgo/ui/core/stock_unit_display.dart';
import 'package:fridgo/ui/core/storage_location_kind_display.dart';
import 'package:fridgo/ui/stock_item_detail/stock_item_detail_view_model.dart';
import 'package:fridgo/ui/stock_overview/stock_overview_view_model.dart';
import 'package:fridgo/ui/storage_locations/storage_locations_view_model.dart';

class StockItemDetailScreen extends ConsumerWidget {
  const new({required this.homeId, required this.stockItemId, super.key});

  final String homeId;
  final String stockItemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(
      stockItemDetailsProvider((homeId: homeId, stockItemId: stockItemId)),
    );
    final homeName = ref.watch(homeProvider(homeId)).value?.name ?? '';
    return Scaffold(
      appBar: AppBar(),
      body: switch (details) {
        AsyncError(:final error, :final stackTrace) =>
          Error.throwWithStackTrace(error, stackTrace),
        AsyncData(:final value?) => _Details(
          details: value,
          homeName: homeName,
          today: ref.watch(todayProvider),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _Details extends StatelessWidget {
  const new({
    required this.details,
    required this.homeName,
    required this.today,
  });

  final StockItemDetails details;
  final String homeName;
  final CalendarDate today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final StockItemDetails(:stockItem, :product, :storageLocation) = details;
    final bestBeforeDate = stockItem.bestBeforeDate;
    final openedDate = stockItem.openedDate;
    final expiryBadge = ExpiryBadge.forStatus(
      ExpiryStatus.of(bestBeforeDate, today: today),
    );
    return ListView(
      padding: const EdgeInsets.all(Spacing.l),
      children: [
        Hero(
          tag: stockItemPhotoHeroTag(stockItem.id),
          child: _ProductPhoto(imagePath: product.imagePath),
        ),
        const SizedBox(height: Spacing.l),
        Text(product.name, style: Theme.of(context).textTheme.titleLarge),
        if (expiryBadge != null) ...[
          const SizedBox(height: Spacing.s),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: expiryBadge,
          ),
        ],
        const SizedBox(height: Spacing.l),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.s),
            child: Column(
              children: [
                _DetailRow(
                  leading: const Icon(Icons.scale_rounded),
                  label: l10n.stockItemQuantityLabel,
                  value: stockItem.unit.formatQuantity(
                    stockItem.quantity,
                    l10n,
                  ),
                ),
                _DetailRow(
                  leading: const Icon(Icons.event_rounded),
                  label: l10n.stockItemDetailBestBeforeLabel,
                  value:
                      bestBeforeDate?.format(l10n) ??
                      l10n.stockItemDetailNoBestBeforeDate,
                ),
                _DetailRow(
                  leading: const Icon(Icons.lock_open_rounded),
                  label: l10n.stockItemDetailOpenedLabel,
                  value:
                      openedDate?.format(l10n) ?? l10n.stockItemDetailNotOpened,
                ),
                _DetailRow(
                  leading: _EmojiIcon(storageLocation.kind.emoji),
                  label: l10n.stockItemStorageLocationLabel,
                  value: storageLocation.name,
                ),
                _DetailRow(
                  leading: const _EmojiIcon(Emoji.house),
                  label: l10n.stockItemDetailHomeLabel,
                  value: homeName,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductPhoto extends ConsumerWidget {
  const new({required this.imagePath});

  final String? imagePath;

  static const double _aspectRatio = 4 / 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imagePath = this.imagePath;
    final file = imagePath == null
        ? null
        : ref.watch(productImageFileProvider(imagePath)).value;
    final decodeWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round();
    return AspectRatio(
      aspectRatio: _aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Corners.large),
        child: ColoredBox(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: switch ((imagePath, file)) {
            (null, _) => const ImagePlaceholder(),
            (_, null) => null,
            (_, final file?) => Stack(
              fit: StackFit.expand,
              children: [
                Image(
                  image: productThumbnailImage(context, file),
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const ImagePlaceholder(),
                ),
                Image(
                  image: ResizeImage(
                    FileImage(file),
                    width: decodeWidth,
                    policy: ResizeImagePolicy.fit,
                  ),
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  frameBuilder: _fadeIn,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }

  static Widget _fadeIn(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (wasSynchronouslyLoaded) return child;
    return AnimatedOpacity(
      opacity: frame == null ? 0 : 1,
      duration: Durations.medium2,
      child: child,
    );
  }
}

class _EmojiIcon extends StatelessWidget {
  const new(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    final size = IconTheme.of(context).size;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const new({required this.leading, required this.label, required this.value});

  final Widget leading;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.l,
        vertical: Spacing.s,
      ),
      child: Row(
        spacing: Spacing.m,
        children: [
          IconTheme.merge(
            data: IconThemeData(color: colors.onSurfaceVariant),
            child: leading,
          ),
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
