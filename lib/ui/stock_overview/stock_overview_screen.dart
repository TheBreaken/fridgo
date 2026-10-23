import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridgo/domain/calendar_date.dart';
import 'package:fridgo/domain/stock_item.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/appear_animation.dart';
import 'package:fridgo/ui/core/emoji.dart';
import 'package:fridgo/ui/core/empty_state.dart';
import 'package:fridgo/ui/stock_overview/consume_stock_item_sheet.dart';
import 'package:fridgo/ui/stock_overview/stock_item_card.dart';
import 'package:fridgo/ui/stock_overview/stock_overview_view_model.dart';
import 'package:fridgo/ui/stock_overview/switch_home_sheet.dart';
import 'package:fridgo/ui/storage_locations/create_storage_location_sheet.dart';
import 'package:fridgo/ui/storage_locations/storage_locations_view_model.dart';
import 'package:go_router/go_router.dart';

class StockOverviewScreen extends ConsumerWidget {
  const new({required this.homeId, super.key});

  final String homeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final home = ref.watch(homeProvider(homeId)).value;
    final storageLocations = ref.watch(
      storageLocationsViewModelProvider(homeId),
    );
    final stockItems = ref.watch(stockOverviewProvider(homeId));
    final hasStorageLocations = storageLocations.value?.isNotEmpty ?? false;
    return AnimatedSwitcher(
      duration: Durations.medium2,
      child: Scaffold(
        key: ValueKey(homeId),
        appBar: AppBar(
          // Together with the button padding the name lines up with a plain
          // title.
          titleSpacing: Spacing.xs,
          title: _SwitchHomeButton(homeId: homeId, name: home?.name ?? ''),
          actions: [
            IconButton(
              onPressed: () => context.go('/homes/$homeId/storage-locations'),
              tooltip: l10n.showStorageLocations,
              icon: const Icon(Icons.kitchen_rounded),
            ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: Durations.medium2,
          child: switch ((storageLocations, stockItems)) {
            (AsyncError(:final error, :final stackTrace), _) ||
            (
              _,
              AsyncError(:final error, :final stackTrace),
            ) => Error.throwWithStackTrace(error, stackTrace),
            (AsyncData(value: []), _) => _NoStorageLocation(homeId: homeId),
            (AsyncData(), AsyncData(value: [])) => _EmptyStock(homeId: homeId),
            (AsyncData(), AsyncData(:final value)) => _StockItemList(
              stockItems: value,
            ),
            _ => const SizedBox.shrink(),
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: hasStorageLocations
            ? FloatingActionButton(
                onPressed: () => _openScanner(context, homeId),
                tooltip: l10n.scanStockItem,
                child: const Icon(Icons.qr_code_scanner_rounded),
              )
            : null,
      ),
    );
  }
}

class _SwitchHomeButton extends StatelessWidget {
  const new({required this.homeId, required this.name});

  final String homeId;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: AppLocalizations.of(context).switchHome,
      child: TextButton.icon(
        onPressed: () => showSwitchHomeSheet(context, homeId),
        iconAlignment: IconAlignment.end,
        icon: const Icon(Icons.arrow_drop_down_rounded),
        label: Text(name, overflow: TextOverflow.ellipsis),
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface,
          textStyle: theme.textTheme.titleLarge,
        ),
      ),
    );
  }
}

void _openScanner(BuildContext context, String homeId) =>
    context.go('/homes/$homeId/scan');

class _NoStorageLocation extends StatelessWidget {
  const new({required this.homeId});

  final String homeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(Spacing.l),
      children: [
        EmptyState(
          emoji: Emoji.jar,
          title: l10n.stockOverviewNoStorageLocationTitle,
          message: l10n.stockOverviewNoStorageLocationMessage,
          action: FilledButton(
            onPressed: () => showCreateStorageLocationSheet(context, homeId),
            child: Text(l10n.addStorageLocation),
          ),
        ),
      ],
    );
  }
}

class _EmptyStock extends StatelessWidget {
  const new({required this.homeId});

  final String homeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(Spacing.l),
      children: [
        EmptyState(
          emoji: Emoji.carrot,
          title: l10n.stockOverviewEmptyTitle,
          message: l10n.stockOverviewEmptyMessage,
          action: FilledButton(
            onPressed: () => _openScanner(context, homeId),
            child: Text(l10n.addStockItem),
          ),
        ),
      ],
    );
  }
}

class _StockItemList extends ConsumerStatefulWidget {
  const new({required this.stockItems});

  final List<StockItemDetails> stockItems;

  @override
  ConsumerState<_StockItemList> createState() => _StockItemListState();
}

class _StockItemListState extends ConsumerState<_StockItemList> {
  var _listKey = GlobalKey<AnimatedListState>();
  late List<StockItemDetails> _shown = widget.stockItems;
  late CalendarDate _today;

  @override
  void didUpdateWidget(_StockItemList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.stockItems;
    final nextIds = {for (final details in next) details.stockItem.id};
    final shownIds = {for (final details in _shown) details.stockItem.id};
    final keptInShownOrder = [
      for (final id in shownIds)
        if (nextIds.contains(id)) id,
    ];
    final keptInNextOrder = [
      for (final id in nextIds)
        if (shownIds.contains(id)) id,
    ];
    if (!listEquals(keptInShownOrder, keptInNextOrder)) {
      // ponytail: a changed order rebuilds without animation. Animate moves
      // once they become common, e.g. when editing the best before date (T018).
      _listKey = GlobalKey();
      _shown = next;
      return;
    }
    final list = _listKey.currentState!;
    for (var index = _shown.length - 1; index >= 0; index--) {
      final removed = _shown[index];
      if (nextIds.contains(removed.stockItem.id)) continue;
      list.removeItem(
        index,
        (context, animation) => IgnorePointer(
          child: _buildItem(removed, animation, onTap: () {}, onConsume: () {}),
        ),
      );
    }
    for (var index = 0; index < next.length; index++) {
      if (shownIds.contains(next[index].stockItem.id)) continue;
      list.insertItem(index);
    }
    _shown = next;
  }

  Widget _buildItem(
    StockItemDetails details,
    Animation<double> animation, {
    required VoidCallback onTap,
    required VoidCallback onConsume,
  }) {
    final curved = CurvedAnimation(parent: animation, curve: Easing.standard);
    return SizeTransition(
      sizeFactor: curved,
      child: FadeTransition(
        opacity: curved,
        child: Padding(
          padding: const EdgeInsets.only(bottom: Spacing.m),
          child: AppearAnimation(
            child: StockItemCard(
              details: details,
              today: _today,
              onTap: onTap,
              onConsume: onConsume,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _today = ref.watch(todayProvider);
    return AnimatedList(
      key: _listKey,
      padding: const EdgeInsets.fromLTRB(
        Spacing.l,
        Spacing.l,
        Spacing.l,
        Sizes.floatingActionButtonClearance,
      ),
      initialItemCount: _shown.length,
      itemBuilder: (context, index, animation) {
        final details = _shown[index];
        return _buildItem(
          details,
          animation,
          onTap: () => context.go(
            '/homes/${details.storageLocation.homeId}/stock-items/'
            '${details.stockItem.id}',
          ),
          onConsume: () => showConsumeStockItemSheet(context, details),
        );
      },
    );
  }
}
